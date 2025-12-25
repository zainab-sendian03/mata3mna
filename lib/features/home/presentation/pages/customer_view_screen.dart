import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/features/home/presentation/controllers/customer_view_controller.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mata3mna/features/cart/presentation/cart_page.dart';
import 'package:sizer/sizer.dart';

/// Customer View Screen - Read-only view of all restaurant menus
/// Shows all menu items from all restaurants for browsing
class CustomerViewScreen extends StatefulWidget {
  const CustomerViewScreen({super.key});

  @override
  State<CustomerViewScreen> createState() => _CustomerViewScreenState();
}

class _CustomerViewScreenState extends State<CustomerViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late final CustomerViewController _controller;
  final CartController _cartController = Get.find<CartController>();
  int _currentPageIndex = 0; // 0 = Menu, 1 = Cart

  @override
  void initState() {
    super.initState();
    _controller = Get.put(CustomerViewController());
    _tabController = TabController(
      length: _controller.categories.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_controller.searchQuery.value.isNotEmpty) {
        _searchController.clear();
        _controller.clearSearch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colorScheme.surface,
      appBar: _currentPageIndex == 0 ? _buildAppBar(theme, colorScheme) : null,
      body: _currentPageIndex == 0
          ? _buildMenuPage(theme, colorScheme)
          : CartPage(),
      bottomNavigationBar: _buildBottomNavBar(theme, colorScheme),
    );
  }

  Widget _buildMenuPage(ThemeData theme, ColorScheme colorScheme) {
    return Obx(() {
      if (_controller.isLoadingRestaurants.value) {
        return _buildLoadingState();
      }

      if (_controller.filteredRestaurants.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'search_off_rounded',
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20.w,
                ),
                SizedBox(height: 2.h),
                Text(
                  'لم يتم العثور على مطاعم',
                  style: theme.textTheme.titleLarge,
                ),
                SizedBox(height: 1.h),
                Text(
                  _controller.hasActiveFilters
                      ? 'لا توجد مطاعم في المنطقة المحددة'
                      : _controller.searchQuery.value.isNotEmpty
                      ? 'حاول البحث باسم مطعم آخر'
                      : 'لا توجد مطاعم متاحة',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          Obx(
            () => _controller.hasActiveFilters
                ? _buildActiveFiltersChips(theme, colorScheme)
                : SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _controller.handleRefresh,
              child: ListView.builder(
                padding: EdgeInsets.all(2.w),
                itemCount: _controller.filteredRestaurants.length,
                itemBuilder: (context, index) {
                  final restaurant = _controller.filteredRestaurants[index];
                  return Column(
                    children: [
                      _buildRestaurantCard(restaurant, theme, colorScheme),
                      Divider(
                        color: colorScheme.outline.withValues(alpha: 1),
                        thickness: 1,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return PreferredSize(
      preferredSize: Size.fromHeight(19.h),
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
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ' مرحباً بك!',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'أهلاً بك في تطبيق مطاعمنا',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    _buildSearchHeader(theme, colorScheme),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          Obx(
            () => _controller.hasActiveFilters
                ? IconButton(
                    onPressed: _controller.clearFilters,
                    icon: Icon(
                      Icons.filter_alt_off_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'إزالة الفلاتر',
                  )
                : SizedBox.shrink(),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159),
            child: Obx(
              () => IconButton(
                onPressed: () =>
                    _showFilterBottomSheet(context, theme, colorScheme),
                icon: Icon(
                  Icons.tune_rounded,
                  color: _controller.hasActiveFilters
                      ? Colors.amber
                      : Colors.white,
                ),
                tooltip: 'الفلاتر',
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159),
            child: IconButton(
              onPressed: _showLogoutDialog,
              icon: Icon(
                Icons.logout_rounded,
                color: theme.scaffoldBackgroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(ThemeData theme, ColorScheme colorScheme) {
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
                hintText: 'ابحث عن مطعم أو طعام...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 10.sp,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              onChanged: (value) => _controller.updateSearchQuery(value),
            ),
          ),
          Obx(
            () =>
                _controller.isLoadingRestaurants.value &&
                    _controller.searchQuery.value.isNotEmpty
                ? SizedBox(
                    width: 30,
                    height: 30,
                    child: Padding(
                      padding: EdgeInsets.all(4.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.search_rounded,
                    color: colorScheme.primary,
                    size: 30,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _buildActiveFiltersChips(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      child: Row(
        children: [
          Wrap(
            spacing: .5.w,
            runSpacing: .5.h,
            children: [
              Obx(
                () => _controller.selectedGovernorate.value != null
                    ? Chip(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        label: Text(
                          'المحافظة: ${_controller.selectedGovernorate.value}',
                        ),
                        onDeleted: () {
                          _controller.setGovernorate(null);
                        },
                        deleteIcon: Icon(Icons.close, size: 18),
                      )
                    : SizedBox.shrink(),
              ),
              Obx(
                () => _controller.selectedCity.value != null
                    ? Chip(
                        label: Text(
                          'المدينة: ${_controller.selectedCity.value}',
                        ),
                        onDeleted: () => _controller.setCity(null),
                        deleteIcon: Icon(Icons.close, size: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      )
                    : SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(5.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الفلاتر',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Obx(
                () => _buildFilterDropdown(
                  label: 'المحافظة',
                  value: _controller.selectedGovernorate.value,
                  items: _controller.governorates,
                  onChanged: (value) {
                    _controller.setGovernorate(value);
                    setModalState(() {});
                  },
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ),
              SizedBox(height: 2.h),
              Obx(
                () => _buildFilterDropdown(
                  label: 'المدينة',
                  value: _controller.selectedCity.value,
                  items: _controller.getAvailableCities(),
                  onChanged: (value) {
                    _controller.setCity(value);
                    setModalState(() {});
                  },
                  theme: theme,
                  colorScheme: colorScheme,
                  enabled: _controller.selectedGovernorate.value != null,
                ),
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => OutlinedButton(
                        onPressed: _controller.hasActiveFilters
                            ? () {
                                _controller.clearFilters();
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text('إزالة الفلاتر'),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: Text('تطبيق'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required ThemeData theme,
    required ColorScheme colorScheme,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
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
            value: value != null && items.contains(value) ? value : null,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4.w,
                vertical: 2.h,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
            hint: Text('اختر $label'),
            items: () {
              final uniqueItems = items.toSet().toList()..sort();
              return [
                DropdownMenuItem<String>(value: null, child: Text('الكل')),
                ...uniqueItems.map(
                  (item) =>
                      DropdownMenuItem<String>(value: item, child: Text(item)),
                ),
              ];
            }(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text(
          "تسجيل الخروج",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("هل أنت متأكد أنك تريد تسجيل الخروج؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _controller.handleLogout();
            },
            child: Text(
              "تسجيل خروج",
              style: TextStyle(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(
    Map<String, dynamic> restaurant,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final name = restaurant['name'] ?? 'بدون اسم';
    final description = restaurant['description'] ?? '';
    final logoPath = restaurant['logoPath'] ?? '';
    final governorate = restaurant['governorate'] ?? '';
    final city = restaurant['city'] ?? '';
    final ownerId = restaurant['ownerId'] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Get.toNamed(
                AppPages.restaurantDetail,
                arguments: {'restaurant': restaurant, 'ownerId': ownerId},
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: Row(
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: logoPath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: logoPath,
                            width: 20.w,
                            height: 20.w,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 20.w,
                              height: 20.w,
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 20.w,
                              height: 20.w,
                              color: colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Image.asset(Assets.assetsImagesLogoM),
                              ),
                            ),
                          )
                        : Container(
                            width: 20.w,
                            height: 20.w,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.restaurant,
                              size: 10.w,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(width: 4.w),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          SizedBox(height: 0.5.h),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (governorate.isNotEmpty || city.isNotEmpty) ...[
                          SizedBox(height: 0.5.h),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 4.w,
                                color: colorScheme.primary,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                '$governorate${city.isNotEmpty ? ' - $city' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Show categories before search
                        Obx(() {
                          if (_controller.searchQuery.value.isEmpty) {
                            final categories = _controller
                                .getRestaurantCategories(ownerId);
                            if (categories.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 1.h),
                                  Wrap(
                                    spacing: 1.w,
                                    runSpacing: 0.5.h,
                                    children: categories.take(4).map((
                                      category,
                                    ) {
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2.w,
                                          vertical: 0.5.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          category,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                                fontSize: 8.sp,
                                              ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Show matching items if search is active
          Obx(() {
            final matchingItems = _controller.getMatchingItemsForRestaurant(
              ownerId,
            );
            if (_controller.searchQuery.value.isNotEmpty &&
                matchingItems.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 1.h),
                  SizedBox(
                    height: 40.w,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 3.w),
                      itemCount: matchingItems.length,
                      itemBuilder: (context, index) {
                        final item = matchingItems[index];
                        return _buildMatchingItemCard(item, theme, colorScheme);
                      },
                    ),
                  ),
                  SizedBox(height: 1.h),
                ],
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(ThemeData theme, ColorScheme colorScheme) {
    return Obx(() {
      final cartItemCount = _cartController.totalItems;
      final cartsCount = _cartController.restaurantCarts.length;

      return BottomNavigationBar(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerLow,
        currentIndex: _currentPageIndex,
        onTap: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'القائمة',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(Icons.shopping_cart),
                if (cartItemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        cartsCount > 99 ? '99+' : cartsCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'السلة',
          ),
        ],
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
      );
    });
  }

  Widget _buildMatchingItemCard(
    Map<String, dynamic> item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final itemName = item['name'] ?? 'بدون اسم';
    final itemPrice = item['price'] ?? '';
    final itemImage = item['image'] ?? '';

    return GestureDetector(
      onTap: () {
        Get.toNamed(AppPages.itemDetail, arguments: {'item': item});
      },
      child: Container(
        width: 30.w,
        margin: EdgeInsets.only(left: 2.w),
        decoration: BoxDecoration(
          //no border
          border: Border(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Item image
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: itemImage.toString().isNotEmpty
                    ? (itemImage.toString().startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: itemImage.toString(),
                              width: 25.w,
                              height: 25.w,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 25.w,
                                height: 25.w,
                                color: colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 25.w,
                                height: 25.w,
                                color: colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Image.asset(Assets.assetsImagesLogoM),
                                ),
                              ),
                            )
                          : Image.file(
                              File(itemImage.toString()),
                              width: 25.w,
                              height: 25.w,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 25.w,
                                    height: 25.w,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Center(
                                      child: Image.asset(
                                        Assets.assetsImagesLogoM,
                                      ),
                                    ),
                                  ),
                            ))
                    : Container(
                        width: 25.w,
                        height: 25.w,
                        color: colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Image.asset(Assets.assetsImagesLogoM),
                        ),
                      ),
              ),
            ),

            // Item info
            Text(
              itemName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              itemPrice.toString() + ' \$',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
