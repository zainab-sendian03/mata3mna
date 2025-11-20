import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mata3mna/features/auth/data/datesources/auth_remote_data_source.dart';
import 'package:mata3mna/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';

class ServiceLocator {
  static void init() {
    // External dependencies
    Get.put<FirebaseAuth>(FirebaseAuth.instance);
    Get.put<GoogleSignIn>(GoogleSignIn());

    // Data sources
    Get.put<AuthRemoteDataSource>(
      AuthRemoteDataSourceImpl(
        auth: Get.find<FirebaseAuth>(),
        googleSignIn: Get.find<GoogleSignIn>(),
      ),
    );

    // Repositories
    Get.put<AuthRepository>(
      AuthRepositoryImpl(Get.find<AuthRemoteDataSource>()),
    );

    // Controllers
    Get.put<AuthController>(
      AuthController(authRepository: Get.find<AuthRepository>()),
    );
  }
}
