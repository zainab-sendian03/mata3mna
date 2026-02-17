// auth_remote_data_source.dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/entities/user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web Client ID from Google Cloud Console (OAuth 2.0 Web application).
/// Required for native mobile Google Sign-In to obtain id_token.
/// Replace with your project's Web Client ID.
const String _kGoogleWebClientId =
    '667029338646-mm72sl4ucjubhfcbejohimpe6m2068ch.apps.googleusercontent.com';

abstract class AuthRemoteDataSource {
  Future<Either<Failure, UserEntity?>> signInWithEmailAndPassword(
    String email,
    String password,
  );

  Future<Either<Failure, UserEntity?>> signInWithGoogle();

  Future<Either<Failure, UserEntity?>> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  });

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Future<Either<Failure, void>> sendEmailVerification();
  Future<Either<Failure, bool>> checkEmailVerification();
  Future<Either<Failure, void>> applyEmailVerificationActionCode(
    String actionCode,
  );
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _supabase;

  AuthRemoteDataSourceImpl({required SupabaseClient supabase})
    : _supabase = supabase;

  @override
  Future<Either<Failure, UserEntity?>> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return Right(_mapUser(response.user));
    } on AuthException catch (e) {
      // Extract proper status code from AuthException
      // Supabase returns 400 for invalid credentials, 500 for server errors
      int statusCode = 500;
      String errorMessage = e.message;

      // Check error message to determine appropriate status code
      if (e.message.toLowerCase().contains('invalid login credentials') ||
          e.message.toLowerCase().contains('invalid credentials') ||
          e.message.toLowerCase().contains('email not confirmed')) {
        statusCode = 400;
      } else if (e.message.toLowerCase().contains('too many requests')) {
        statusCode = 429;
      }

      print(
        '🔍 [AuthRemoteDataSource] AuthException: $errorMessage (status: $statusCode)',
      );
      return Left(Failure(errMessage: errorMessage, statusCode: statusCode));
    } catch (e) {
      print('🔍 [AuthRemoteDataSource] Unexpected error: $e');
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> signInWithGoogle() async {
    try {
      final isMobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isMobile && _kGoogleWebClientId.startsWith('YOUR_')) {
        return Left(
          Failure(
            errMessage:
                'قم بتعيين Web Client ID من Google Cloud في auth_remote_data_source.dart',
            statusCode: 500,
          ),
        );
      }

      if (isMobile) {
        // Native mobile: use google_sign_in for in-app account picker (no browser)
        final googleSignIn = GoogleSignIn(
          serverClientId: _kGoogleWebClientId,
          scopes: ['email', 'profile'],
        );
        final account = await googleSignIn.signIn();
        if (account == null) {
          return const Right(null); // User cancelled
        }
        final auth = await account.authentication;
        final idToken = auth.idToken;
        if (idToken == null || idToken.isEmpty) {
          return Left(
            Failure(errMessage: 'فشل الحصول على رمز Google', statusCode: 400),
          );
        }
        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );
        return Right(_mapUser(response.user));
      }

      // Web: fallback to OAuth (opens browser)
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.mata3mna://login-callback',
      );
      final user = _supabase.auth.currentUser;
      if (user != null) return Right(_mapUser(user));
      return const Right(null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  /// Deep link scheme for email confirmation callback (must match Supabase Dashboard Redirect URLs)
  static const String _emailRedirectTo = 'io.supabase.mata3mna://auth-callback';

  @override
  Future<Either<Failure, UserEntity?>> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _emailRedirectTo,
        data: displayName != null && displayName.trim().isNotEmpty
            ? {'display_name': displayName.trim()}
            : null,
      );
      return Right(_mapUser(response.user));
    } on AuthException catch (e) {
      int statusCode = 500;
      String msg = e.message;
      if (msg.toLowerCase().contains('already registered') ||
          msg.toLowerCase().contains('already exists') ||
          msg.toLowerCase().contains('duplicate')) {
        statusCode = 400;
      } else if (msg.toLowerCase().contains('password') ||
          msg.toLowerCase().contains('weak')) {
        statusCode = 400;
      } else if (msg.toLowerCase().contains('confirmation email') ||
          msg.toLowerCase().contains('error sending')) {
        statusCode = 503;
        msg =
            'لا يمكن إرسال بريد التأكيد. يجب تهيئة البريد في Supabase: لوحة التحكم → Authentication → Providers → Email → إما تعطيل "Confirm email" أو إضافة SMTP مخصص.';
      }
      print('[AuthRemoteDataSource] signUp AuthException: $msg');
      return Left(Failure(errMessage: msg, statusCode: statusCode));
    } catch (e) {
      print('[AuthRemoteDataSource] signUp error: $e');
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _supabase.auth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      return Right(_mapUser(user));
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return Left(
          Failure(errMessage: 'لا يوجد مستخدم مسجل دخول', statusCode: 401),
        );
      }

      await _supabase.auth.resend(type: OtpType.signup, email: user.email!);
      return Right(null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, bool>> checkEmailVerification() async {
    try {
      await _supabase.auth.refreshSession();
      final user = _supabase.auth.currentUser;
      return Right(user?.emailConfirmedAt != null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> applyEmailVerificationActionCode(
    String actionCode,
  ) async {
    // Supabase handles email verification automatically, nothing to implement
    return Right(null);
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _emailRedirectTo,
      );
      return Right(null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  UserEntity _mapUser(User? user) {
    if (user == null) return UserEntity();
    return UserEntity(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }
}
