import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:sizer/sizer.dart';

/// Dropdown widget for selecting menu item category
/// Supports existing categories and creating new ones
class CategoryDropdownWidget extends StatefulWidget {
  /// Currently selected category
  final String? selectedCategory;

  /// List of available categories
  final List<String> categories;

  /// Callback when category is selected
  final Function(String) onCategorySelected;

  /// Whether the widget is enabled
  final bool enabled;

  /// Callback when a new category is created
  /// Parameters: (categoryName, imageFile)
  final Function(String, XFile?)? onCategoryCreated;

  const CategoryDropdownWidget({
    super.key,
    this.selectedCategory,
    required this.categories,
    required this.onCategorySelected,
    this.enabled = true,
    this.onCategoryCreated,
  });

  @override
  State<CategoryDropdownWidget> createState() => _CategoryDropdownWidgetState();
}

class _CategoryDropdownWidgetState extends State<CategoryDropdownWidget> {
  final TextEditingController _newCategoryController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _categoryImage;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الفئة',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: DropdownButtonFormField<String>(
            key: ValueKey(widget.selectedCategory),
            value:
                widget.selectedCategory != null &&
                    widget.categories.contains(widget.selectedCategory)
                ? widget.selectedCategory
                : null,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4.w,
                vertical: 2.h,
              ),
              border: InputBorder.none,
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 2.w, right: 2.w),
                child: CustomIconWidget(
                  iconName: 'category',
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 12.w),
            ),
            hint: Text(
              'اختر الفئة',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            icon: CustomIconWidget(
              iconName: 'arrow_drop_down',
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              size: 24,
            ),
            isExpanded: true,
            items: [
              ...widget.categories.map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category, style: theme.textTheme.bodyLarge),
                ),
              ),
              DropdownMenuItem(
                value: '__add_new__',
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'add_circle_outline',
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'إضافة فئة جديدة',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: widget.enabled
                ? (value) {
                    if (value == '__add_new__') {
                      _showAddCategoryDialog();
                    } else if (value != null &&
                        value != widget.selectedCategory) {
                      widget.onCategorySelected(value);
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    _categoryImage = null;
    _newCategoryController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'إضافة فئة جديدة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category name field
                TextField(
                  controller: _newCategoryController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'أدخل اسم الفئة',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 2.w, right: 2.w),
                      child: CustomIconWidget(
                        iconName: 'category',
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 12.w),
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 30,
                ),
                SizedBox(height: 2.h),
                // Image picker section
                Text(
                  'صورة الفئة (اختياري)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 1.h),
                GestureDetector(
                  onTap: () => _showImageSourceDialog(setDialogState),
                  child: Container(
                    width: double.infinity,
                    height: 20.h,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: _categoryImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_categoryImage!.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: CustomIconWidget(
                                      iconName: 'edit',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _showImageSourceDialog(setDialogState),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.error.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: CustomIconWidget(
                                      iconName: 'delete',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        _categoryImage = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomIconWidget(
                                iconName: 'add_a_photo',
                                color: Theme.of(context).colorScheme.primary,
                                size: 32,
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'اضغط لإضافة صورة',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newCategoryController.clear();
                _categoryImage = null;
                Navigator.pop(context);
              },
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final newCategory = _newCategoryController.text.trim();
                if (newCategory.isNotEmpty) {
                  if (!widget.categories.contains(newCategory)) {
                    widget.onCategoryCreated?.call(newCategory, _categoryImage);
                  }
                  widget.onCategorySelected(newCategory);
                  _newCategoryController.clear();
                  _categoryImage = null;
                  Navigator.pop(context);
                }
              },
              child: Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(StateSetter setDialogState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 2.h),
              Container(
                width: 10.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 2.h),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'camera_alt',
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'التقاط صورة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, setDialogState);
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'photo_library',
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'اختيار من المعرض',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, setDialogState);
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(
    ImageSource source,
    StateSetter setDialogState,
  ) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setDialogState(() {
          _categoryImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل اختيار الصورة: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
