import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:sizer/sizer.dart';

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen>
    with TickerProviderStateMixin {
  final MenuFirestoreService _menuService = Get.find<MenuFirestoreService>();
  final CartController _cartController = Get.find<CartController>();
  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();

  String? _ownerId;
  Map<String, dynamic>? _restaurant;
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, List<Map<String, dynamic>>> _itemsByCategory = {};
  List<String> _categories = ['جميع العناصر'];
  Map<String, String> _categoryImages = {};
  String? _restaurantLogoUrl;
  TabController? _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _restaurant = args['restaurant'] as Map<String, dynamic>?;
      _ownerId = args['ownerId'] as String?;

      if (_ownerId != null && _ownerId!.isNotEmpty) {
        _loadRestaurantLogo();
        _menuService.getMenuItemsStream(_ownerId).listen((items) {
          if (mounted) {
            setState(() {
              _menuItems = items;
              _groupItemsByCategory(items);
              _updateCategories();
              _loadCategoryImages();
              _isLoading = false;
            });
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRestaurantLogo() async {
    try {
      if (_ownerId != null && _ownerId!.isNotEmpty) {
        final restaurantInfo = await _restaurantService
            .getRestaurantInfoByOwnerId(_ownerId!);
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
      _categoryImages = {};
      for (final category in _categories) {
        if (category != 'جميع العناصر') {
          final imagePath = _cacheHelper.getCategoryImagePath(
            '${_ownerId}_$category',
          );
          if (imagePath != null && imagePath.isNotEmpty) {
            final file = File(imagePath);
            if (file.existsSync()) {
              _categoryImages[category] = imagePath;
            }
          }
        }
      }
    } catch (e) {
      _categoryImages = {};
    }
  }

  void _updateCategories() {
    final categories = ['جميع العناصر', ..._itemsByCategory.keys.toList()];
    if (categories.length != _categories.length ||
        !categories.every((cat) => _categories.contains(cat))) {
      final oldController = _tabController;
      _categories = categories;
      oldController?.dispose();
      _tabController = TabController(
        length: _categories.length,
        vsync: this,
        initialIndex: 0,
      );
    }
  }

  /// Group menu items by category
  void _groupItemsByCategory(List<Map<String, dynamic>> items) {
    _itemsByCategory = {};
    for (var item in items) {
      final category = item['category'] as String? ?? 'غير مصنف';
      if (!_itemsByCategory.containsKey(category)) {
        _itemsByCategory[category] = [];
      }
      _itemsByCategory[category]!.add(item);
    }
    // Sort categories alphabetically
    final sortedCategories = _itemsByCategory.keys.toList()..sort();
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (var category in sortedCategories) {
      sortedMap[category] = _itemsByCategory[category]!;
    }
    _itemsByCategory = sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('تفاصيل المطعم'),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_restaurant == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('تفاصيل المطعم'),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          body: const Center(child: Text('المطعم غير موجود')),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _restaurant?['name'],
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Category Tabs
            if (_categories.length > 1 && _tabController != null)
              TabBar(
                controller: _tabController!,
                isScrollable: true,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                indicatorColor: colorScheme.primary,
                tabs: _categories.map((category) {
                  return Tab(text: category);
                }).toList(),
              ),
            // Menu Items
            Expanded(
              child: _menuItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 20.w,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'لا توجد عناصر في القائمة',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    )
                  : _tabController != null
                  ? TabBarView(
                      controller: _tabController!,
                      children: _categories.map((category) {
                        final items = category == 'جميع العناصر'
                            ? _menuItems
                            : (_itemsByCategory[category] ?? []);
                        return ListView.builder(
                          padding: EdgeInsets.all(4.w),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildMenuItemCard(
                              context,
                              item,
                              colorScheme,
                            );
                          },
                        );
                      }).toList(),
                    )
                  : const SizedBox(),
            ),
            // Cart Summary (if items in cart)
            Obx(() {
              if (_ownerId == null ||
                  _ownerId!.isEmpty ||
                  _cartController.getCartItems(_ownerId!).isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_cartController.getTotalItems(ownerId: _ownerId)} عنصر',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${_cartController.getTotalPrice(ownerId: _ownerId).toStringAsFixed(2)} \$',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Get.toNamed(AppPages.cart);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                      ),
                      child: const Text('عرض السلة'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(
    BuildContext context,
    Map<String, dynamic> item,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final name = item['name'] ?? 'بدون اسم';
    final description = item['description'] ?? '';
    final price = item['price'] ?? '0';
    final image = item['image'] ?? '';
    final itemId = item['id'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(3.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: image,
                  width: 25.w,
                  height: 25.w,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 25.w,
                    height: 25.w,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 25.w,
                    height: 25.w,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.fastfood,
                      size: 10.w,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 25.w,
                  height: 25.w,
                  color: colorScheme.surfaceContainerHighest,
                  child: Center(child: Image.asset(Assets.assetsImagesLogoM)),
                ),
              ),
            ],

            SizedBox(width: 3.w),
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
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$price \$',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Add to cart button
                      Obx(() {
                        final quantity = _cartController.getItemQuantity(
                          itemId,
                          ownerId: _ownerId,
                        );
                        if (quantity > 0) {
                          return Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  _cartController.removeItem(
                                    itemId,
                                    ownerId: _ownerId,
                                  );
                                },
                                color: colorScheme.primary,
                              ),
                              Text(
                                quantity.toString(),
                                style: theme.textTheme.titleMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  if (_ownerId != null) {
                                    _cartController.addItem(item, _ownerId!);
                                  }
                                },
                                color: colorScheme.primary,
                              ),
                            ],
                          );
                        }
                        return IconButton(
                          onPressed: () {
                            if (_ownerId != null) {
                              _cartController.addItem(item, _ownerId!);
                            }
                          },
                          icon: Icon(
                            Icons.add_shopping_cart,
                            size: 5.w,
                            color: colorScheme.primary,
                          ),
                          color: colorScheme.primary,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
