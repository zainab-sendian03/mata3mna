import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:mata3mna/core/constants/custom_app_bar.dart';
import 'package:mata3mna/core/constants/custom_bottom_bar.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';
import 'package:mata3mna/features/items_managment/presentation/widgets/category_dropdown_widget.dart';
import 'package:mata3mna/features/items_managment/presentation/widgets/image_picker_widget.dart';
import 'package:mata3mna/features/items_managment/presentation/widgets/price_input_widget.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:sizer/sizer.dart';

/// Screen for adding new menu items or editing existing ones
/// Supports image upload, category selection, and price formatting
class AddEditItemScreen extends StatefulWidget {
  /// Menu item data for edit mode (null for add mode)
  final Map<String, dynamic>? itemData;

  const AddEditItemScreen({super.key, this.itemData});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final MenuFirestoreService _menuService = Get.find<MenuFirestoreService>();
  final SupabaseStorageService _storageService =
      Get.find<SupabaseStorageService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();
  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();

  String? _selectedCategory;
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  int _currentBottomNavIndex = 1;
  String? _restaurantLogoUrl;

  // Available categories - loaded from cache
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeFormData();
    _setupChangeListeners();
    _loadRestaurantLogo();
  }

  Future<void> _loadRestaurantLogo() async {
    try {
      final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
      if (ownerId != null && ownerId.isNotEmpty) {
        final restaurantInfo = await _restaurantService
            .getRestaurantInfoByOwnerId(ownerId);
        if (restaurantInfo != null && mounted) {
          setState(() {
            _restaurantLogoUrl = restaurantInfo['logoPath'] as String?;
            if (_restaurantLogoUrl != null && _restaurantLogoUrl!.isEmpty) {
              _restaurantLogoUrl = null;
            }
          });
        }
      }
    } catch (e) {
      // Ignore errors, logo is optional
    }
  }

  void _loadCategories() {
    final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
    if (ownerId == null || ownerId.isEmpty) {
      // Default categories if no user ID
      _categories = [];
      return;
    }

    // Use user-specific key for categories
    final userCategoriesKey = 'menuCategories_$ownerId';
    final savedCategories = _cacheHelper.getStringList(key: userCategoriesKey);
    if (savedCategories != null && savedCategories.isNotEmpty) {
      _categories = savedCategories;
    } else {
      // Default categories
      _categories = [];
    }
  }

  void _initializeFormData() {
    if (widget.itemData != null) {
      _nameController.text = widget.itemData!['name'] ?? '';
      _priceController.text = widget.itemData!['price'] ?? '';
      _descriptionController.text = widget.itemData!['description'] ?? '';
      _selectedCategory = widget.itemData!['category'];
    }
  }

  void _setupChangeListeners() {
    _nameController.addListener(() {
      _onFormChanged();
      setState(() {}); // Trigger rebuild to update button state
    });
    _priceController.addListener(() {
      _onFormChanged();
      setState(() {}); // Trigger rebuild to update button state
    });
    _descriptionController.addListener(_onFormChanged);
  }

  Future<void> _handleCategoryCreated(
    String category,
    XFile? categoryImage,
  ) async {
    final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
    if (ownerId == null || ownerId.isEmpty) {
      // Can't save without user ID
      return;
    }

    // Always create the category first, regardless of image
    setState(() {
      if (!_categories.contains(category)) {
        _categories.add(category);
        // Save to cache with user-specific key
        final userCategoriesKey = 'menuCategories_$ownerId';
        _cacheHelper.saveData(key: userCategoriesKey, value: _categories);
      }
      _selectedCategory = category;
      _hasUnsavedChanges = true;
    });

    // Save category image locally if provided (optional)
    if (categoryImage != null) {
      try {
        final imageFile = File(categoryImage.path);
        if (await imageFile.exists()) {
          // Save image to local storage with user-specific key
          final userCategoryKey = '${ownerId}_$category';
          final savedPath = await _cacheHelper.saveImageFile(
            key: userCategoryKey,
            imageFile: imageFile,
          );

          if (savedPath != null && mounted) {
            // Update local state to reflect the saved image
            setState(() {});
          }
        }
      } catch (e) {
        // Category was already created successfully, just show a warning about image
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إنشاء الفئة بنجاح، لكن فشل حفظ الصورة. يمكنك إضافة الصورة لاحقاً.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
    // Category is created successfully with or without image
  }

  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.itemData != null;

  bool get _isFormValid {
    return _nameController.text.trim().isNotEmpty &&
        _priceController.text.trim().isNotEmpty &&
        _selectedCategory != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _showUnsavedChangesDialog();
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: CustomAppBar(
          title: _isEditMode ? 'تعديل عنصر القائمة' : 'إضافة عنصر القائمة',
          variant: _isEditMode
              ? CustomAppBarVariant.standard
              : CustomAppBarVariant.modal,
          showBackButton: true,
          onBackPressed: _handleBackPress,
          actions: [
            if (_isEditMode)
              IconButton(
                icon: CustomIconWidget(
                  iconName: 'delete',
                  color: colorScheme.error,
                  size: 22,
                ),
                onPressed: _showDeleteConfirmation,
                tooltip: 'حذف العنصر',
              ),
            SizedBox(width: 1.w),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(4.w),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image picker
                        ImagePickerWidget(
                          imageUrl: _isEditMode
                              ? widget.itemData!['image']
                              : null,
                          fallbackImageUrl: _restaurantLogoUrl,
                          onImageSelected: (image) {
                            setState(() {
                              _selectedImage = image;
                              _hasUnsavedChanges = true;
                            });
                          },
                          isLoading: _isLoading,
                        ),
                        SizedBox(height: 3.h),

                        // Item name
                        _buildNameField(theme, colorScheme),
                        SizedBox(height: 3.h),

                        // Category dropdown
                        CategoryDropdownWidget(
                          selectedCategory: _selectedCategory,
                          categories: _categories,
                          onCategorySelected: (category) {
                            setState(() {
                              _selectedCategory = category;
                              _hasUnsavedChanges = true;
                            });
                          },
                          onCategoryCreated: (category, image) async {
                            await _handleCategoryCreated(category, image);
                            setState(
                              () {},
                            ); // Trigger rebuild to update button state
                          },
                          enabled: !_isLoading,
                        ),
                        SizedBox(height: 3.h),

                        // Price input
                        PriceInputWidget(
                          controller: _priceController,
                          enabled: !_isLoading,
                          onChanged: (_) {
                            _onFormChanged();
                            setState(
                              () {},
                            ); // Trigger rebuild to update button state
                          },
                        ),
                        SizedBox(height: 3.h),

                        // Description
                        _buildDescriptionField(theme, colorScheme),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom action buttons
              _buildBottomActions(colorScheme),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomBar(
          currentIndex: _currentBottomNavIndex,
          onTap: (index) {
            if (index != _currentBottomNavIndex) {
              if (_hasUnsavedChanges) {
                _showUnsavedChangesDialog().then((shouldLeave) {
                  if (shouldLeave == true) {
                    _navigateToScreen(index);
                  }
                });
              } else {
                _navigateToScreen(index);
              }
            }
          },
          variant: CustomBottomBarVariant.standard,
        ),
      ),
    );
  }

  Widget _buildNameField(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اسم العنصر',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: _nameController,
          enabled: !_isLoading,
          onChanged: (_) {
            setState(() {}); // Trigger rebuild to update button state
          },
          decoration: InputDecoration(
            hintText: 'أدخل اسم العنصر',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 2.w, right: 2.w),
              child: CustomIconWidget(
                iconName: 'restaurant',
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 12.w),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 2.h,
            ),
            counterText: '${_nameController.text.length}/50',
          ),
          style: theme.textTheme.bodyLarge,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildDescriptionField(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوصف (اختياري)',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: _descriptionController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'أدخل وصف العنصر',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 2.w, right: 2.w, top: 2.h),
              child: CustomIconWidget(
                iconName: 'description',
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 12.w),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 2.h,
            ),
            counterText: '${_descriptionController.text.length}/200',
          ),
          style: theme.textTheme.bodyLarge,
          maxLength: 200,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildBottomActions(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _isFormValid ? _saveItem : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  disabledBackgroundColor: colorScheme.outline.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Text(
                        _isEditMode ? 'تحديث العنصر' : 'حفظ العنصر',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
              ),
            ),
            SizedBox(height: 1.5.h),
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleBackPress,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final price = _priceController.text.trim();
      final description = _descriptionController.text.trim();
      final restaurantName =
          _cacheHelper.getData(key: 'restaurantName') as String? ?? '';
      final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
      String? uploadedImageUrl;

      // Upload image if provided, otherwise use restaurant logo as fallback
      if (_selectedImage != null) {
        if (ownerId == null || ownerId.isEmpty) {
          throw Exception('لا يمكن رفع الصورة بدون معرف المالك');
        }
        uploadedImageUrl = await _uploadImageToStorage(ownerId);
      } else {
        // Use restaurant logo as fallback if no image is selected
        uploadedImageUrl = _restaurantLogoUrl;
      }

      if (_isEditMode && widget.itemData != null) {
        // Update existing item
        final itemId = widget.itemData!['id'] as String?;
        if (itemId != null) {
          // Use uploaded image, or existing image, or restaurant logo as fallback
          final finalImageUrl =
              uploadedImageUrl ??
              widget.itemData!['image'] ??
              _restaurantLogoUrl ??
              '';
          await _menuService.updateMenuItem(
            itemId: itemId,
            name: name,
            category: _selectedCategory!,
            price: price,
            description: description,
            imageUrl: finalImageUrl,
            restaurantName: restaurantName,
          );
        }
      } else {
        // Add new item
        if (ownerId == null || ownerId.isEmpty) {
          throw Exception('لم يتم العثور على معرف المالك لرفع العنصر');
        }
        await _menuService.addMenuItem(
          name: name,
          category: _selectedCategory!,
          price: price,
          description: description,
          imageUrl: uploadedImageUrl ?? '',
          restaurantName: restaurantName,
          ownerId: ownerId,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasUnsavedChanges = false;
        });

        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'تم تحديث العنصر بنجاح!' : 'تم إضافة العنصر بنجاح!',
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        Get.offAllNamed(AppPages.home);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // ignore: avoid_print
        print('[AddEditItemScreen] Failed to save item: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String> _uploadImageToStorage(String ownerId) async {
    if (_selectedImage == null) {
      throw Exception('لم يتم اختيار صورة');
    }

    final localFile = File(_selectedImage!.path);
    if (!await localFile.exists()) {
      throw Exception('الملف المحدد غير موجود على جهازك');
    }

    return _storageService.uploadImage(
      file: localFile,
      pathPrefix: 'menu_items/$ownerId',
    );
  }

  void _handleBackPress() {
    if (_hasUnsavedChanges) {
      _showUnsavedChangesDialog().then((shouldPop) {
        if (shouldPop == true && mounted) {
          Navigator.of(context).pop();
        }
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تغييرات غير محفوظة',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'لديك تغييرات غير محفوظة. هل أنت متأكد أنك تريد المغادرة؟',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('البقاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('مغادرة'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف العنصر',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'هل أنت متأكد أنك تريد حذف عنصر القائمة هذا؟ لا يمكن التراجع عن هذا الإجراء.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final itemId = widget.itemData?['id'] as String?;
      if (itemId != null) {
        await _menuService.deleteMenuItem(itemId);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف العنصر بنجاح!'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacementNamed(context, '/menu-management-screen');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف العنصر: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToScreen(int index) {
    setState(() {
      _currentBottomNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        // Already on this screen
        break;
    }
  }
}
