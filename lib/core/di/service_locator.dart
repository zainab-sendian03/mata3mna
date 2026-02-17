import 'package:get/get.dart';
import 'package:mata3mna/features/auth/data/datesources/auth_remote_data_source.dart';
import 'package:mata3mna/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mata3mna/features/auth/domain/repositories/auth_repository.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mata3mna/features/home/presentation/controllers/customer_view_controller.dart';
import 'package:mata3mna/features/dashboard/data/services/dashboard_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/location_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceLocator {
  static void init() {
    // Use Supabase.instance.client so auth and CRUD share the SAME session.
    // Previously a separate SupabaseClient was used for auth, so login never
    // persisted to the client used by CRUD services.
    Get.lazyPut<SupabaseClient>(() => Supabase.instance.client);

    Get.lazyPut<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(supabase: Get.find<SupabaseClient>()),
      fenix: true,
    );

    // Repositories
    Get.put<AuthRepository>(
      AuthRepositoryImpl(Get.find<AuthRemoteDataSource>()),
    );

    Get.lazyPut<SupabaseStorageService>(
      () => SupabaseStorageService(),
      fenix: true,
    );
    Get.lazyPut<MenuSupabaseService>(() => MenuSupabaseService(), fenix: true);
    Get.lazyPut<DashboardSupabaseService>(
      () => DashboardSupabaseService(),
      fenix: true,
    );
    Get.lazyPut<LocationSupabaseService>(
      () => LocationSupabaseService(),
      fenix: true,
    );
    Get.lazyPut<AdminFirestoreService>(
      () => AdminFirestoreService(),
      fenix: true,
    );
    Get.lazyPut(() => RestaurantSupabaseService());
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
        dashboardService: Get.find<DashboardSupabaseService>(),
        cacheHelper: Get.find<CacheHelper>(),
      ),
      fenix: true,
    );
  }
}
