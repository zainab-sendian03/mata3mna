import 'package:get/get.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/dashboard/data/services/dashboard_firestore_service.dart';

/// Controller for managing dashboard state and statistics
class DashboardController extends GetxController {
  final DashboardFirestoreService _dashboardService;
  final CacheHelper _cacheHelper;

  DashboardController({
    required DashboardFirestoreService dashboardService,
    required CacheHelper cacheHelper,
  })  : _dashboardService = dashboardService,
        _cacheHelper = cacheHelper;

  // Observable state
  final RxInt totalRestaurants = 0.obs;
  final RxInt totalMenuItems = 0.obs;
  final RxInt totalCategories = 0.obs;
  final RxInt totalUsers = 0.obs;
  final RxList<Map<String, dynamic>> popularItems = <Map<String, dynamic>>[].obs;
  final RxMap<String, int> itemsByCategory = <String, int>{}.obs;
  final RxList<Map<String, dynamic>> recentItems = <Map<String, dynamic>>[].obs;
  final RxMap<String, int> restaurantsByStatus = <String, int>{}.obs;
  final RxList<Map<String, dynamic>> recentRestaurants = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  /// Load all dashboard statistics (admin view - system-wide)
  Future<void> loadDashboardData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Check if user is admin
      final userRole = _cacheHelper.getData(key: 'userRole') as String?;
      if (userRole != 'admin') {
        errorMessage.value = 'غير مصرح لك بالوصول إلى لوحة التحكم';
        isLoading.value = false;
        return;
      }

      // Load all statistics in parallel
      await Future.wait([
        _loadTotalRestaurants(),
        _loadTotalMenuItems(),
        _loadTotalCategories(),
        _loadTotalUsers(),
        _loadPopularItems(),
        _loadItemsByCategory(),
        _loadRecentItems(),
        _loadRestaurantsByStatus(),
        _loadRecentRestaurants(),
      ]);
    } catch (e) {
      errorMessage.value = 'حدث خطأ أثناء تحميل البيانات: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadTotalRestaurants() async {
    try {
      final count = await _dashboardService.getTotalRestaurants();
      totalRestaurants.value = count;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadTotalMenuItems() async {
    try {
      final count = await _dashboardService.getTotalMenuItems();
      totalMenuItems.value = count;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadTotalCategories() async {
    try {
      final count = await _dashboardService.getTotalCategories();
      totalCategories.value = count;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadTotalUsers() async {
    try {
      final count = await _dashboardService.getTotalUsers();
      totalUsers.value = count;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadPopularItems() async {
    try {
      final items = await _dashboardService.getPopularItems(limit: 5);
      popularItems.value = items;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadItemsByCategory() async {
    try {
      final distribution = await _dashboardService.getItemsByCategory();
      itemsByCategory.value = distribution;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadRecentItems() async {
    try {
      final items = await _dashboardService.getRecentItems();
      recentItems.value = items;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadRestaurantsByStatus() async {
    try {
      final distribution = await _dashboardService.getRestaurantsByStatus();
      restaurantsByStatus.value = distribution;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> _loadRecentRestaurants() async {
    try {
      final restaurants = await _dashboardService.getRecentRestaurants();
      recentRestaurants.value = restaurants;
    } catch (e) {
      // Handle error silently or log it
    }
  }

  /// Refresh dashboard data
  Future<void> refresh() async {
    await loadDashboardData();
  }
}

