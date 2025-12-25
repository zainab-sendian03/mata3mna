import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mata3mna/features/auth/domain/entities/user_entity.dart';

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
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
  Future<Either<Failure, void>> sendEmailVerification();
  Future<Either<Failure, bool>> checkEmailVerification();
  Future<Either<Failure, void>> applyEmailVerificationActionCode(String actionCode);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth auth,
    required GoogleSignIn googleSignIn,
  }) : _auth = auth,
       _googleSignIn = googleSignIn;

  @override
  Future<Either<Failure, UserEntity?>> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return Right(_mapFirebaseUserToEntity(userCredential.user));
    } on FirebaseAuthException catch (e) {
      // Map Firebase Auth error codes to HTTP status codes
      final statusCode = _mapFirebaseErrorToStatusCode(e.code);
      print('🔍 Firebase Auth Error Code: ${e.code}');
      print('🔍 Mapped Status Code: $statusCode');
      return Left(
        Failure(errMessage: e.message ?? e.code, statusCode: statusCode),
      );
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  /// Maps Firebase Auth error codes to HTTP status codes
  int _mapFirebaseErrorToStatusCode(String firebaseErrorCode) {
    switch (firebaseErrorCode) {
      // Authentication errors (401 Unauthorized)
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-email':
      case 'invalid-credential':
        return 401;

      // Bad request errors (400)
      case 'email-already-in-use':
      case 'weak-password':
      case 'operation-not-allowed':
        return 400;

      // Too many requests (429)
      case 'too-many-requests':
        return 429;

      // Server errors (500)
      case 'network-request-failed':
      case 'internal-error':
      default:
        return 500;
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return Left(
          Failure(
            errMessage: 'تم إلغاء تسجيل الدخول بواسطة Google',
            statusCode: 400,
          ),
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        return Left(
          Failure(
            errMessage:
                'فشل الحصول على رمز المصادقة من Google. يرجى التحقق من إعدادات Firebase',
            statusCode: 500,
          ),
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return Right(_mapFirebaseUserToEntity(userCredential.user));
    } on FirebaseAuthException catch (e) {
      final statusCode = _mapFirebaseErrorToStatusCode(e.code);
      print('🔍 Firebase Auth Error Code: ${e.code}');
      print('🔍 Firebase Auth Error Message: ${e.message}');
      print('🔍 Mapped Status Code: $statusCode');

      String errorMessage = e.message ?? e.code;
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'يوجد حساب آخر بنفس البريد الإلكتروني';
      } else if (e.code == 'invalid-credential') {
        errorMessage =
            'فشل المصادقة. يرجى التحقق من إعدادات Google Sign-In في Firebase';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'تسجيل الدخول بواسطة Google غير مفعّل في Firebase';
      }

      return Left(Failure(errMessage: errorMessage, statusCode: statusCode));
    } catch (e, stackTrace) {
      print('🔍 Google Sign-In Error: $e');
      print('🔍 Stack Trace: $stackTrace');

      String errorMessage = 'حدث خطأ أثناء تسجيل الدخول بواسطة Google';

      // Check for specific error codes
      if (e.toString().contains('ApiException: 10')) {
        errorMessage =
            'خطأ في الإعدادات: يرجى إضافة SHA-1 fingerprint في Firebase Console وإعادة تحميل google-services.json';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage =
            'فشل تسجيل الدخول. تأكد من تفعيل Google Sign-In في Firebase Console وإضافة SHA-1 fingerprint';
      } else {
        errorMessage =
            'حدث خطأ أثناء تسجيل الدخول بواسطة Google: ${e.toString()}';
      }

      return Left(Failure(errMessage: errorMessage, statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile with display name if provided
      // Using updateProfile with UserProfileChangeRequest to avoid type casting issues
      if (displayName != null &&
          displayName.isNotEmpty &&
          userCredential.user != null) {
        try {
          // Add a small delay to ensure Firebase Auth is fully initialized
          await Future.delayed(const Duration(milliseconds: 100));

          // Use updateProfile method which is more reliable
          await userCredential.user!.updateProfile(displayName: displayName);

          // Reload to get updated user data
          await userCredential.user!.reload();

          // Get the refreshed user
          final refreshedUser = _auth.currentUser;
          return Right(_mapFirebaseUserToEntity(refreshedUser));
        } catch (updateError) {
          // If profile update fails, still return success with the created user
          // The signup was successful even if display name update failed
          print('Warning: Failed to update display name: $updateError');
          // Continue with the created user - signup was successful
        }
      }

      return Right(_mapFirebaseUserToEntity(userCredential.user));
    } on FirebaseAuthException catch (e) {
      final statusCode = _mapFirebaseErrorToStatusCode(e.code);
      print('🔍 Firebase Auth Error Code: ${e.code}');
      print('🔍 Mapped Status Code: $statusCode');
      return Left(
        Failure(errMessage: e.message ?? e.code, statusCode: statusCode),
      );
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
      return Right(null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      return Right(_mapFirebaseUserToEntity(user));
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return Right(null);
    } on FirebaseAuthException catch (e) {
      final statusCode = _mapFirebaseErrorToStatusCode(e.code);
      return Left(
        Failure(errMessage: e.message ?? e.code, statusCode: statusCode),
      );
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Left(
          Failure(errMessage: 'لا يوجد مستخدم مسجل دخول', statusCode: 401),
        );
      }
      await user.sendEmailVerification();
      return Right(null);
    } on FirebaseAuthException catch (e) {
      final statusCode = _mapFirebaseErrorToStatusCode(e.code);
      return Left(
        Failure(errMessage: e.message ?? e.code, statusCode: statusCode),
      );
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, bool>> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Right(false);
      }
      await user.reload();
      final refreshedUser = _auth.currentUser;
      return Right(refreshedUser?.emailVerified ?? false);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> applyEmailVerificationActionCode(String actionCode) async {
    try {
      await _auth.applyActionCode(actionCode);
      return Right(null);
    } on FirebaseAuthException catch (e) {
      final statusCode = _mapFirebaseErrorToStatusCode(e.code);
      String errorMessage = e.message ?? e.code;
      
      // Provide user-friendly error messages
      if (e.code == 'expired-action-code') {
        errorMessage = 'انتهت صلاحية رابط التحقق. يرجى طلب رابط جديد';
      } else if (e.code == 'invalid-action-code') {
        errorMessage = 'رابط التحقق غير صحيح أو تم استخدامه مسبقاً';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'تم تعطيل هذا الحساب';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'لم يتم العثور على المستخدم';
      }
      
      return Left(
        Failure(errMessage: errorMessage, statusCode: statusCode),
      );
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  UserEntity _mapFirebaseUserToEntity(User? user) {
    if (user == null) return UserEntity();

    return UserEntity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }
}
