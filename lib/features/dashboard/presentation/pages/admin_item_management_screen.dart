import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/admin_item_controller.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// Screen for managing menu items in admin dashboard
class AdminItemManagementScreen extends StatelessWidget {
  const AdminItemManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminItemController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    return Obx(() {
      return Column(
        children: [
          // Header bar (when AppBar is hidden)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : (isTablet ? 20 : 16),
              vertical: isDesktop ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'إدارة العناصر',
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
                bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
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
                          fontSize: isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0),
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
                        SizedBox(height: isDesktop ? 24 : (isTablet ? 20 : 16)),
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
                      child: isDesktop
                          ? GridView.builder(
                              padding: EdgeInsets.all(24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: 3,
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
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(isTablet ? 20 : 16),
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
      );
    });
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
    final cardPadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final cardSpacing = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);

    return Card(
      margin: EdgeInsets.only(bottom: isDesktop ? 10 : (isTablet ? 16 : 12)),
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

            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: Text(
                          item['category'] ?? 'غير مصنف',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                          ),
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
                  if (item['restaurantName'] != null &&
                      item['restaurantName'].toString().isNotEmpty) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        SizedBox(width: 4),
                        Text(
                          item['restaurantName'].toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item['description'] != null &&
                      item['description'].toString().isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      item['description'].toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _showAddEditItemDialog(context, controller, item),
                  color: colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteDialog(context, controller, item),
                  color: colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditItemDialog(
    BuildContext context,
    AdminItemController controller,
    Map<String, dynamic>? item,
  ) {
    final isEdit = item != null;
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final priceController = TextEditingController(text: item?['price'] ?? '');
    final descriptionController = TextEditingController(
      text: item?['description'] ?? '',
    );
    String? selectedOwnerId = item?['ownerId'];
    Map<String, dynamic>? selectedOwner;
    final restaurantNameController = TextEditingController(
      text: item?['restaurantName'] ?? '',
    );

    String? selectedCategory = item?['category'];
    String? imageUrl = item?['image'];
    XFile? selectedImage;
    bool isLoading = false;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storageService = Get.find<SupabaseStorageService>();
    final adminService = Get.find<AdminFirestoreService>();
    final imagePicker = ImagePicker();

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

    Get.dialog(
      Dialog(
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(dialogPadding),
          child: StatefulBuilder(
            builder: (context, setState) {
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

                          // Find selected owner if exists
                          if (selectedOwnerId != null &&
                              selectedOwner == null) {
                            selectedOwner = owners.firstWhere(
                              (owner) =>
                                  owner['id'] == selectedOwnerId ||
                                  owner['uid'] == selectedOwnerId,
                              orElse: () => {},
                            );
                            if (selectedOwner!.isEmpty) {
                              selectedOwner = null;
                            }
                          }

                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: adminService.getAllRestaurants(),
                            builder: (context, restaurantsSnapshot) {
                              final restaurants =
                                  restaurantsSnapshot.data ?? [];
                              final restaurantNamesMap = <String, String>{};

                              // Build a map of ownerId/ownerEmail -> restaurant name
                              for (final restaurant in restaurants) {
                                final ownerId =
                                    restaurant['ownerId'] as String? ?? '';
                                final ownerEmail =
                                    restaurant['ownerEmail'] as String? ?? '';
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

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<Map<String, dynamic>>(
                                    value: selectedOwner,
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
                                      hintText: owners.isEmpty
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
                                    items: owners.map((owner) {
                                      final ownerId =
                                          owner['id'] ?? owner['uid'] ?? '';
                                      final ownerEmail = owner['email'] ?? '';
                                      final restaurantName =
                                          restaurantNamesMap[ownerId] ??
                                          restaurantNamesMap[ownerEmail] ??
                                          'بدون مطعم';
                                      return DropdownMenuItem<
                                        Map<String, dynamic>
                                      >(
                                        value: owner,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              restaurantName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: formFieldFontSize,
                                              ),
                                            ),
                                            if (ownerEmail.isNotEmpty)
                                              Text(
                                                ownerEmail,
                                                style: TextStyle(
                                                  fontSize:
                                                      formFieldFontSize - 2,
                                                  color: colorScheme.onSurface
                                                      .withOpacity(0.6),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: owners.isEmpty
                                        ? null
                                        : (owner) {
                                            setState(() {
                                              selectedOwner = owner;
                                              selectedOwnerId =
                                                  owner?['id'] ?? owner?['uid'];
                                            });
                                          },
                                  ),
                                  if (owners.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'لا يوجد ملاك مسجلين في النظام',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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

                    // Show owner info in edit mode
                    if (isEdit)
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 16 : 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المالك:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: labelFontSize,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              selectedOwnerId ?? 'غير محدد',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: formFieldFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isEdit) SizedBox(height: dialogSpacing),

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
                      final categories = controller.categories
                          .where((c) => c != 'جميع العناصر')
                          .toList();
                      return DropdownButtonFormField<String>(
                        value: selectedCategory,
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
                        onChanged: (value) =>
                            setState(() => selectedCategory = value),
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

                    // Restaurant Name
                    TextField(
                      style: TextStyle(
                        fontSize: formFieldFontSize,
                        height: 1.2,
                      ),
                      controller: restaurantNameController,
                      decoration: InputDecoration(
                        label: Text(
                          'اسم المطعم',
                          style: TextStyle(fontSize: labelFontSize),
                        ),
                        hintText: 'أدخل اسم المطعم',
                        hintStyle: TextStyle(fontSize: hintFontSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
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
                      maxLines: 3,
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
                              child: selectedImage != null
                                  ? Image.file(
                                      File(selectedImage!.path),
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: imageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await imagePicker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (picked != null) {
                              setState(() {
                                selectedImage = picked;
                                imageUrl = null;
                              });
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
                                  if (selectedImage != null) {
                                    try {
                                      final ownerId =
                                          selectedOwnerId ??
                                          item?['ownerId'] ??
                                          '';
                                      finalImageUrl = await storageService
                                          .uploadImage(
                                            file: File(selectedImage!.path),
                                            pathPrefix:
                                                'menu_items/$ownerId/logos',
                                          );
                                    } catch (e) {
                                      Get.snackbar(
                                        'خطأ',
                                        'فشل رفع الصورة: $e',
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
