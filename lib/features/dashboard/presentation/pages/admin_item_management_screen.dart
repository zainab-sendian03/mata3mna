import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/admin_item_controller.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';

/// Screen for managing menu items in admin dashboard
class AdminItemManagementScreen extends StatelessWidget {
  const AdminItemManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminItemController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Get category or restaurant from arguments if provided
    final arguments = Get.arguments;
    Future.delayed(Duration(milliseconds: 100), () {
      if (arguments != null && arguments is Map) {
        if (arguments['category'] != null) {
          controller.selectedCategory.value = arguments['category'] as String;
        }
        if (arguments['restaurantId'] != null) {
          controller.setRestaurantFilter(
            arguments['restaurantId'] as String?,
            restaurantName: arguments['restaurantName'] as String?,
          );
        } else {
          controller.setRestaurantFilter(null);
        }
      } else {
        controller.setRestaurantFilter(null);
      }
    });

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    return Obx(() {
      return Material(
        child: Column(
          children: [
            // Header bar (when AppBar is hidden)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: isDesktop ? 16 : 12,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                    onPressed: () => Get.back(),
                  ),
                  Expanded(
                    child: Text(
                      controller.selectedRestaurantName.value.isNotEmpty
                          ? 'عناصر ${controller.selectedRestaurantName.value}'
                          : 'إدارة العناصر',
                      style: isDesktop
                          ? theme.textTheme.displaySmall?.copyWith(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            )
                          : theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: colorScheme.onSurface),
                    onPressed: () =>
                        _showAddEditItemDialog(context, controller, null),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                    onPressed: () => controller.refresh(),
                  ),
                ],
              ),
            ),

            // Search and filter bar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : (isTablet ? 32 : 20),
                vertical: isDesktop ? 24 : (isTablet ? 20 : 16),
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  child: Column(
                    children: [
                      // Search
                      TextField(
                        onChanged: (value) =>
                            controller.searchQuery.value = value,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                        ),
                        decoration: InputDecoration(
                          hintText: 'بحث في العناصر...',
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: controller.searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      controller.searchQuery.value = '',
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 16 : 12,
                            vertical: isDesktop ? 16 : 14,
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 16 : 12),
                      // Category filter
                      Obx(() {
                        if (controller.categories.isEmpty)
                          return SizedBox.shrink();
                        return DropdownButtonFormField<String>(
                          value: controller.selectedCategory.value.isEmpty
                              ? 'جميع العناصر'
                              : controller.selectedCategory.value,
                          style: TextStyle(
                            fontSize: isDesktop
                                ? 16.0
                                : (isTablet ? 15.0 : 14.0),
                          ),
                          decoration: InputDecoration(
                            labelText: 'الفئة',
                            labelStyle: TextStyle(
                              fontSize: isDesktop
                                  ? 15.0
                                  : (isTablet ? 14.0 : 13.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 12,
                              vertical: isDesktop ? 16 : 14,
                            ),
                          ),
                          items: controller.categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: isDesktop
                                      ? 16.0
                                      : (isTablet ? 15.0 : 14.0),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            controller.selectedCategory.value =
                                value ?? 'جميع العناصر';
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Items list
            Expanded(
              child: controller.filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0),
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          SizedBox(
                            height: isDesktop ? 24 : (isTablet ? 20 : 16),
                          ),
                          Text(
                            controller.searchQuery.value.isNotEmpty ||
                                    controller.selectedCategory.value.isNotEmpty
                                ? 'لا توجد نتائج'
                                : 'لا توجد عناصر',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1400 : double.infinity,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.all(
                            isDesktop ? 24 : (isTablet ? 20 : 16),
                          ),
                          itemCount: controller.filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = controller.filteredItems[index];
                            return _buildItemCard(
                              context,
                              item,
                              controller,
                              theme,
                              colorScheme,
                              isDesktop,
                              isTablet,
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  /// Helper method to get owner info from item using restaurant_id
  Future<Map<String, dynamic>?> _getOwnerInfo(Map<String, dynamic> item) async {
    try {
      final supabase = Supabase.instance.client;

      final restaurantId = item['restaurant_id'];
      if (restaurantId == null || restaurantId.toString().isEmpty) {
        return null;
      }

      final restaurant = await supabase
          .from('restaurants')
          .select('owner_id, owner_email')
          .eq('id', restaurantId)
          .maybeSingle();

      if (restaurant == null) return null;

      final ownerId = restaurant['owner_id'] as String? ?? '';
      final ownerEmail = restaurant['owner_email'] as String? ?? '';

      // Try to get more info from users table
      if (ownerId.isNotEmpty) {
        try {
          final userInfo = await supabase
              .from('users')
              .select('id, email, role')
              .eq('id', ownerId)
              .maybeSingle();

          if (userInfo != null) {
            return {
              'id': ownerId,
              'email': userInfo['email'] ?? ownerEmail,
              'owner_email': ownerEmail,
            };
          }
        } catch (e) {
          print('[AdminItemManagementScreen] Error getting user info: $e');
        }
      }

      return {'id': ownerId, 'email': ownerEmail, 'owner_email': ownerEmail};
    } catch (e) {
      print('[AdminItemManagementScreen] Error getting owner info: $e');
      return null;
    }
  }

  /// Helper method to get restaurant name from item using restaurant_id
  Future<String> _getRestaurantName(Map<String, dynamic> item) async {
    // First check if restaurant_name exists
    if (item['restaurant_name'] != null &&
        item['restaurant_name'].toString().isNotEmpty) {
      return item['restaurant_name'].toString();
    }

    // If not, try to get from restaurant_id
    if (item['restaurant_id'] != null) {
      try {
        final supabase = Supabase.instance.client;
        final restaurant = await supabase
            .from('restaurants')
            .select('name')
            .eq('id', item['restaurant_id'])
            .maybeSingle();

        if (restaurant != null && restaurant['name'] != null) {
          return restaurant['name'].toString();
        }
      } catch (e) {
        print('[AdminItemManagementScreen] Error getting restaurant name: $e');
      }
    }

    return '';
  }

  /// Helper method to get category name from item
  Future<String> _getCategoryName(
    Map<String, dynamic> item,
    AdminItemController controller,
  ) async {
    // First check if category name exists
    if (item['category'] != null && item['category'].toString().isNotEmpty) {
      return item['category'].toString();
    }

    // If not, try to get from category_id
    if (item['category_id'] != null) {
      try {
        final adminService = Get.find<AdminFirestoreService>();
        final categoryName = await adminService.getCategoryNameById(
          item['category_id'],
        );
        if (categoryName != null && categoryName.isNotEmpty) {
          return categoryName;
        }
      } catch (e) {
        print('[AdminItemManagementScreen] Error getting category name: $e');
      }
    }

    return 'غير مصنف';
  }

  Widget _buildItemCard(
    BuildContext context,
    Map<String, dynamic> item,
    AdminItemController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final imageUrl = item['image'] as String? ?? '';
    final imageSize = isDesktop ? 100.0 : (isTablet ? 80.0 : 60.0);
    final cardPadding = isDesktop ? 20.0 : (isTablet ? 20.0 : 16.0);
    final cardSpacing = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);
    final description = item['description']?.toString() ?? '';
    final hasDescription = description.isNotEmpty;

    return StatefulBuilder(
      builder: (context, setState) {
        // Use a unique key for each item to track expansion state
        final itemId = item['id'] as String? ?? '';
        final expansionKey = '_desc_expanded_$itemId';
        final isExpanded = item[expansionKey] as bool? ?? false;

        return Card(
          margin: EdgeInsets.only(
            bottom: isDesktop ? 10 : (isTablet ? 16 : 12),
          ),
          elevation: isDesktop ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outline),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: imageSize,
                            height: imageSize,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.fastfood,
                              size: imageSize * 0.5,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        )
                      : Container(
                          width: imageSize,
                          height: imageSize,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.fastfood,
                            size: imageSize * 0.5,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                ),
                SizedBox(width: cardSpacing),

                // Item info - Flexible to expand with description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['name'] ?? 'بدون اسم',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FutureBuilder<String>(
                              future: _getCategoryName(item, controller),
                              builder: (context, snapshot) {
                                final categoryName =
                                    snapshot.data ??
                                    (item['category']?.toString() ??
                                        'غير مصنف');
                                return Text(
                                  categoryName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isDesktop
                                        ? 13
                                        : (isTablet ? 12 : 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${item['price'] ?? '0'} \$',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                            ),
                          ),
                        ],
                      ),
                      // Show restaurant name
                      FutureBuilder<String>(
                        future: _getRestaurantName(item),
                        builder: (context, snapshot) {
                          final restaurantName = snapshot.data ?? '';
                          if (restaurantName.isEmpty) return SizedBox.shrink();

                          return Column(
                            children: [
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    size: 16,
                                    color: colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      restaurantName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withOpacity(0.7),
                                            fontSize: isDesktop
                                                ? 16
                                                : (isTablet ? 15 : 14),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      if (hasDescription) ...[
                        SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            // Show "Read more" if description is long enough to potentially overflow 2 lines
                            // Approximate: ~50 characters per line for Arabic text
                            final shouldShowReadMore =
                                description.length > 100 ||
                                description.split('\n').length > 2;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: isDesktop
                                        ? 16
                                        : (isTablet ? 15 : 14),
                                    color: colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                                  ),
                                  maxLines: isExpanded ? null : 2,
                                  overflow: isExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                ),
                                if (shouldShowReadMore)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        item[expansionKey] = !isExpanded;
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        isExpanded ? 'اقرأ أقل' : 'اقرأ المزيد',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: isDesktop
                                                  ? 13
                                                  : (isTablet ? 12 : 11),
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions - Aligned to top
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () =>
                          _showAddEditItemDialog(context, controller, item),
                      color: colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _showDeleteDialog(context, controller, item),
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddEditItemDialog(
    BuildContext context,
    AdminItemController controller,
    Map<String, dynamic>? item,
  ) async {
    final isEdit = item != null;
    final nameController = TextEditingController(
      text: item?['name'] is String
          ? item!['name'] as String
          : (item?['name']?.toString() ?? ''),
    );
    // Handle price - it might be int, double, or String
    final priceValue = item?['price'];
    final priceText = priceValue is String
        ? priceValue
        : (priceValue != null ? priceValue.toString() : '');
    final priceController = TextEditingController(text: priceText);
    final descriptionController = TextEditingController(
      text: item?['description'] is String
          ? item!['description'] as String
          : (item?['description']?.toString() ?? ''),
    );
    String? selectedOwnerId = item?['ownerId'];
    Map<String, dynamic>? selectedOwner;
    final restaurantNameController = TextEditingController(
      text: item?['restaurantName'] ?? '',
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storageService = Get.find<SupabaseStorageService>();
    final adminService = Get.find<AdminFirestoreService>();
    final imagePicker = ImagePicker();

    // Get category name from category_id if editing
    String? selectedCategory;
    if (item != null) {
      try {
        // First try to get category name from category_id
        final categoryId = item['category_id'];
        if (categoryId != null) {
          final categoryName = await adminService.getCategoryNameById(
            categoryId,
          );
          if (categoryName != null && categoryName.isNotEmpty) {
            selectedCategory = categoryName;
          }
        }

        // Fallback to category field if category_id lookup failed
        if (selectedCategory == null || selectedCategory.isEmpty) {
          final categoryField = item['category'];
          if (categoryField != null) {
            selectedCategory = categoryField is String
                ? categoryField
                : categoryField.toString();
          }
        }
      } catch (e) {
        print('[AdminItemManagementScreen] Error getting category name: $e');
        // Fallback to category field if it exists
        final categoryField = item['category'];
        if (categoryField != null) {
          selectedCategory = categoryField is String
              ? categoryField
              : categoryField.toString();
        }
      }
    }
    String? imageUrl = item?['image'];
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    bool isLoading = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final dialogWidth = isDesktop
        ? 600.0
        : (isTablet ? 600.0 : screenWidth * 0.95);
    final dialogPadding = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final dialogSpacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    // Responsive font sizes for form fields
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

    // Refresh categories when opening dialog and wait for them to load
    await controller.loadCategories();

    // Ensure categories are loaded
    if (controller.allCategories.isEmpty) {
      print(
        '[AdminItemManagementScreen] No categories loaded, trying again...',
      );
      await Future.delayed(Duration(milliseconds: 500));
      await controller.loadCategories();
    }

    print(
      '[AdminItemManagementScreen] Categories after load: ${controller.allCategories.toList()}',
    );

    // Use a variable that persists across StatefulBuilder rebuilds
    String? currentSelectedCategory = selectedCategory;

    Get.dialog(
      Dialog(
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(dialogPadding),
          child: StatefulBuilder(
            builder: (context, setState) {
              // Create a function to update the category
              void updateCategory(String? newCategory) {
                setState(() {
                  currentSelectedCategory = newCategory;
                  selectedCategory =
                      newCategory; // Update the original variable too
                });
                print(
                  '[AdminItemManagementScreen] Category updated to: $newCategory',
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'تعديل عنصر' : 'إضافة عنصر جديد',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                      ),
                    ),
                    SizedBox(height: dialogSpacing),

                    // Owner Selection (only for new items)
                    if (!isEdit)
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: adminService.getAllOwners(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'خطأ في تحميل الملاك: ${snapshot.error}',
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            );
                          }

                          final owners = snapshot.data ?? [];

                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: adminService.getAllRestaurants(),
                            builder: (context, restaurantsSnapshot) {
                              final restaurants =
                                  restaurantsSnapshot.data ?? [];
                              final restaurantNamesMap = <String, String>{};

                              // Build a map of ownerId/ownerEmail -> restaurant name
                              for (final restaurant in restaurants) {
                                final ownerId =
                                    restaurant['owner_id'] as String? ?? '';
                                final ownerEmail =
                                    restaurant['owner_email'] as String? ?? '';
                                final restaurantName =
                                    restaurant['name'] as String? ?? '';

                                if (ownerId.isNotEmpty &&
                                    restaurantName.isNotEmpty) {
                                  restaurantNamesMap[ownerId] = restaurantName;
                                }
                                if (ownerEmail.isNotEmpty &&
                                    restaurantName.isNotEmpty) {
                                  restaurantNamesMap[ownerEmail] =
                                      restaurantName;
                                }
                              }

                              // Filter owners to only include those with restaurants
                              final ownersWithRestaurants = owners.where((
                                owner,
                              ) {
                                final ownerId =
                                    owner['id'] ?? owner['uid'] ?? '';
                                final ownerEmail = owner['email'] ?? '';
                                final hasRestaurant =
                                    restaurantNamesMap.containsKey(ownerId) ||
                                    restaurantNamesMap.containsKey(ownerEmail);
                                return hasRestaurant;
                              }).toList();

                              // Get the current selected owner ID
                              String? currentSelectedOwnerId = selectedOwnerId;
                              if (currentSelectedOwnerId == null &&
                                  selectedOwner != null) {
                                currentSelectedOwnerId =
                                    selectedOwner!['id'] ??
                                    selectedOwner!['uid'];
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: currentSelectedOwnerId,
                                    style: TextStyle(
                                      fontSize: formFieldFontSize,
                                      height: 1.2,
                                    ),
                                    decoration: InputDecoration(
                                      label: Text(
                                        'اختر المالك *',
                                        style: TextStyle(
                                          fontSize: labelFontSize,
                                        ),
                                      ),
                                      hintText: ownersWithRestaurants.isEmpty
                                          ? 'لا يوجد ملاك'
                                          : 'اختر المالك',
                                      hintStyle: TextStyle(
                                        fontSize: hintFontSize,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor:
                                          colorScheme.surfaceContainerHighest,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 16 : 12,
                                        vertical: isDesktop ? 16 : 14,
                                      ),
                                    ),
                                    selectedItemBuilder: (BuildContext context) {
                                      return ownersWithRestaurants.map((owner) {
                                        final ownerId =
                                            owner['id'] ?? owner['uid'] ?? '';
                                        final ownerEmail = owner['email'] ?? '';
                                        final restaurantName =
                                            restaurantNamesMap[ownerId] ??
                                            restaurantNamesMap[ownerEmail] ??
                                            '';
                                        return Text(
                                          restaurantName,
                                          style: TextStyle(
                                            fontSize: formFieldFontSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    items: ownersWithRestaurants.map((owner) {
                                      final ownerId =
                                          owner['id'] ?? owner['uid'] ?? '';
                                      final ownerEmail = owner['email'] ?? '';
                                      final restaurantName =
                                          restaurantNamesMap[ownerId] ??
                                          restaurantNamesMap[ownerEmail] ??
                                          '';
                                      return DropdownMenuItem<String>(
                                        value: ownerId,
                                        child: Text(
                                          restaurantName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: formFieldFontSize,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: ownersWithRestaurants.isEmpty
                                        ? null
                                        : (ownerId) {
                                            setState(() {
                                              // Find the owner object from the list
                                              final owner =
                                                  ownersWithRestaurants
                                                      .firstWhere(
                                                        (o) =>
                                                            (o['id'] ??
                                                                o['uid']) ==
                                                            ownerId,
                                                      );
                                              selectedOwner = owner;
                                              selectedOwnerId = ownerId;

                                              restaurantNameController.text =
                                                  restaurantNamesMap[ownerId] ??
                                                  restaurantNamesMap[owner['email']] ??
                                                  '';
                                            });
                                          },
                                  ),
                                  if (owners.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'لا يوجد ملاك مسجلين في النظام',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontSize: labelFontSize,
                                              color: colorScheme.error,
                                            ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    if (!isEdit) SizedBox(height: dialogSpacing),

                    // Show owner email when editing
                    if (isEdit)
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _getOwnerInfo(item),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox.shrink();
                          }
                          final ownerInfo = snapshot.data;
                          if (ownerInfo == null) return SizedBox.shrink();

                          final ownerEmail =
                              ownerInfo['email'] ??
                              ownerInfo['owner_email'] ??
                              '';
                          if (ownerEmail.isEmpty) return SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'البريد الإلكتروني للمالك:',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontSize: labelFontSize,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      size: 20,
                                      color: colorScheme.primary,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ownerEmail,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontSize: formFieldFontSize,
                                              color: colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: dialogSpacing),
                            ],
                          );
                        },
                      ),

                    // Name
                    TextField(
                      style: TextStyle(
                        fontSize: formFieldFontSize,
                        height: 1.2,
                      ),
                      controller: nameController,
                      decoration: InputDecoration(
                        label: Text(
                          'اسم العنصر *',
                          style: TextStyle(fontSize: labelFontSize),
                        ),
                        hintText: 'أدخل اسم العنصر',
                        hintStyle: TextStyle(fontSize: hintFontSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    SizedBox(height: dialogSpacing),

                    // Category
                    Obx(() {
                      // Use allCategories directly to ensure reactive updates
                      final allCats = controller.allCategories.toList();
                      print(
                        '[AdminItemManagementScreen] allCategories from controller: $allCats',
                      );

                      final categories = allCats
                          .where((c) => c.isNotEmpty && c != 'جميع العناصر')
                          .toList();

                      print(
                        '[AdminItemManagementScreen] Filtered categories for dropdown: $categories',
                      );
                      print(
                        '[AdminItemManagementScreen] Current selected category: $currentSelectedCategory',
                      );

                      // If no categories, show a message
                      if (categories.isEmpty) {
                        return DropdownButtonFormField<String>(
                          value: null,
                          decoration: InputDecoration(
                            label: Text(
                              'الفئة *',
                              style: TextStyle(fontSize: labelFontSize),
                            ),
                            hintText: 'لا توجد فئات متاحة',
                            hintStyle: TextStyle(fontSize: hintFontSize),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                          ),
                          items: [],
                          onChanged: null,
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: currentSelectedCategory,
                        style: TextStyle(
                          fontSize: formFieldFontSize,
                          height: 1.2,
                        ),
                        decoration: InputDecoration(
                          label: Text(
                            'الفئة *',
                            style: TextStyle(fontSize: labelFontSize),
                          ),
                          hintText: 'أختر الفئة',
                          hintStyle: TextStyle(fontSize: hintFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 16 : 12,
                            vertical: isDesktop ? 16 : 14,
                          ),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat,
                              style: TextStyle(fontSize: formFieldFontSize),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          print(
                            '[AdminItemManagementScreen] Category changed to: $value',
                          );
                          updateCategory(value);
                        },
                      );
                    }),
                    SizedBox(height: dialogSpacing),

                    // Price
                    TextField(
                      style: TextStyle(
                        fontSize: formFieldFontSize,
                        height: 1.2,
                      ),
                      controller: priceController,
                      decoration: InputDecoration(
                        label: Text(
                          'السعر *',
                          style: TextStyle(fontSize: labelFontSize),
                        ),
                        hintText: 'أدخل السعر',
                        hintStyle: TextStyle(fontSize: hintFontSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: dialogSpacing),

                    // Restaurant Name (read-only, especially when editing)
                    TextField(
                      style: TextStyle(
                        fontSize: formFieldFontSize,
                        height: 1.2,
                      ),
                      controller: restaurantNameController,
                      enabled: !isEdit, // Disable when editing
                      readOnly: true, // Always read-only
                      decoration: InputDecoration(
                        label: Text(
                          'اسم المطعم',
                          style: TextStyle(fontSize: labelFontSize),
                        ),
                        hintText: isEdit
                            ? 'اسم المطعم (غير قابل للتعديل)'
                            : (!isEdit && selectedOwner != null)
                            ? 'يمكنك تعديل اسم المطعم'
                            : 'أدخل اسم المطعم',
                        hintStyle: TextStyle(fontSize: hintFontSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isEdit
                            ? colorScheme.surfaceContainerHighest.withOpacity(
                                0.5,
                              )
                            : colorScheme.surfaceContainerHighest,
                        suffixIcon: (!isEdit && selectedOwner != null)
                            ? Icon(
                                Icons.edit,
                                size: 20,
                                color: colorScheme.primary.withOpacity(0.6),
                              )
                            : isEdit
                            ? Icon(
                                Icons.lock,
                                size: 20,
                                color: colorScheme.onSurface.withOpacity(0.4),
                              )
                            : null,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 16 : 12,
                          vertical: isDesktop ? 16 : 14,
                        ),
                      ),
                      onChanged: isEdit
                          ? null // No changes allowed when editing
                          : (value) {
                              // Allow manual editing only when creating new item
                              setState(() {});
                            },
                    ),
                    SizedBox(height: dialogSpacing),

                    // Description
                    TextField(
                      style: TextStyle(
                        fontSize: formFieldFontSize,
                        height: 1.2,
                      ),
                      controller: descriptionController,
                      decoration: InputDecoration(
                        label: Text(
                          'الوصف',
                          style: TextStyle(fontSize: labelFontSize),
                        ),
                        hintText: 'أدخل الوصف',
                        hintStyle: TextStyle(fontSize: hintFontSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
                      maxLines: 5,
                    ),
                    SizedBox(height: dialogSpacing),

                    // Image
                    Row(
                      children: [
                        if (selectedImage != null ||
                            (imageUrl != null && imageUrl!.isNotEmpty))
                          Container(
                            width: 80,
                            height: 80,
                            margin: EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.2),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: selectedImageBytes != null
                                  ? Image.memory(
                                      selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : imageUrl != null && imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : SizedBox.shrink(),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final picked = await imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (picked != null) {
                                // Read image bytes for web compatibility
                                final bytes = await picked.readAsBytes();
                                setState(() {
                                  selectedImage = picked;
                                  selectedImageBytes = bytes;
                                  imageUrl = null;
                                });
                              }
                            } catch (e) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصورة: $e',
                                maxWidth: Get.width > 1200
                                    ? 400.0
                                    : (Get.width > 768 ? 350.0 : null),
                                margin: Get.width > 768
                                    ? EdgeInsets.symmetric(
                                        horizontal: Get.width > 1200
                                            ? (Get.width - 400.0) / 2
                                            : (Get.width - 350.0) / 2,
                                        vertical: 16,
                                      )
                                    : EdgeInsets.all(16),
                                snackStyle: SnackStyle.FLOATING,
                                borderRadius: 12,
                              );
                            }
                          },
                          icon: Icon(Icons.image),
                          label: Text(
                            'اختر صورة',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: dialogSpacing * 1.5),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text(
                            'إلغاء',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (nameController.text.isEmpty ||
                                      priceController.text.isEmpty ||
                                      selectedCategory == null) {
                                    Get.snackbar(
                                      'خطأ',
                                      'يرجى ملء جميع الحقول المطلوبة',
                                      maxWidth: Get.width > 1200
                                          ? 400.0
                                          : (Get.width > 768 ? 350.0 : null),
                                      margin: Get.width > 768
                                          ? EdgeInsets.symmetric(
                                              horizontal: Get.width > 1200
                                                  ? (Get.width - 400.0) / 2
                                                  : (Get.width - 350.0) / 2,
                                              vertical: 16,
                                            )
                                          : EdgeInsets.all(16),
                                      snackStyle: SnackStyle.FLOATING,
                                      borderRadius: 12,
                                    );
                                    return;
                                  }

                                  setState(() => isLoading = true);

                                  if (!isEdit &&
                                      (selectedOwnerId == null ||
                                          selectedOwnerId!.isEmpty)) {
                                    Get.snackbar(
                                      'خطأ',
                                      'يرجى اختيار المالك',
                                      maxWidth: Get.width > 1200
                                          ? 400.0
                                          : (Get.width > 768 ? 350.0 : null),
                                      margin: Get.width > 768
                                          ? EdgeInsets.symmetric(
                                              horizontal: Get.width > 1200
                                                  ? (Get.width - 400.0) / 2
                                                  : (Get.width - 350.0) / 2,
                                              vertical: 16,
                                            )
                                          : EdgeInsets.all(16),
                                      snackStyle: SnackStyle.FLOATING,
                                      borderRadius: 12,
                                    );
                                    setState(() => isLoading = false);
                                    return;
                                  }

                                  String? finalImageUrl = imageUrl;
                                  if (selectedImage != null &&
                                      selectedImageBytes != null) {
                                    try {
                                      // Get ownerId - for new items use selectedOwnerId, for edits get from restaurant_id
                                      String? ownerId = selectedOwnerId;

                                      if (ownerId?.isEmpty ?? true) {
                                        if (isEdit) {
                                          // Get ownerId from restaurant_id
                                          final restaurantId =
                                              item['restaurant_id'];
                                          if (restaurantId != null) {
                                            try {
                                              final supabase =
                                                  Supabase.instance.client;
                                              final restaurant = await supabase
                                                  .from('restaurants')
                                                  .select(
                                                    'owner_id, owner_email',
                                                  )
                                                  .eq('id', restaurantId)
                                                  .maybeSingle();

                                              if (restaurant != null) {
                                                ownerId =
                                                    restaurant['owner_id']
                                                        as String? ??
                                                    restaurant['owner_email']
                                                        as String? ??
                                                    '';
                                              }
                                            } catch (e) {
                                              print(
                                                '[AdminItemManagementScreen] Error getting owner from restaurant: $e',
                                              );
                                            }
                                          }
                                        }
                                      }

                                      if (ownerId == null || ownerId.isEmpty) {
                                        throw Exception(
                                          'معرف المالك غير موجود. يرجى التأكد من أن العنصر مرتبط بمطعم.',
                                        );
                                      }

                                      // For web, use bytes; for mobile, use file path
                                      if (kIsWeb) {
                                        // Web: upload bytes directly
                                        finalImageUrl = await storageService
                                            .uploadImageBytes(
                                              bytes: selectedImageBytes!,
                                              pathPrefix:
                                                  'menu_items/$ownerId/logos',
                                            );
                                      } else {
                                        // Mobile: use file path
                                        final imageFile = File(
                                          selectedImage!.path,
                                        );
                                        if (!await imageFile.exists()) {
                                          throw Exception(
                                            'الملف المحدد غير موجود',
                                          );
                                        }

                                        finalImageUrl = await storageService
                                            .uploadImage(
                                              file: imageFile,
                                              pathPrefix:
                                                  'menu_items/$ownerId/logos',
                                            );
                                      }
                                    } catch (e) {
                                      Get.snackbar(
                                        'خطأ',
                                        'فشل رفع الصورة: ${e.toString().replaceAll('Exception: ', '')}',
                                        maxWidth: Get.width > 1200
                                            ? 400.0
                                            : (Get.width > 768 ? 350.0 : null),
                                        margin: Get.width > 768
                                            ? EdgeInsets.symmetric(
                                                horizontal: Get.width > 1200
                                                    ? (Get.width - 400.0) / 2
                                                    : (Get.width - 350.0) / 2,
                                                vertical: 16,
                                              )
                                            : EdgeInsets.all(16),
                                        snackStyle: SnackStyle.FLOATING,
                                        borderRadius: 12,
                                        duration: Duration(seconds: 4),
                                      );
                                      setState(() {
                                        isLoading = false;
                                        print(e);
                                      });
                                      return;
                                    }
                                  }

                                  final success = isEdit
                                      ? await controller.updateItem(
                                          itemId: item['id'],
                                          name: nameController.text,
                                          category: selectedCategory!,
                                          price: priceController.text,
                                          description:
                                              descriptionController.text,
                                          imageUrl: finalImageUrl,
                                          restaurantName:
                                              restaurantNameController.text,
                                        )
                                      : await controller.createItem(
                                          name: nameController.text,
                                          category: selectedCategory!,
                                          price: priceController.text,
                                          ownerId: selectedOwnerId!,
                                          description:
                                              descriptionController.text,
                                          imageUrl: finalImageUrl,
                                          restaurantName:
                                              restaurantNameController.text,
                                        );

                                  setState(() => isLoading = false);

                                  if (success) {
                                    Get.back();
                                    Get.snackbar(
                                      'نجح',
                                      isEdit
                                          ? 'تم تحديث العنصر'
                                          : 'تم إنشاء العنصر',
                                      maxWidth: Get.width > 1200
                                          ? 400.0
                                          : (Get.width > 768 ? 350.0 : null),
                                      margin: Get.width > 768
                                          ? EdgeInsets.symmetric(
                                              horizontal: Get.width > 1200
                                                  ? (Get.width - 400.0) / 2
                                                  : (Get.width - 350.0) / 2,
                                              vertical: 16,
                                            )
                                          : EdgeInsets.all(16),
                                      snackStyle: SnackStyle.FLOATING,
                                      borderRadius: 12,
                                    );
                                  } else {
                                    Get.snackbar(
                                      'خطأ',
                                      controller.errorMessage.value,
                                      maxWidth: Get.width > 1200
                                          ? 400.0
                                          : (Get.width > 768 ? 350.0 : null),
                                      margin: Get.width > 768
                                          ? EdgeInsets.symmetric(
                                              horizontal: Get.width > 1200
                                                  ? (Get.width - 400.0) / 2
                                                  : (Get.width - 350.0) / 2,
                                              vertical: 16,
                                            )
                                          : EdgeInsets.all(16),
                                      snackStyle: SnackStyle.FLOATING,
                                      borderRadius: 12,
                                    );
                                  }
                                },
                          child: isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isEdit ? 'تحديث' : 'إضافة',
                                  style: TextStyle(
                                    fontSize: isDesktop
                                        ? 16
                                        : (isTablet ? 15 : 14),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AdminItemController controller,
    Map<String, dynamic> item,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    Get.dialog(
      AlertDialog(
        title: Text(
          'حذف العنصر',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${item['name']}"؟',
          style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              final success = await controller.deleteItem(item['id']);
              if (success) {
                Get.snackbar(
                  'نجح',
                  'تم حذف العنصر',
                  maxWidth: Get.width > 1200
                      ? 400.0
                      : (Get.width > 768 ? 350.0 : null),
                  margin: Get.width > 768
                      ? EdgeInsets.symmetric(
                          horizontal: Get.width > 1200
                              ? (Get.width - 400.0) / 2
                              : (Get.width - 350.0) / 2,
                          vertical: 16,
                        )
                      : EdgeInsets.all(16),
                  snackStyle: SnackStyle.FLOATING,
                  borderRadius: 12,
                );
              } else {
                Get.snackbar(
                  'خطأ',
                  controller.errorMessage.value,
                  maxWidth: Get.width > 1200
                      ? 400.0
                      : (Get.width > 768 ? 350.0 : null),
                  margin: Get.width > 768
                      ? EdgeInsets.symmetric(
                          horizontal: Get.width > 1200
                              ? (Get.width - 400.0) / 2
                              : (Get.width - 350.0) / 2,
                          vertical: 16,
                        )
                      : EdgeInsets.all(16),
                  snackStyle: SnackStyle.FLOATING,
                  borderRadius: 12,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'حذف',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }
}
