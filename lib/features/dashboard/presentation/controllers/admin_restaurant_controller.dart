import 'package:get/get.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';

/// Controller for managing restaurants in admin dashboard
class AdminRestaurantController extends GetxController {
  final AdminFirestoreService _adminService = Get.find<AdminFirestoreService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();

  final RxList<Map<String, dynamic>> restaurants = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadRestaurants();
  }

  /// Load all restaurants
  void loadRestaurants() {
    isLoading.value = true;
    errorMessage.value = '';

    _adminService
        .getAllRestaurants()
        .then((restaurantsList) {
          restaurants.value = restaurantsList;
          isLoading.value = false;
          errorMessage.value = '';
        })
        .catchError((error) {
          print(
            '[AdminRestaurantController] Error loading restaurants: $error',
          );
          errorMessage.value = 'خطأ في تحميل المطاعم: $error';
          isLoading.value = false;
        });
  }

  /// Get filtered restaurants based on search query
  List<Map<String, dynamic>> get filteredRestaurants {
    if (searchQuery.value.isEmpty) {
      return restaurants;
    }

    final query = searchQuery.value.toLowerCase();
    return restaurants.where((restaurant) {
      final name = (restaurant['name'] ?? '').toString().toLowerCase();
      final phone = (restaurant['phone'] ?? '').toString().toLowerCase();
      final governorate = (restaurant['governorate'] ?? '')
          .toString()
          .toLowerCase();
      final city = (restaurant['city'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          phone.contains(query) ||
          governorate.contains(query) ||
          city.contains(query);
    }).toList();
  }

  /// Create a new restaurant
  Future<bool> createRestaurant({
    required String ownerId,
    required String ownerEmail,
    required String name,
    required String phone,
    required String governorate,
    required String city,
    String? description,
    String? logoPath,
    String? status,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      print(
        'Controller: Creating restaurant for ownerId: $ownerId, ownerEmail: $ownerEmail',
      );
      print('Controller: Restaurant name: $name, phone: $phone');
      print('Controller: Governorate: $governorate, city: $city');

      final restaurantId = await _adminService.createRestaurant(
        ownerId: ownerId,
        ownerEmail: ownerEmail,
        name: name,
        phone: phone,
        governorate: governorate,
        city: city,
        description: description,
        logoPath: logoPath,
        status: status,
      );

      print(
        'Controller: Restaurant created successfully with ID: $restaurantId',
      );

      // Double-check the restaurant exists
      final restaurant = await _adminService.getRestaurantById(restaurantId);
      if (restaurant == null) {
        print('WARNING: Restaurant was created but cannot be retrieved!');
        errorMessage.value =
            'تم إنشاء المطعم ولكن لا يمكن العثور عليه. يرجى التحقق من قاعدة البيانات.';
        isLoading.value = false;
        return false;
      }

      print('Controller: Verified restaurant exists: ${restaurant['name']}');

      isLoading.value = false;
      return true;
    } catch (e) {
      // Extract error message
      final errorMsg = e.toString();
      print('Controller: Error creating restaurant: $e');
      print('Controller: Error type: ${e.runtimeType}');
      if (errorMsg.contains('مطعم بالفعل')) {
        errorMessage.value =
            'المالك لديه مطعم بالفعل. كل بريد إلكتروني يمكن أن يكون له مطعم واحد فقط.';
      } else {
        errorMessage.value = 'خطأ في إنشاء المطعم: $e';
      }
      isLoading.value = false;
      return false;
    }
  }

  /// Update a restaurant
  Future<bool> updateRestaurant({
    required String restaurantId,
    String? name,
    String? phone,
    String? governorate,
    String? city,
    String? description,
    String? logoPath,
    String? status,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.updateRestaurant(
        restaurantId: restaurantId,
        name: name,
        phone: phone,
        governorate: governorate,
        city: city,
        description: description,
        logoPath: logoPath,
        status: status,
      );

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في تحديث المطعم: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Delete a restaurant and all its associated data (menu items, categories)
  Future<bool> deleteRestaurant(String restaurantId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Delete restaurant and get ownerId/ownerEmail for cache cleanup
      final result = await _adminService.deleteRestaurant(restaurantId);
      final ownerId = result['ownerId'] ?? '';

      // Delete categories and category images from cache
      if (ownerId.isNotEmpty) {
        try {
          // Get categories from cache first (before deleting) to delete their images
          final categoriesKey = 'menuCategories_$ownerId';
          final savedCategories = _cacheHelper.getStringList(
            key: categoriesKey,
          );

          // Delete all category images for this owner
          if (savedCategories != null && savedCategories.isNotEmpty) {
            for (final category in savedCategories) {
              final imageKey = '${ownerId}_$category';
              await _cacheHelper.removeCategoryImage(imageKey);
            }
          }

          // Also try to delete common category images as fallback
          final commonCategories = [
            'المقبلات',
            'الأطباق الرئيسية',
            'الحلويات',
            'المشروبات',
            'غير مصنف',
          ];

          for (final category in commonCategories) {
            final imageKey = '${ownerId}_$category';
            await _cacheHelper.removeCategoryImage(imageKey);
          }

          // Delete categories list from cache
          await _cacheHelper.removeData(key: categoriesKey);

          print(
            '[AdminRestaurantController] Deleted categories and images from cache for ownerId: $ownerId',
          );
        } catch (e) {
          // Log error but don't fail the deletion
          print(
            '[AdminRestaurantController] Error deleting categories from cache: $e',
          );
        }
      }

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في حذف المطعم: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Refresh restaurants list
  void refresh() {
    loadRestaurants();
  }
}
