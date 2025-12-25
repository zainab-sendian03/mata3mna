import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/admin_category_controller.dart';
import 'package:sizer/sizer.dart';

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
    final isDesktop = screenWidth > 1200;

    final bodyContent = Obx(() {
      if (controller.isLoading.value && controller.categories.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      }

      if (controller.errorMessage.value.isNotEmpty &&
          controller.categories.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 15.w),
              SizedBox(height: 2.h),
              Text(
                controller.errorMessage.value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              ElevatedButton(
                onPressed: () => controller.refresh(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
            ),
            child: TextField(
              onChanged: (value) => controller.searchQuery.value = value,
              decoration: InputDecoration(
                hintText: 'بحث في الفئات...',
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
                          size: 15.w,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          controller.searchQuery.value.isNotEmpty
                              ? 'لا توجد نتائج للبحث'
                              : 'لا توجد فئات',
                          style: isDesktop
                              ? theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 20,
                                )
                              : theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isDesktop ? 24 : 16),
                    itemCount: controller.filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = controller.filteredCategories[index];
                      return _buildCategoryCard(
                        context,
                        category,
                        controller,
                        theme,
                        colorScheme,
                        isDesktop,
                      );
                    },
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
                        fontSize: 20,
                        color: colorScheme.onPrimary,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: colorScheme.onPrimary,
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
                      Expanded(
                        child: Text(
                          'إدارة الفئات',
                          style: isDesktop
                              ? theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 20,
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
  ) {
    final itemCount = controller.getItemCount(category);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Row(
          children: [
            // Category icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.category,
                color: colorScheme.onPrimaryContainer,
                size: isDesktop ? 32 : 28,
              ),
            ),
            SizedBox(width: 16),

            // Category info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 16,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '$itemCount عنصر',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
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
                  tooltip: 'تعديل',
                  color: colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _showDeleteDialog(context, controller, category),
                  tooltip: 'حذف',
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

    Get.dialog(
      Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width > 600
              ? 500
              : double.infinity,
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'تعديل فئة' : 'إضافة فئة جديدة',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),

                // Category name
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم الفئة *',
                    hintText: 'مثال: وجبات رئيسية',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 24),

                // Info text
                if (isEdit)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيتم تحديث اسم الفئة في جميع العناصر المرتبطة بها',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isEdit) SizedBox(height: 16),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('إلغاء'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          Get.snackbar('خطأ', 'يرجى إدخال اسم الفئة');
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
                          );
                        } else {
                          Get.snackbar('خطأ', controller.errorMessage.value);
                        }
                      },
                      child: Text(isEdit ? 'تحديث' : 'إضافة'),
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
    final itemCount = controller.getItemCount(category);

    Get.dialog(
      AlertDialog(
        title: const Text('حذف الفئة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حذف فئة "$category"؟'),
            if (itemCount > 0) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هذه الفئة تحتوي على $itemCount عنصر. سيتم نقلها إلى فئة "غير مصنف"',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              final success = await controller.deleteCategory(category);
              if (success) {
                Get.snackbar('نجح', 'تم حذف الفئة');
              } else {
                Get.snackbar('خطأ', controller.errorMessage.value);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
