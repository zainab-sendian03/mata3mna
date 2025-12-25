import 'package:dartz/dartz.dart';
import 'package:mata3mna/core/errors/failure.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';

class ApplyEmailVerificationActionCode {
  final AuthRepository repository;

  ApplyEmailVerificationActionCode(this.repository);

  Future<Either<Failure, void>> call(String actionCode) async {
    return await repository.applyEmailVerificationActionCode(actionCode);
  }
}

