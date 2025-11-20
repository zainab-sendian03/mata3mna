import 'package:mata3mna/features/auth/domain/entities/user_entity.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';

class SignUpWithEmailAndPassword {
  final AuthRepository repository;

  SignUpWithEmailAndPassword(this.repository);
  Future<Either<Failure, UserEntity?>> call(
    String email,
    String password, {
    String? displayName,
  }) async {
    return await repository.signUpWithEmailAndPassword(
      email,
      password,
      displayName: displayName,
    );
  }
}
