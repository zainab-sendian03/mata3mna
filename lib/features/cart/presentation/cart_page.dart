import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/cart/presentation/cart_detail_page.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:sizer/sizer.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'السلة',
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Obx(() {
            final cartsInfo = cartController.restaurantCartsInfo;
            final currentOwnerId = cartController.currentCartOwnerId.value;

            return IconButton(
              onPressed: () {
                if (cartsInfo.isEmpty) return;

                // If multiple carts, show options
                if (cartsInfo.length > 1 && currentOwnerId != null) {
                  _showClearCartDialog(
                    context,
                    cartController,
                    theme,
                    colorScheme,
                    currentOwnerId,
                    cartsInfo,
                  );
                } else {
                  // Single cart or no current cart
                  _showClearCartDialog(
                    context,
                    cartController,
                    theme,
                    colorScheme,
                    currentOwnerId!,
                    cartsInfo,
                  );
                }
              },
              icon: Icon(Icons.delete_sweep),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final cartsInfo = cartController.restaurantCartsInfo;

          // Show empty state if no carts
          if (cartsInfo.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 20.w,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 2.h),
                  Text('السلة فارغة', style: theme.textTheme.titleLarge),
                  SizedBox(height: 1.h),
                  Text(
                    'أضف أصنافاً من القائمة',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          // Show carts as cards (works for both single and multiple)
          return _buildCartsCardsView(cartController, theme, colorScheme);
        }),
      ),
    );
  }

  Widget _buildCartsCardsView(
    CartController cartController,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final cartsInfo = cartController.restaurantCartsInfo;

    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: cartsInfo.length,
      itemBuilder: (context, index) {
        final cartInfo = cartsInfo[index];
        final ownerId = cartInfo['ownerId'] as String;
        final restaurantName = cartInfo['restaurantName'] as String;
        final itemCount = cartInfo['itemCount'] as int;
        final totalPrice = cartInfo['totalPrice'] as double;

        return Container(
          margin: EdgeInsets.only(bottom: 3.h),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartDetailPage(
                    ownerId: ownerId,
                    restaurantName: restaurantName,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  // Restaurant Icon/Info
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      color: colorScheme.primary,
                      size: 6.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  // Restaurant Name and Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Row(
                          children: [
                            Text(
                              '$itemCount عنصر',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              '•',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              '${totalPrice.toStringAsFixed(2)} \$',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Arrow Icon
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 5.w,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showClearCartDialog(
    BuildContext context,
    CartController cartController,
    ThemeData theme,
    ColorScheme colorScheme,
    String currentOwnerId,
    List<Map<String, dynamic>> cartsInfo,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مسح جميع السلات', style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من مسح جميع السلات؟',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              cartController.clearCart(clearAll: true); // Clear all carts
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم مسح جميع السلات بنجاح'),
                  backgroundColor: colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'نعم، مسح الكل',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
