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
  ) async {
    try {
      final user = await _remoteDataSource.signInWithEmailAndPassword(
        email,
        password,
      );
      return user;
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> signInWithGoogle() async {
    try {
      final user = await _remoteDataSource.signInWithGoogle();
      return user;
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = await _remoteDataSource.getCurrentUser();
      return user;
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final user = await _remoteDataSource.signUpWithEmailAndPassword(
        email,
        password,
        displayName: displayName,
      );
      return user;
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      return await _remoteDataSource.sendPasswordResetEmail(email);
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      return await _remoteDataSource.sendEmailVerification();
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }

  @override
  Future<Either<Failure, bool>> checkEmailVerification() async {
    try {
      return await _remoteDataSource.checkEmailVerification();
    } catch (e) {
      return Left(Failure(errMessage: e.toString(), statusCode: 500));
    }
  }
}
