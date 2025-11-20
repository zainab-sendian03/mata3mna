import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/entities/user_entity.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';

class SignInWithEmail {
  final AuthRepository repository;

  SignInWithEmail(this.repository);

  Future<Either<Failure, UserEntity?>> call(
    String email,
    String password,
  ) async {
    return await repository.signInWithEmailAndPassword(email, password);
  }
}
