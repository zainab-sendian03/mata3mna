import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';

class SendEmailVerification {
  final AuthRepository repository;

  SendEmailVerification(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.sendEmailVerification();
  }
}

