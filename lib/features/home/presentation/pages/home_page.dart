import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:sizer/sizer.dart';

import './widgets/empty_category_state.dart';
import './widgets/menu_item_card.dart';

/// Menu Management Screen - Comprehensive CRUD operations for restaurant menu items
/// Implements category organization, search, and swipe actions
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MenuFirestoreService _menuService = Get.find<MenuFirestoreService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();

  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _menuItems = [];
  bool _hasScrolledToBottom = false;

  // Categories for menu organization
  List<String> _categories = ['جميع العناصر'];

  // Category images map
  Map<String, String> _categoryImages = {};

  // Restaurant logo URL for fallback
  String? _restaurantLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadCategoryImages();
    _loadRestaurantLogo();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadMenuItems();
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

  void _loadCategoryImages() {
    try {
      // Load category images from local file paths (user-specific)
      final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
      if (ownerId == null || ownerId.isEmpty) return;

      _categoryImages = {};
      for (final category in _categories) {
        if (category != 'جميع العناصر') {
          // Use user-specific key for category images
          final imagePath = _cacheHelper.getCategoryImagePath(
            '${ownerId}_$category',
          );
          if (imagePath != null && imagePath.isNotEmpty) {
            // Verify file exists
            final file = File(imagePath);
            if (file.existsSync()) {
              _categoryImages[category] = imagePath;
            }
          }
        }
      }
    } catch (e) {
      // If there's any error loading category images, just start with empty map
      _categoryImages = {};
    }
  }

  void _loadCategories() {
    final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
    if (ownerId == null || ownerId.isEmpty) {
      // Default categories if no user ID
      _categories = ['جميع العناصر'];
      return;
    }

    // Use user-specific key for categories
    final userCategoriesKey = 'menuCategories_$ownerId';
    final savedCategories = _cacheHelper.getStringList(key: userCategoriesKey);
    if (savedCategories != null && savedCategories.isNotEmpty) {
      _categories = ['جميع العناصر', ...savedCategories];
    } else {
      // Default categories
      _categories = ['جميع العناصر'];
      _saveCategories(); // Save default categories on first load
    }
  }

  void _saveCategories() {
    final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
    if (ownerId == null || ownerId.isEmpty) return;

    final categoriesToSave = _categories
        .where((cat) => cat != 'جميع العناصر')
        .toList();
    // Use user-specific key for categories
    final userCategoriesKey = 'menuCategories_$ownerId';
    _cacheHelper.saveData(key: userCategoriesKey, value: categoriesToSave);
  }

  void _loadMenuItems() {
    final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
    if (ownerId != null && ownerId.isNotEmpty) {
      _menuService.getMenuItemsStream(ownerId).listen((items) {
        if (mounted) {
          setState(() {
            _menuItems = items;
          });

          // Auto-advance to next tab if first tab is empty
          _checkAndAdvanceFromFirstTab();
        }
      });
    }
  }

  void _checkAndAdvanceFromFirstTab() {
    // Check if we're on the first tab and it's empty
    if (_tabController.index == 0 &&
        _categories.isNotEmpty &&
        _categories[0] == 'جميع العناصر') {
      // Check if first tab has no items
      if (_menuItems.isEmpty && _categories.length > 1) {
        // Move to the next tab (index 1)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.length > 1) {
            _tabController.animateTo(1);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Allow tab navigation at any time, regardless of items completion
    if (_tabController.indexIsChanging ||
        _tabController.index != _tabController.previousIndex) {
      setState(() {
        // Clear search when switching categories
        if (_searchQuery.isNotEmpty) {
          _searchController.clear();
          _searchQuery = '';
        }
        // Reset scroll position and bottom flag when switching tabs
        _hasScrolledToBottom = false;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Only handle scroll end notifications to prevent rapid navigation
    if (notification is! ScrollEndNotification) {
      return false;
    }

    if (!_scrollController.hasClients) return false;

    final scrollPosition = _scrollController.position;
    final maxScroll = scrollPosition.maxScrollExtent;
    final currentScroll = scrollPosition.pixels;

    // Don't trigger if there's no scrollable content
    if (maxScroll <= 0) return false;

    // Don't trigger if user hasn't scrolled
    if (currentScroll <= 0) return false;

    // Check if user has reached the bottom
    // Use a simple threshold: within 100px of bottom for all lists
    final threshold = 20;
    final distanceFromBottom = maxScroll - currentScroll;
    final isNearBottom = distanceFromBottom <= threshold;

    // Also check if at edge
    final isAtEdge = scrollPosition.atEdge && currentScroll > 0;

    // Trigger navigation if at bottom or near bottom
    if ((isAtEdge || isNearBottom) && !_hasScrolledToBottom) {
      _hasScrolledToBottom = true;

      if (_tabController.index < _tabController.length - 1) {
        final nextIndex = _tabController.index + 1;
        // Small delay for smooth transition
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted &&
              _tabController.index < _tabController.length - 1 &&
              !_tabController.indexIsChanging &&
              _tabController.length > nextIndex) {
            _tabController.animateTo(nextIndex);
          }
        });
      }
    }

    return false; // Allow notification to continue
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    String currentCategory = _categories[_tabController.index];

    List<Map<String, dynamic>> filtered = currentCategory == 'جميع العناصر'
        ? List.from(_menuItems)
        : _menuItems
              .where((item) => item['category'] == currentCategory)
              .toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final description = (item['description'] ?? '')
            .toString()
            .toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);

    // Reload menu items
    _loadMenuItems();

    if (mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث القائمة بنجاح'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleAddItem() {
    Get.toNamed(AppPages.addItem);
  }

  void _handleEditItem(Map<String, dynamic> item) {
    Get.toNamed(AppPages.addItem, arguments: {'item': item, 'mode': 'edit'});
  }

  Future<void> _handleDeleteItem(Map<String, dynamic> item) async {
    final itemId = item['id'] as String?;
    if (itemId == null) return;

    try {
      await _menuService.deleteMenuItem(itemId);
      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف ${item['name']}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف العنصر: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredItems = _getFilteredItems();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(20.h),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "إدارة القائمة",
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      title: const Text(
                                        "تسجيل الخروج",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: const Text(
                                        "هل أنت متأكد أنك تريد تسجيل الخروج؟",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text("إلغاء"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            foregroundColor: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await authController.signOut();
                                            authController
                                                .confirmPasswordController
                                                .clear();
                                            authController.usernameController
                                                .clear();
                                            authController.signupEmailController
                                                .clear();
                                            authController
                                                .signupPasswordController
                                                .clear();
                                            authController.loginEmailController
                                                .clear();
                                            authController
                                                .loginPasswordController
                                                .clear();
                                            Get.offAllNamed(AppPages.root);
                                          },
                                          child: Text(
                                            "تسجيل خروج",
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.logout_rounded,
                                  color: theme.scaffoldBackgroundColor,
                                ),
                              ),
                              // Only show this button for owners, not admins
                              if ((_cacheHelper.getData(key: 'userRole')
                                      as String?) !=
                                  'admin')
                                IconButton(
                                  onPressed: () async {
                                    // Load restaurant info and pass it for editing
                                    final ownerId =
                                        _cacheHelper.getData(key: 'userUid')
                                            as String?;
                                    Map<String, dynamic>? restaurantData;
                                    if (ownerId != null && ownerId.isNotEmpty) {
                                      try {
                                        final ownerEmail =
                                            _cacheHelper.getData(
                                                  key: 'userEmail',
                                                )
                                                as String?;
                                        restaurantData =
                                            await _restaurantService
                                                .getRestaurantInfoByOwnerId(
                                                  ownerId,
                                                  ownerEmail: ownerEmail,
                                                );
                                        print(
                                          '[HomePage] Loaded restaurant data: $restaurantData',
                                        );
                                      } catch (e) {
                                        print(
                                          '[HomePage] Error loading restaurant info: $e',
                                        );
                                      }
                                    }
                                    Get.toNamed(
                                      AppPages.completeRestaurantInfo,
                                      arguments: restaurantData,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.person_2_rounded,
                                    color: theme.scaffoldBackgroundColor,
                                  ),
                                  tooltip: 'تعديل معلومات المطعم',
                                ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      _buildSearchAppBar(theme, colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  _buildSquareTabs(theme, colorScheme),
                  GestureDetector(
                    onTap: () =>
                        _showAddCategoryDialog(context, theme, colorScheme),
                    child: Container(
                      margin: EdgeInsets.only(left: 2.w),
                      width: 18.w,
                      height: 18.w,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '+\n اضف تصنيف',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.normal,
                            fontSize: 9.sp,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: filteredItems.isEmpty
                        ? _buildEmptyState()
                        : _buildItemsList(filteredItems),
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(colorScheme),
    );
  }

  Widget _buildSquareTabs(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        textDirection: TextDirection.rtl,
        children: _categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isSelected = _tabController.index == index;
          final categoryImageUrl = _categoryImages[category];

          return GestureDetector(
            onTap: () {
              _tabController.animateTo(index);
            },
            onLongPress: () {
              // Only allow edit/delete for non-default categories
              if (category != 'جميع العناصر') {
                _showCategoryManageDialog(
                  context,
                  theme,
                  colorScheme,
                  category,
                  index,
                );
              }
            },
            child: Container(
              margin: EdgeInsets.only(left: 2.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Square with image
                  Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : Border.all(color: colorScheme.outline, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: category == 'جميع العناصر'
                          ? Center(
                              child: CustomIconWidget(
                                iconName: 'restaurant_menu',
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                                size: 8.w,
                              ),
                            )
                          : categoryImageUrl != null &&
                                categoryImageUrl.isNotEmpty
                          ? Image.file(
                              File(categoryImageUrl),
                              width: 18.w,
                              height: 18.w,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackImage(colorScheme, isSelected),
                            )
                          : _restaurantLogoUrl != null &&
                                _restaurantLogoUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _restaurantLogoUrl!,
                              width: 18.w,
                              height: 18.w,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildFallbackImage(colorScheme, isSelected),
                            )
                          : _buildFallbackImage(colorScheme, isSelected),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  // Category name below square
                  SizedBox(
                    width: 18.w,
                    child: Text(
                      category,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 8.sp,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFallbackImage(ColorScheme colorScheme, bool isSelected) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: CustomIconWidget(
          iconName: 'category',
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          size: 8.w,
        ),
      ),
    );
  }

  Widget _buildSearchAppBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 2.w),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: 'البحث في عناصر القائمة...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 10.sp,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Icon(Icons.search_rounded, color: colorScheme.primary, size: 30),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    String currentCategory = _categories[_tabController.index];

    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomIconWidget(
                iconName: 'search_off_rounded',
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20.w,
              ),
              SizedBox(height: 2.h),
              Text(
                'لم يتم العثور على نتائج',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 1.h),
              Text(
                'حاول تعديل مصطلحات البحث',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return EmptyCategoryState(
      categoryName: currentCategory,
      onAddItem: _handleAddItem,
    );
  }

  Widget _buildItemsList(List<Map<String, dynamic>> items) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // Add extra bottom padding to ensure there's always scrollable space
        // This allows navigation to work even with one item
        padding: EdgeInsets.only(top: 2.h, bottom: 45.h),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return MenuItemCard(
            item: item,
            onEdit: () => _handleEditItem(item),
            onDelete: () => _handleDeleteItem(item),
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButton(ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      onPressed: _handleAddItem,
      icon: CustomIconWidget(
        iconName: 'add',
        color: colorScheme.onPrimary,
        size: 6.w,
      ),
      label: Text('إضافة عنصر'),
      elevation: 4.0,
    );
  }

  void _showCategoryManageDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String category,
    int categoryIndex,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 2.h),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'edit',
                  color: colorScheme.primary,
                  size: 24,
                ),
                title: Text('تعديل الفئة', style: theme.textTheme.titleMedium),
                onTap: () {
                  Navigator.pop(context);
                  _showEditCategoryDialog(
                    context,
                    theme,
                    colorScheme,
                    category,
                    categoryIndex,
                  );
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'delete',
                  color: colorScheme.error,
                  size: 24,
                ),
                title: Text(
                  'حذف الفئة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteCategoryConfirmation(
                    context,
                    theme,
                    colorScheme,
                    category,
                    categoryIndex,
                  );
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteCategoryConfirmation(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String category,
    int categoryIndex,
  ) {
    // Check if category has items
    final itemsInCategory = _menuItems
        .where((item) => item['category'] == category)
        .toList();
    final hasItems = itemsInCategory.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف الفئة', style: theme.textTheme.titleLarge),
        content: Text(
          hasItems
              ? 'تحذير: هذه الفئة تحتوي على ${itemsInCategory.length} عنصر. سيتم حذف الفئة فقط، العناصر ستبقى في القائمة.'
              : 'هل أنت متأكد من حذف الفئة "$category"؟',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCategory(category, categoryIndex);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String category, int categoryIndex) async {
    try {
      final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
      if (ownerId == null || ownerId.isEmpty) return;

      // Find all items with this category and update them to "غير مصنف"
      final itemsToUpdate = _menuItems
          .where((item) => item['category'] == category)
          .toList();

      // Update all items to "غير مصنف" category
      for (final item in itemsToUpdate) {
        final itemId = item['id'] as String?;
        if (itemId != null) {
          try {
            await FirebaseFirestore.instance
                .collection('menuItems')
                .doc(itemId)
                .update({'category': 'غير مصنف'});
          } catch (e) {
            print('Error updating item $itemId: $e');
          }
        }
      }

      // Ensure "غير مصنف" category exists in the list
      bool addedUncategorized = false;
      if (!_categories.contains('غير مصنف')) {
        _categories.insert(1, 'غير مصنف'); // Insert after "جميع العناصر"
        addedUncategorized = true;
      }

      // Adjust categoryIndex if we added "غير مصنف" before it
      int adjustedCategoryIndex = categoryIndex;
      if (addedUncategorized && categoryIndex > 0) {
        adjustedCategoryIndex = categoryIndex + 1;
      }

      // Remove category image if exists
      final categoryImageKey = '${ownerId}_$category';
      await _cacheHelper.removeCategoryImage(categoryImageKey);

      // Store old controller state
      final oldController = _tabController;
      final currentIndex = oldController.index;

      // Remove category from list (use adjusted index)
      if (adjustedCategoryIndex < _categories.length) {
        _categories.removeAt(adjustedCategoryIndex);
      }
      _categoryImages.remove(category);
      _saveCategories();

      // Dispose old controller
      oldController.removeListener(_handleTabChange);
      oldController.dispose();

      // Create new TabController
      final newIndex = currentIndex >= categoryIndex && currentIndex > 0
          ? currentIndex - 1
          : (currentIndex < categoryIndex ? currentIndex : 0);

      _tabController = TabController(
        length: _categories.length,
        vsync: this,
        initialIndex: newIndex.clamp(0, _categories.length - 1),
      );
      _tabController.addListener(_handleTabChange);

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              itemsToUpdate.isNotEmpty
                  ? 'تم حذف الفئة "$category" وتم نقل ${itemsToUpdate.length} عنصر إلى "غير مصنف"'
                  : 'تم حذف الفئة "$category" بنجاح',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الفئة: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showEditCategoryDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String oldCategory,
    int categoryIndex,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _EditCategoryDialogContent(
        theme: theme,
        colorScheme: colorScheme,
        oldCategory: oldCategory,
        oldCategoryImage: _categoryImages[oldCategory],
        onCategoryUpdated: (newCategory, image) async {
          await _updateCategory(oldCategory, newCategory, categoryIndex, image);
        },
        onCancel: () {
          Navigator.pop(context);
        },
        showImageSourceDialog: _showImageSourceDialog,
        imagePicker: _imagePicker,
      ),
    );
  }

  Future<void> _updateCategory(
    String oldCategory,
    String newCategory,
    int categoryIndex,
    XFile? image,
  ) async {
    try {
      final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
      if (ownerId == null || ownerId.isEmpty) return;

      // If category name changed, update menu items
      if (oldCategory != newCategory) {
        final itemsToUpdate = _menuItems
            .where((item) => item['category'] == oldCategory)
            .toList();

        for (final item in itemsToUpdate) {
          final itemId = item['id'] as String?;
          if (itemId != null) {
            try {
              // Update category field in Firestore
              await FirebaseFirestore.instance
                  .collection('menuItems')
                  .doc(itemId)
                  .update({'category': newCategory});
            } catch (e) {
              print('Error updating item $itemId: $e');
            }
          }
        }
      }

      // Update category in list
      _categories[categoryIndex] = newCategory;

      // Handle image update
      if (image != null) {
        // Remove old image if exists
        final oldImageKey = '${ownerId}_$oldCategory';
        await _cacheHelper.removeCategoryImage(oldImageKey);

        // Save new image
        final imageFile = File(image.path);
        if (await imageFile.exists()) {
          final newImageKey = '${ownerId}_$newCategory';
          final savedPath = await _cacheHelper.saveImageFile(
            key: newImageKey,
            imageFile: imageFile,
          );

          if (savedPath != null) {
            _categoryImages.remove(oldCategory);
            _categoryImages[newCategory] = savedPath;
          }
        }
      } else if (oldCategory != newCategory) {
        // If category name changed but no new image, update image key
        final oldImageKey = '${ownerId}_$oldCategory';
        final oldImagePath = _cacheHelper.getCategoryImagePath(oldImageKey);
        if (oldImagePath != null) {
          final oldImageFile = File(oldImagePath);
          if (await oldImageFile.exists()) {
            final newImageKey = '${ownerId}_$newCategory';
            final savedPath = await _cacheHelper.saveImageFile(
              key: newImageKey,
              imageFile: oldImageFile,
            );
            if (savedPath != null) {
              _categoryImages.remove(oldCategory);
              _categoryImages[newCategory] = savedPath;
              await _cacheHelper.removeCategoryImage(oldImageKey);
            }
          }
        }
      }

      _saveCategories();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الفئة بنجاح'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الفئة: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAddCategoryDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AddCategoryDialogContent(
        theme: theme,
        colorScheme: colorScheme,
        onCategoryAdded: (category, image) async {
          // Handle category creation logic here
          final newCategory = category;
          if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
            // Store old controller state before updating
            final oldController = _tabController;
            final currentIndex = oldController.index;
            final newIndex = _categories.length; // Index of the new category

            // Update categories (outside setState to avoid build issues)
            _categories.add(newCategory);
            _saveCategories();

            // Dispose old controller first
            oldController.removeListener(_handleTabChange);
            oldController.dispose();

            // Create new TabController with preserved index
            _tabController = TabController(
              length: _categories.length,
              vsync: this,
              initialIndex: currentIndex < _categories.length
                  ? currentIndex
                  : 0,
            );
            _tabController.addListener(_handleTabChange);

            // Save category image locally if provided (optional)
            if (image != null) {
              try {
                final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
                if (ownerId != null && ownerId.isNotEmpty) {
                  final imageFile = File(image.path);
                  if (await imageFile.exists()) {
                    // Save image to local storage with user-specific key
                    final userCategoryKey = '${ownerId}_$newCategory';
                    final savedPath = await _cacheHelper.saveImageFile(
                      key: userCategoryKey,
                      imageFile: imageFile,
                    );

                    if (savedPath != null) {
                      // Update local state
                      setState(() {
                        _categoryImages[newCategory] = savedPath;
                      });
                    }
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

            // Update UI
            setState(() {});

            // Navigate to the new category after frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _tabController.length > newIndex) {
                _tabController.animateTo(newIndex);
              }
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إضافة الفئة "$newCategory" بنجاح'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
        onCancel: () {
          Navigator.pop(context);
        },
        showImageSourceDialog: _showImageSourceDialog,
        imagePicker: _imagePicker,
      ),
    );
  }

  void _showImageSourceDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    StateSetter setDialogState,
    Function(XFile) onImageSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 2.h),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'camera_alt',
                  color: colorScheme.primary,
                  size: 24,
                ),
                title: Text('التقاط صورة', style: theme.textTheme.titleMedium),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(
                    ImageSource.camera,
                    setDialogState,
                    onImageSelected,
                  );
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'photo_library',
                  color: colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'اختيار من المعرض',
                  style: theme.textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(
                    ImageSource.gallery,
                    setDialogState,
                    onImageSelected,
                  );
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
    Function(XFile) onImageSelected,
  ) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        onImageSelected(image);
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

class _AddCategoryDialogContent extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final Function(String, XFile?) onCategoryAdded;
  final VoidCallback onCancel;
  final Function(
    BuildContext,
    ThemeData,
    ColorScheme,
    StateSetter,
    Function(XFile),
  )
  showImageSourceDialog;
  final ImagePicker imagePicker;

  const _AddCategoryDialogContent({
    required this.theme,
    required this.colorScheme,
    required this.onCategoryAdded,
    required this.onCancel,
    required this.showImageSourceDialog,
    required this.imagePicker,
  });

  @override
  State<_AddCategoryDialogContent> createState() =>
      _AddCategoryDialogContentState();
}

class _AddCategoryDialogContentState extends State<_AddCategoryDialogContent> {
  late TextEditingController _categoryController;
  XFile? _categoryImage;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          'إضافة فئة جديدة',
          style: widget.theme.textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category name field
              TextField(
                controller: _categoryController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الفئة',
                  hintText: 'أدخل اسم الفئة الجديدة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 2.w, right: 2.w),
                    child: CustomIconWidget(
                      iconName: 'category',
                      color: widget.colorScheme.primary,
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
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              GestureDetector(
                onTap: () => _showImageSourceDialog(
                  context,
                  widget.theme,
                  widget.colorScheme,
                  setDialogState,
                  (image) {
                    setDialogState(() {
                      _categoryImage = image;
                    });
                  },
                ),
                child: Container(
                  width: double.infinity,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.colorScheme.outline.withValues(alpha: 0.3),
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
                                  color: widget.colorScheme.surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'edit',
                                    color: widget.colorScheme.primary,
                                    size: 18,
                                  ),
                                  onPressed: () => widget.showImageSourceDialog(
                                    context,
                                    widget.theme,
                                    widget.colorScheme,
                                    setDialogState,
                                    (image) {
                                      setDialogState(() {
                                        _categoryImage = image;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.colorScheme.error.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'delete',
                                    color: widget.colorScheme.onError,
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
                              color: widget.colorScheme.primary,
                              size: 32,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'اضغط لإضافة صورة',
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color: widget.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
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
          TextButton(onPressed: widget.onCancel, child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newCategory = _categoryController.text.trim();
              if (newCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('يرجى إدخال اسم الفئة'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await widget.onCategoryAdded(newCategory, _categoryImage);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.colorScheme.primary,
              foregroundColor: widget.colorScheme.onPrimary,
            ),
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    StateSetter setDialogState,
    Function(XFile) onImageSelected,
  ) {
    widget.showImageSourceDialog(
      context,
      theme,
      colorScheme,
      setDialogState,
      onImageSelected,
    );
  }
}

class _EditCategoryDialogContent extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String oldCategory;
  final String? oldCategoryImage;
  final Function(String, XFile?) onCategoryUpdated;
  final VoidCallback onCancel;
  final Function(
    BuildContext,
    ThemeData,
    ColorScheme,
    StateSetter,
    Function(XFile),
  )
  showImageSourceDialog;
  final ImagePicker imagePicker;

  const _EditCategoryDialogContent({
    required this.theme,
    required this.colorScheme,
    required this.oldCategory,
    required this.oldCategoryImage,
    required this.onCategoryUpdated,
    required this.onCancel,
    required this.showImageSourceDialog,
    required this.imagePicker,
  });

  @override
  State<_EditCategoryDialogContent> createState() =>
      _EditCategoryDialogContentState();
}

class _EditCategoryDialogContentState
    extends State<_EditCategoryDialogContent> {
  late TextEditingController _categoryController;
  XFile? _categoryImage;
  String? _currentImagePath;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.oldCategory);
    _currentImagePath = widget.oldCategoryImage;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('تعديل الفئة', style: widget.theme.textTheme.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category name field
              TextField(
                controller: _categoryController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الفئة',
                  hintText: 'أدخل اسم الفئة الجديدة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 2.w, right: 2.w),
                    child: CustomIconWidget(
                      iconName: 'category',
                      color: widget.colorScheme.primary,
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
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              GestureDetector(
                onTap: () => _showImageSourceDialog(
                  context,
                  widget.theme,
                  widget.colorScheme,
                  setDialogState,
                  (image) {
                    setDialogState(() {
                      _categoryImage = image;
                      _currentImagePath = null;
                    });
                  },
                ),
                child: Container(
                  width: double.infinity,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.colorScheme.outline.withValues(alpha: 0.3),
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
                                  color: widget.colorScheme.surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'edit',
                                    color: widget.colorScheme.primary,
                                    size: 18,
                                  ),
                                  onPressed: () => widget.showImageSourceDialog(
                                    context,
                                    widget.theme,
                                    widget.colorScheme,
                                    setDialogState,
                                    (image) {
                                      setDialogState(() {
                                        _categoryImage = image;
                                        _currentImagePath = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.colorScheme.error.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'delete',
                                    color: widget.colorScheme.onError,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      _categoryImage = null;
                                      _currentImagePath = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      : _currentImagePath != null &&
                            _currentImagePath!.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_currentImagePath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.colorScheme.surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'edit',
                                    color: widget.colorScheme.primary,
                                    size: 18,
                                  ),
                                  onPressed: () => widget.showImageSourceDialog(
                                    context,
                                    widget.theme,
                                    widget.colorScheme,
                                    setDialogState,
                                    (image) {
                                      setDialogState(() {
                                        _categoryImage = image;
                                        _currentImagePath = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.colorScheme.error.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'delete',
                                    color: widget.colorScheme.onError,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      _categoryImage = null;
                                      _currentImagePath = null;
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
                              color: widget.colorScheme.primary,
                              size: 32,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'اضغط لإضافة صورة',
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color: widget.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
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
          TextButton(onPressed: widget.onCancel, child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newCategory = _categoryController.text.trim();
              if (newCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('يرجى إدخال اسم الفئة'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await widget.onCategoryUpdated(newCategory, _categoryImage);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.colorScheme.primary,
              foregroundColor: widget.colorScheme.onPrimary,
            ),
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    StateSetter setDialogState,
    Function(XFile) onImageSelected,
  ) {
    widget.showImageSourceDialog(
      context,
      theme,
      colorScheme,
      setDialogState,
      onImageSelected,
    );
  }
}
