import 'dart:async';
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
  final MenuSupabaseService _menuService = Get.find<MenuSupabaseService>();
  final CartController _cartController = Get.find<CartController>();
  final RestaurantSupabaseService _restaurantService =
      Get.find<RestaurantSupabaseService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();

  String? _ownerId;
  String? _restaurantId; // items are related to restaurant_id
  Map<String, dynamic>? _restaurant;
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, List<Map<String, dynamic>>> _itemsByCategory = {};
  List<String> _categories = [];
  Map<String, String> _categoryImages = {};
  String? _restaurantLogoUrl;
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();

  /// Start scroll offset for each category section (for auto tab switch)
  List<double> _sectionStartOffsets = [];
  static const double _sectionHeaderHeight = 52;
  static const double _itemCardHeight = 110;
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _menuItemsSubscription;
  // Map to track expanded state for each item's description
  final Map<String, bool> _expandedDescriptions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _scrollToSection(int index) {
    if (index < 0 || index >= _sectionStartOffsets.length) return;
    if (!_scrollController.hasClients) return;
    final offset = _sectionStartOffsets[index].clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    // Safely cancel subscription to avoid Supabase Realtime errors
    try {
      _menuItemsSubscription?.cancel();
    } catch (e) {
      print(
        '[RestaurantDetailScreen] Error cancelling menu items subscription: $e',
      );
      // Ignore - subscription may already be cancelled
    }
    _menuItemsSubscription = null;

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _restaurant = args['restaurant'] as Map<String, dynamic>?;
      final rest = _restaurant;
      final argRestaurantId = args['restaurantId'] as String?;
      _restaurantId = (argRestaurantId ?? rest?['id']?.toString() ?? '')
          .toString()
          .trim();
      final argOwnerId = args['ownerId'] as String?;
      _ownerId = (argOwnerId ?? rest?['ownerId'] ?? rest?['owner_id'] ?? '')
          .toString()
          .trim();

      // Items are related to restaurant_id: prefer loading by restaurant_id when available
      final canLoadByRestaurantId =
          _restaurantId != null && _restaurantId!.isNotEmpty;
      final canLoadByOwnerId = _ownerId != null && _ownerId!.isNotEmpty;

      // If we came from item-detail without restaurant object, fetch it by id or ownerId
      if (_restaurant == null && (canLoadByRestaurantId || canLoadByOwnerId)) {
        try {
          Map<String, dynamic>? fetched;
          if (canLoadByRestaurantId) {
            fetched = await _restaurantService.getRestaurantById(
              _restaurantId!,
            );
          }
          if (fetched == null && canLoadByOwnerId) {
            fetched = await _restaurantService.getRestaurantByOwnerId(
              _ownerId!,
            );
          }
          if (fetched != null && mounted) {
            _restaurant = fetched;
          }
        } catch (e) {
          print('[RestaurantDetailScreen] Error fetching restaurant: $e');
        }
      }

      if (canLoadByRestaurantId || canLoadByOwnerId) {
        print(
          '[RestaurantDetailScreen] Loading menu items restaurantId: $_restaurantId, ownerId: $_ownerId, restaurant: ${_restaurant?['name']}',
        );
        _loadRestaurantLogo();

        try {
          final initialItems = canLoadByRestaurantId
              ? await _menuService.getMenuItemsByRestaurantId(_restaurantId!)
              : await _menuService.getMenuItems(_ownerId!);
          if (mounted) {
            setState(() {
              _menuItems = initialItems;
              _groupItemsByCategory(initialItems);
              _updateCategories();
              _loadCategoryImages();
              _isLoading = false;
            });
          }
        } catch (e) {
          print('[RestaurantDetailScreen] Initial menu load error: $e');
          if (mounted) setState(() => _isLoading = false);
        }

        try {
          _menuItemsSubscription?.cancel();
        } catch (e) {
          print(
            '[RestaurantDetailScreen] Error cancelling previous subscription: $e',
          );
        }
        _menuItemsSubscription = null;

        final stream = canLoadByRestaurantId
            ? _menuService.getMenuItemsStreamByRestaurantId(_restaurantId!)
            : _menuService.getMenuItemsStream(_ownerId!);
        _menuItemsSubscription = stream.listen(
          (items) {
            if (mounted) {
              setState(() {
                _menuItems = items;
                _groupItemsByCategory(items);
                _updateCategories();
                _loadCategoryImages();
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print('[RestaurantDetailScreen] Error loading menu items: $error');
            if (mounted) setState(() => _isLoading = false);
          },
        );
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
        final restaurantInfo = await _restaurantService.getRestaurantByOwnerId(
          _ownerId!,
        );
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
    } catch (e) {
      _categoryImages = {};
    }
  }

  void _updateCategories() {
    final categories = _itemsByCategory.keys.toList()..sort();
    if (categories.isEmpty) return;
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
    _computeSectionOffsets();
  }

  void _computeSectionOffsets() {
    double offset = 0;
    final list = <double>[0];
    for (final category in _categories) {
      final count = _itemsByCategory[category]?.length ?? 0;
      offset += _sectionHeaderHeight + (count * _itemCardHeight);
      list.add(offset);
    }
    _sectionStartOffsets = list;
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _tabController == null ||
        _sectionStartOffsets.length <= 1)
      return;
    final pixels = _scrollController.offset;
    int index = 0;
    for (int i = 0; i < _sectionStartOffsets.length - 1; i++) {
      if (pixels >= _sectionStartOffsets[i] - 20) index = i;
    }
    if (index != _tabController!.index) {
      _tabController!.animateTo(
        index,
        duration: const Duration(milliseconds: 100),
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
            // Category Tabs (tap scrolls to section; scroll updates active tab)
            if (_categories.length >= 1 && _tabController != null)
              TabBar(
                controller: _tabController!,
                isScrollable: true,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                indicatorColor: colorScheme.primary,
                onTap: _scrollToSection,
                tabs: _categories.map((category) {
                  return Tab(text: category);
                }).toList(),
              ),
            // Menu Items: single scrollable list with section headers (auto tab switch on scroll)
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
                  ? CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        for (final category in _categories) ...[
                          SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              context,
                              category,
                              theme,
                              colorScheme,
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final items =
                                      _itemsByCategory[category] ?? [];
                                  if (index >= items.length) return null;
                                  final item = items[index];
                                  return _buildMenuItemCard(
                                    context,
                                    item,
                                    colorScheme,
                                  );
                                },
                                childCount:
                                    _itemsByCategory[category]?.length ?? 0,
                              ),
                            ),
                          ),
                        ],
                        SliverToBoxAdapter(child: SizedBox(height: 2.h)),
                      ],
                    )
                  : const SizedBox(),
            ),
            // Cart Summary (if items in cart) — use GetBuilder to avoid Obx dependency issues
            GetBuilder<CartController>(
              builder: (_) {
                final ownerId = _ownerId;
                if (ownerId == null || ownerId.isEmpty) {
                  return const SizedBox.shrink();
                }
                final cart = _cartController.getCartItems(ownerId);
                if (cart.isEmpty) {
                  return const SizedBox.shrink();
                }
                final totalItems = _cartController.getTotalItems(
                  ownerId: ownerId,
                );
                final totalPrice = _cartController.getTotalPrice(
                  ownerId: ownerId,
                );
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalItems عنصر',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${totalPrice.toStringAsFixed(2)} \$',
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String category,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
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

    // Check if description should be expandable
    final isExpanded = _expandedDescriptions[itemId] ?? false;
    final shouldShowReadMore =
        description.length > 100 || description.split('\n').length > 2;

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
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (shouldShowReadMore) ...[
                      SizedBox(height: 0.5.h),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _expandedDescriptions[itemId] = !isExpanded;
                          });
                        },
                        child: Text(
                          isExpanded ? 'اقرأ أقل' : 'اقرأ المزيد',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                      // Add to cart button — use GetBuilder to avoid Obx dependency issues
                      GetBuilder<CartController>(
                        builder: (_) {
                          final ownerId = _ownerId;
                          final quantity = ownerId != null
                              ? _cartController.getItemQuantity(
                                  itemId,
                                  ownerId: ownerId,
                                )
                              : 0;
                          if (quantity > 0) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
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
                        },
                      ),
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
