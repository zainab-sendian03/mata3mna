import 'package:get/get.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/dashboard/data/services/location_firestore_service.dart';

/// Controller for managing locations (governorates and cities) in the admin dashboard
class LocationManagementController extends GetxController {
  final LocationFirestoreService _locationService;
  final CacheHelper _cacheHelper;

  LocationManagementController({
    required LocationFirestoreService locationService,
    required CacheHelper cacheHelper,
  }) : _locationService = locationService,
       _cacheHelper = cacheHelper;

  // Observable state
  final RxList<String> governorates = <String>[].obs;
  final RxMap<String, List<String>> citiesByGovernorate =
      <String, List<String>>{}.obs;
  final RxString selectedGovernorate = ''.obs;
  final RxList<String> selectedGovernorateCities = <String>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadLocations();
  }

  /// Load all governorates and cities
  Future<void> loadLocations() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Check if user is admin
      final userRole = _cacheHelper.getData(key: 'userRole') as String?;
      if (userRole != 'admin') {
        errorMessage.value = 'غير مصرح لك بالوصول إلى إدارة المناطق';
        isLoading.value = false;
        return;
      }

      // Load governorates
      final loadedGovernorates = await _locationService.getGovernorates();
      governorates.value = loadedGovernorates;

      // If no governorates exist, initialize default locations first
      if (loadedGovernorates.isEmpty) {
        try {
          await _locationService.initializeDefaultLocations();
          // Reload governorates after initialization
          final reloadedGovernorates = await _locationService.getGovernorates();
          governorates.value = reloadedGovernorates;
        } catch (e) {
          // ignore: avoid_print
          print(
            '[LocationManagementController] Error initializing locations: $e',
          );
        }
      }

      // Load cities grouped by governorate
      final loadedCitiesMap = await _locationService
          .getCitiesByGovernorateMap();
      citiesByGovernorate.value = loadedCitiesMap;
    } catch (e) {
      errorMessage.value = 'حدث خطأ أثناء تحميل المناطق: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  /// Select a governorate and load its cities
  void selectGovernorate(String governorate) {
    selectedGovernorate.value = governorate;
    selectedGovernorateCities.value = citiesByGovernorate[governorate] ?? [];
  }

  /// Add a new governorate
  Future<bool> addGovernorate(String name) async {
    try {
      if (name.trim().isEmpty) {
        Get.snackbar('خطأ', 'اسم المحافظة لا يمكن أن يكون فارغاً');
        return false;
      }

      await _locationService.addGovernorate(name.trim());
      await loadLocations(); // Reload to refresh the list
      Get.snackbar('نجح', 'تم إضافة المحافظة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
      return false;
    }
  }

  /// Update a governorate name
  Future<bool> updateGovernorate(String oldName, String newName) async {
    try {
      if (newName.trim().isEmpty) {
        Get.snackbar('خطأ', 'اسم المحافظة لا يمكن أن يكون فارغاً');
        return false;
      }

      await _locationService.updateGovernorate(oldName, newName.trim());
      await loadLocations(); // Reload to refresh the list
      Get.snackbar('نجح', 'تم تحديث المحافظة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
      return false;
    }
  }

  /// Delete a governorate
  Future<bool> deleteGovernorate(String name) async {
    try {
      await _locationService.deleteGovernorate(name);
      await loadLocations(); // Reload to refresh the list
      Get.snackbar('نجح', 'تم حذف المحافظة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
      return false;
    }
  }

  /// Add a new city to the selected governorate
  Future<bool> addCity(String cityName) async {
    try {
      if (selectedGovernorate.value.isEmpty) {
        Get.snackbar('خطأ', 'يرجى اختيار محافظة أولاً');
        return false;
      }

      if (cityName.trim().isEmpty) {
        Get.snackbar('خطأ', 'اسم المدينة لا يمكن أن يكون فارغاً');
        return false;
      }

      await _locationService.addCity(
        selectedGovernorate.value,
        cityName.trim(),
      );
      await loadLocations(); // Reload to refresh the list
      selectGovernorate(selectedGovernorate.value); // Refresh selected cities
      Get.snackbar('نجح', 'تم إضافة المدينة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
      return false;
    }
  }

  /// Update a city name
  Future<bool> updateCity(String oldCityName, String newCityName) async {
    try {
      if (selectedGovernorate.value.isEmpty) {
        Get.snackbar('خطأ', 'يرجى اختيار محافظة أولاً');
        return false;
      }

      if (newCityName.trim().isEmpty) {
        Get.snackbar('خطأ', 'اسم المدينة لا يمكن أن يكون فارغاً');
        return false;
      }

      await _locationService.updateCity(
        selectedGovernorate.value,
        oldCityName,
        newCityName.trim(),
      );
      await loadLocations(); // Reload to refresh the list
      selectGovernorate(selectedGovernorate.value); // Refresh selected cities
      Get.snackbar('نجح', 'تم تحديث المدينة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
      return false;
    }
  }

  /// Delete a city
  Future<bool> deleteCity(String cityName) async {
    try {
      if (selectedGovernorate.value.isEmpty) {
        Get.snackbar('خطأ', 'يرجى اختيار محافظة أولاً');
        return false;
      }

      await _locationService.deleteCity(selectedGovernorate.value, cityName);
      await loadLocations(); // Reload to refresh the list
      selectGovernorate(selectedGovernorate.value); // Refresh selected cities
      Get.snackbar('نجح', 'تم حذف المدينة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
      return false;
    }
  }

  /// Refresh locations
  Future<void> refresh() async {
    await loadLocations();
  }
}
