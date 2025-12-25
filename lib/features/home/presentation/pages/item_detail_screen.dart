import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:mata3mna/config/themes/assets.dart';
import 'package:mata3mna/core/constants/custom_app_bar.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:sizer/sizer.dart';

/// Screen for displaying detailed information about a menu item
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final CartController _cartController = Get.find<CartController>();
  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();

  Map<String, dynamic>? _item;
  Map<String, dynamic>? _restaurant;
  bool _isLoading = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadItemData();
  }

  Future<void> _loadItemData() async {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _item = args['item'] as Map<String, dynamic>?;
      if (_item != null) {
        final ownerId = _item!['ownerId'] as String?;
        if (ownerId != null && ownerId.isNotEmpty) {
          try {
            final restaurantInfo = await _restaurantService
                .getRestaurantInfoByOwnerId(ownerId);
            if (restaurantInfo != null && mounted) {
              setState(() {
                _restaurant = restaurantInfo;
                _isLoading = false;
              });
            } else {
              setState(() {
                _isLoading = false;
              });
            }
          } catch (e) {
            setState(() {
              _isLoading = false;
            });
          }
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
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToCart() async {
    if (_item == null) return;

    final ownerId = _item!['ownerId'] as String?;
    final itemName = _item!['name'] as String? ?? '';

    if (ownerId != null && ownerId.isNotEmpty) {
      // Add item multiple times based on quantity
      for (int i = 0; i < _quantity; i++) {
        await _cartController.addItem(_item!, ownerId);
      }

      Get.snackbar(
        'تمت الإضافة',
        'تم إضافة $itemName إلى السلة',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: CustomAppBar(
          title: 'تفاصيل العنصر',
          variant: CustomAppBarVariant.standard,
          showBackButton: true,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: CustomAppBar(
          title: 'تفاصيل العنصر',
          variant: CustomAppBarVariant.standard,
          showBackButton: true,
          onBackPressed: () => Get.toNamed(AppPages.restaurantDetail),
        ),
        body: Center(
          child: Text('العنصر غير موجود', style: theme.textTheme.titleLarge),
        ),
      );
    }

    final itemName = _item!['name'] ?? 'بدون اسم';
    final itemPrice = _item!['price'] ?? '';
    final itemDescription = _item!['description'] ?? '';
    final itemImage = _item!['image'] ?? '';
    final itemCategory = _item!['category'] ?? '';
    final restaurantName = _item!['restaurantName'] ?? '';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: CustomAppBar(
        title: itemName,
        variant: CustomAppBarVariant.standard,
        showBackButton: true,
        onBackPressed: () => Get.offNamed(
          AppPages.restaurantDetail,
          arguments: {'restaurant': _restaurant, 'ownerId': _item!['ownerId']},
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            _buildItemImage(itemImage, colorScheme),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          itemName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        itemPrice.isNotEmpty ? '$itemPrice \$' : '',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  // Category
                  if (itemCategory.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        itemCategory,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  SizedBox(height: 2.h),
                  // Restaurant info
                  if (restaurantName.isNotEmpty || _restaurant != null)
                    _buildRestaurantInfo(theme, colorScheme),
                  SizedBox(height: 2.h),
                  // Description
                  if (itemDescription.isNotEmpty) ...[
                    Text(
                      'الوصف',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(itemDescription, style: theme.textTheme.bodyLarge),
                    SizedBox(height: 2.h),
                  ],
                  // Quantity selector
                  _buildQuantitySelector(theme, colorScheme),
                  SizedBox(height: 3.h),
                  // Add to cart button
                  SizedBox(
                    width: double.infinity,
                    height: 6.h,
                    child: ElevatedButton(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomIconWidget(
                            iconName: 'shopping_cart',
                            color: colorScheme.onPrimary,
                            size: 6.w,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'إضافة إلى السلة',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(String imageUrl, ColorScheme colorScheme) {
    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 40.h,
        color: colorScheme.surfaceContainerHighest,
        child: Center(child: Image.asset(Assets.assetsImagesLogoM)),
      );
    }

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: 40.h,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: 40.h,
          color: colorScheme.surfaceContainerHighest,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          height: 40.h,
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: CustomIconWidget(
              iconName: 'restaurant',
              color: colorScheme.onSurface.withValues(alpha: 0.3),
              size: 20.w,
            ),
          ),
        ),
      );
    }

    final file = File(imageUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: double.infinity,
        height: 40.h,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: double.infinity,
      height: 40.h,
      color: colorScheme.surfaceContainerHighest,
      child: Center(child: Image.asset(Assets.assetsImagesLogoM)),
    );
  }

  Widget _buildRestaurantInfo(ThemeData theme, ColorScheme colorScheme) {
    final restaurantName = _item!['restaurantName'] ?? '';
    final governorate = _restaurant?['governorate'] ?? '';
    final city = _restaurant?['city'] ?? '';

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant, color: colorScheme.primary, size: 6.w),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (restaurantName.isNotEmpty)
                  Text(
                    restaurantName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'الكمية:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 3.w),
        IconButton(
          onPressed: () {
            if (_quantity > 1) {
              setState(() {
                _quantity--;
              });
            }
          },
          icon: Icon(Icons.remove_circle_outline),
          color: colorScheme.primary,
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_quantity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _quantity++;
            });
          },
          icon: Icon(Icons.add_circle_outline),
          color: colorScheme.primary,
        ),
      ],
    );
  }
}
