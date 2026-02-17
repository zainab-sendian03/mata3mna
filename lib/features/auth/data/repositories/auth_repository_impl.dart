// auth_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/entities/user_entity.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';
import 'package:mata3mna/features/auth/data/datesources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, UserEntity?>> signInWithEmailAndPassword(
    String email,
    String password,
  ) => _remoteDataSource.signInWithEmailAndPassword(email, password);

  @override
  Future<Either<Failure, UserEntity?>> signInWithGoogle() =>
      _remoteDataSource.signInWithGoogle();

  @override
  Future<Either<Failure, UserEntity?>> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) => _remoteDataSource.signUpWithEmailAndPassword(
    email,
    password,
    displayName: displayName,
  );

  @override
  Future<Either<Failure, void>> signOut() => _remoteDataSource.signOut();

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() =>
      _remoteDataSource.getCurrentUser();

  @override
  Future<Either<Failure, void>> sendEmailVerification() =>
      _remoteDataSource.sendEmailVerification();

  @override
  Future<Either<Failure, bool>> checkEmailVerification() =>
      _remoteDataSource.checkEmailVerification();

  @override
  Future<Either<Failure, void>> applyEmailVerificationActionCode(
    String actionCode,
  ) => _remoteDataSource.applyEmailVerificationActionCode(actionCode);

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) =>
      _remoteDataSource.sendPasswordResetEmail(email);
}
