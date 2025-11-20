import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';

class SendPasswordResetEmail {
  final AuthRepository repository;

  SendPasswordResetEmail(this.repository);

  Future<Either<Failure, void>> call(String email) async {
    return await repository.sendPasswordResetEmail(email);
  }
}

