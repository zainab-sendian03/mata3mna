import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';

class CheckEmailVerification {
  final AuthRepository repository;

  CheckEmailVerification(this.repository);

  Future<Either<Failure, bool>> call() async {
    return await repository.checkEmailVerification();
  }
}

