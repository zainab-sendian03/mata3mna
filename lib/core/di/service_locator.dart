import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mata3mna/features/auth/data/datesources/auth_remote_data_source.dart';
import 'package:mata3mna/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mata3mna/features/home/presentation/controllers/customer_view_controller.dart';
import 'package:mata3mna/features/dashboard/data/services/dashboard_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/location_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';

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

    // Services (lazy - only created when needed)
    Get.lazyPut<RestaurantFirestoreService>(
      () => RestaurantFirestoreService(),
      fenix: true,
    );
    Get.lazyPut<SupabaseStorageService>(
      () => SupabaseStorageService(),
      fenix: true,
    );
    Get.lazyPut<MenuFirestoreService>(
      () => MenuFirestoreService(
        restaurantService: Get.find<RestaurantFirestoreService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<DashboardFirestoreService>(
      () => DashboardFirestoreService(),
      fenix: true,
    );
    Get.lazyPut<LocationFirestoreService>(
      () => LocationFirestoreService(),
      fenix: true,
    );
    Get.lazyPut<AdminFirestoreService>(
      () => AdminFirestoreService(),
      fenix: true,
    );

    // Controllers
    // AuthController is needed immediately for auth state checking
    Get.put<AuthController>(
      AuthController(authRepository: Get.find<AuthRepository>()),
    );

    // CartController (lazy - created when needed)
    Get.lazyPut<CartController>(() => CartController(), fenix: true);

    // CustomerViewController (lazy - created when needed)
    Get.lazyPut<CustomerViewController>(
      () => CustomerViewController(),
      fenix: true,
    );

    // DashboardController (lazy - created when needed)
    Get.lazyPut<DashboardController>(
      () => DashboardController(
        dashboardService: Get.find<DashboardFirestoreService>(),
        cacheHelper: Get.find<CacheHelper>(),
      ),
      fenix: true,
    );
  }
}
