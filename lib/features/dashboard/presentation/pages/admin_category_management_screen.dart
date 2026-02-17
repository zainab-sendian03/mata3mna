import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/admin_category_controller.dart';

/// Screen for managing categories in admin dashboard
class AdminCategoryManagementScreen extends StatelessWidget {
  final bool hideAppBar;

  const AdminCategoryManagementScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminCategoryController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    final bodyContent = Obx(() {
      if (controller.isLoading.value && controller.categories.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      }

      if (controller.errorMessage.value.isNotEmpty &&
          controller.categories.isEmpty) {
        final errorIconSize = isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0);
        final errorSpacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

        return Center(
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 40 : (isTablet ? 32 : 24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                  size: errorIconSize,
                ),
                SizedBox(height: errorSpacing),
                Text(
                  controller.errorMessage.value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.error,
                    fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: errorSpacing),
                ElevatedButton(
                  onPressed: () => controller.refresh(),
                  child: Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          // Search bar
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
                child: TextField(
                  onChanged: (value) => controller.searchQuery.value = value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                  ),
                  decoration: InputDecoration(
                    hintText: 'بحث في الفئات...',
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => controller.searchQuery.value = '',
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
              ),
            ),
          ),

          // Categories list
          Expanded(
            child: controller.filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category,
                          size: isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0),
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        SizedBox(height: isDesktop ? 24 : (isTablet ? 20 : 16)),
                        Text(
                          controller.searchQuery.value.isNotEmpty
                              ? 'لا توجد نتائج للبحث'
                              : 'لا توجد فئات',
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
                                    childAspectRatio: 3.5,
                                  ),
                              itemCount: controller.filteredCategories.length,
                              itemBuilder: (context, index) {
                                final category =
                                    controller.filteredCategories[index];
                                return _buildCategoryCard(
                                  context,
                                  category,
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
                              itemCount: controller.filteredCategories.length,
                              itemBuilder: (context, index) {
                                final category =
                                    controller.filteredCategories[index];
                                return _buildCategoryCard(
                                  context,
                                  category,
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

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              title: Text(
                'إدارة الفئات',
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
              backgroundColor: Colors.white,
              foregroundColor: colorScheme.onSurface,
              actions: [
                IconButton(
                  icon: Icon(Icons.add, color: colorScheme.onSurface),
                  onPressed: () =>
                      _showAddEditCategoryDialog(context, controller, null),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                  onPressed: () => controller.refresh(),
                ),
              ],
            ),
      body: hideAppBar
          ? Column(
              children: [
                // Header bar when AppBar is hidden
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
                        icon: Icon(
                          Icons.arrow_back,
                          color: colorScheme.onSurface,
                        ),
                        onPressed: () => Get.back(),
                      ),
                      Expanded(
                        child: Text(
                          'إدارة الفئات',
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
                        onPressed: () => _showAddEditCategoryDialog(
                          context,
                          controller,
                          null,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                        onPressed: () => controller.refresh(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String category,
    AdminCategoryController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final cardPadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final cardSpacing = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);
    final iconSize = isDesktop ? 40.0 : (isTablet ? 36.0 : 32.0);
    final iconPadding = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);

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
          children: [
            // Category icon
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.category,
                color: colorScheme.onPrimaryContainer,
                size: iconSize,
              ),
            ),
            SizedBox(width: cardSpacing),

            // Category info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: isDesktop ? 18 : (isTablet ? 16 : 14),
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      SizedBox(width: 4),
                      // Use Obx to reactively update the count
                      Obx(() {
                        final itemCount = controller.getItemCount(category);
                        return Text(
                          '$itemCount عنصر',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _showAddEditCategoryDialog(context, controller, category),
                  color: colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _showDeleteDialog(context, controller, category),
                  color: colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditCategoryDialog(
    BuildContext context,
    AdminCategoryController controller,
    String? category,
  ) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category ?? '');

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    final dialogWidth = isDesktop
        ? 600.0
        : (isTablet ? 600.0 : screenWidth * 0.95);
    final dialogPadding = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final dialogSpacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    // Responsive font sizes
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

    Get.dialog(
      Dialog(
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(dialogPadding),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'تعديل فئة' : 'إضافة فئة جديدة',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                  ),
                ),
                SizedBox(height: dialogSpacing),

                // Category name
                TextField(
                  style: TextStyle(fontSize: formFieldFontSize, height: 1.2),
                  controller: nameController,
                  decoration: InputDecoration(
                    label: Text(
                      'اسم الفئة *',
                      style: TextStyle(fontSize: labelFontSize),
                    ),
                    hintText: 'مثال: وجبات رئيسية',
                    hintStyle: TextStyle(
                      fontSize: hintFontSize,
                      color: Colors.grey.shade500,
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
                  autofocus: true,
                ),
                SizedBox(height: dialogSpacing),

                // Info text
                if (isEdit)
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 16 : 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: isDesktop ? 24 : (isTablet ? 20 : 18),
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيتم تحديث اسم الفئة في جميع العناصر المرتبطة بها',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.8),
                              fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isEdit) SizedBox(height: dialogSpacing),

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
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          Get.snackbar(
                            'خطأ',
                            'يرجى إدخال اسم الفئة',
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

                        final success = isEdit
                            ? await controller.updateCategory(
                                oldCategory: category,
                                newCategory: nameController.text.trim(),
                              )
                            : await controller.createCategory(
                                nameController.text.trim(),
                              );

                        if (success) {
                          Get.back();
                          Get.snackbar(
                            'نجح',
                            isEdit ? 'تم تحديث الفئة' : 'تم إنشاء الفئة',
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
                      child: Text(
                        isEdit ? 'تحديث' : 'إضافة',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AdminCategoryController controller,
    String category,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    Get.dialog(
      Obx(() {
        final itemCount = controller.getItemCount(category);
        return AlertDialog(
          title: Text(
            'حذف الفئة',
            style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من حذف فئة "$category"؟',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                ),
              ),
              if (itemCount > 0) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(isDesktop ? 16 : 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: isDesktop ? 24 : (isTablet ? 20 : 18),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هذه الفئة تحتوي على $itemCount عنصر. سيتم نقلها إلى فئة "غير مصنف"',
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Get.back();
                final success = await controller.deleteCategory(category);
                if (success) {
                  Get.snackbar(
                    'نجح',
                    'تم حذف الفئة',
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
                style: TextStyle(
                  fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
