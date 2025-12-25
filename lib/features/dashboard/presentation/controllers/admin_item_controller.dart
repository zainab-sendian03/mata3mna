import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';

/// Controller for managing menu items in admin dashboard
class AdminItemController extends GetxController {
  final AdminFirestoreService _adminService = Get.find<AdminFirestoreService>();

  final RxList<Map<String, dynamic>> items = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadItems();
  }

  /// Load all menu items
  void loadItems() {
    isLoading.value = true;
    errorMessage.value = '';

    _adminService.getAllMenuItems().listen(
      (itemsList) {
        items.value = itemsList;
        isLoading.value = false;
      },
      onError: (error) {
        errorMessage.value = 'خطأ في تحميل العناصر: $error';
        isLoading.value = false;
      },
    );
  }

  /// Get filtered items based on search query and category
  List<Map<String, dynamic>> get filteredItems {
    List<Map<String, dynamic>> filtered = items;

    // Filter by category
    if (selectedCategory.value.isNotEmpty &&
        selectedCategory.value != 'جميع العناصر') {
      filtered = filtered.where((item) {
        return (item['category'] ?? '').toString() == selectedCategory.value;
      }).toList();
    }

    // Filter by search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final description = (item['description'] ?? '')
            .toString()
            .toLowerCase();
        final restaurantName = (item['restaurantName'] ?? '')
            .toString()
            .toLowerCase();

        return name.contains(query) ||
            description.contains(query) ||
            restaurantName.contains(query);
      }).toList();
    }

    return filtered;
  }

  /// Get all unique categories from items
  List<String> get categories {
    final categorySet = <String>{'جميع العناصر'};
    for (final item in items) {
      final category = (item['category'] ?? '').toString();
      if (category.isNotEmpty) {
        categorySet.add(category);
      }
    }
    return categorySet.toList()..sort((a, b) {
      if (a == 'جميع العناصر') return -1;
      if (b == 'جميع العناصر') return 1;
      return a.compareTo(b);
    });
  }

  /// Create a new menu item
  Future<bool> createItem({
    required String name,
    required String category,
    required String price,
    required String ownerId,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.createMenuItem(
        name: name,
        category: category,
        price: price,
        ownerId: ownerId,
        description: description,
        imageUrl: imageUrl,
        restaurantName: restaurantName,
      );

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في إنشاء العنصر: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Update a menu item
  Future<bool> updateItem({
    required String itemId,
    String? name,
    String? category,
    String? price,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.updateMenuItem(
        itemId: itemId,
        name: name,
        category: category,
        price: price,
        description: description,
        imageUrl: imageUrl,
        restaurantName: restaurantName,
      );

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في تحديث العنصر: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Delete a menu item
  Future<bool> deleteItem(String itemId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.deleteMenuItem(itemId);

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في حذف العنصر: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Refresh items list
  void refresh() {
    loadItems();
  }
}
