import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';

/// Controller for managing categories in admin dashboard
class AdminCategoryController extends GetxController {
  final AdminFirestoreService _adminService = Get.find<AdminFirestoreService>();

  final RxList<String> categories = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxMap<String, int> categoryItemCounts = <String, int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  /// Load all categories
  Future<void> loadCategories() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final categoriesList = await _adminService.getAllCategories();
      categories.value = categoriesList;
      
      // Load item counts for each category
      await _loadCategoryItemCounts();
      
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'خطأ في تحميل الفئات: $e';
      isLoading.value = false;
    }
  }

  /// Load item counts for each category
  Future<void> _loadCategoryItemCounts() async {
    try {
      // Use stream to get real-time updates
      // getAllMenuItems() already processes items and adds 'category' field
      _adminService.getAllMenuItems().listen((items) {
        final counts = <String, int>{};
        
        // Process items - getAllMenuItems() should already have 'category' populated
        for (final item in items) {
          // getAllMenuItems() processes items using asyncMap and adds 'category' from 'category_id'
          // So we should use 'category' directly
          final category = (item['category'] ?? 'غير مصنف').toString();
          
          if (category.isNotEmpty && category != 'null') {
            counts[category] = (counts[category] ?? 0) + 1;
          } else {
            // Fallback: if category is not populated, count as unclassified
            counts['غير مصنف'] = (counts['غير مصنف'] ?? 0) + 1;
          }
        }
        
        categoryItemCounts.value = counts;
        print('[AdminCategoryController] Updated category counts: $counts');
      });
    } catch (e) {
      print('[AdminCategoryController] Error loading category counts: $e');
    }
  }

  /// Get filtered categories based on search query
  List<String> get filteredCategories {
    if (searchQuery.value.isEmpty) {
      return categories;
    }

    final query = searchQuery.value.toLowerCase();
    return categories.where((category) {
      return category.toLowerCase().contains(query);
    }).toList();
  }

  /// Get item count for a category
  int getItemCount(String category) {
    return categoryItemCounts[category] ?? 0;
  }

  /// Create a new category
  Future<bool> createCategory(String categoryName) async {
    try {
      if (categoryName.trim().isEmpty) {
        errorMessage.value = 'اسم الفئة لا يمكن أن يكون فارغاً';
        return false;
      }

      if (categories.contains(categoryName.trim())) {
        errorMessage.value = 'هذه الفئة موجودة بالفعل';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.createCategory(categoryName.trim());
      
      // Reload categories
      await loadCategories();

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في إنشاء الفئة: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Update a category name
  Future<bool> updateCategory({
    required String oldCategory,
    required String newCategory,
  }) async {
    try {
      if (newCategory.trim().isEmpty) {
        errorMessage.value = 'اسم الفئة لا يمكن أن يكون فارغاً';
        return false;
      }

      if (oldCategory == newCategory.trim()) {
        return true; // No change needed
      }

      if (categories.contains(newCategory.trim()) &&
          oldCategory != newCategory.trim()) {
        errorMessage.value = 'هذه الفئة موجودة بالفعل';
        return false;
      }

      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.updateCategoryName(
        oldCategory: oldCategory,
        newCategory: newCategory.trim(),
      );

      // Reload categories
      loadCategories();

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في تحديث الفئة: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Delete a category (moves items to "غير مصنف")
  Future<bool> deleteCategory(String category) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _adminService.deleteCategory(category);

      // Wait a bit for Firestore to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Reload categories to get updated list
      await loadCategories();

      isLoading.value = false;
      return true;
    } catch (e) {
      errorMessage.value = 'خطأ في حذف الفئة: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// Refresh categories list
  void refresh() {
    loadCategories();
  }
}
