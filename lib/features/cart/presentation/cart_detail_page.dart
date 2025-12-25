import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:mata3mna/features/cart/presentation/controllers/cart_controller.dart';
import 'package:sizer/sizer.dart';

class CartDetailPage extends StatelessWidget {
  final String ownerId;
  final String restaurantName;

  const CartDetailPage({
    super.key,
    required this.ownerId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notesController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          restaurantName,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Obx(() {
          // Access restaurantCarts to ensure proper observation
          final _ = cartController.restaurantCarts[ownerId];
          final cartItems = cartController.getCartItemsList(ownerId: ownerId);
          final totalPrice = cartController.getTotalPrice(ownerId: ownerId);

          return Column(
            children: [
              Expanded(
                child: cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 20.w,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'السلة فارغة',
                              style: theme.textTheme.titleLarge,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'أضف أصنافاً من $restaurantName',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(4.w),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final cartItem = cartItems[index];
                          return _buildCartItemCard(
                            cartItem,
                            theme,
                            colorScheme,
                            cartController,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: TextFormField(
                  maxLines: 3,
                  controller: notesController,
                  decoration: InputDecoration(
                    suffixIcon: CustomIconWidget(
                      iconName: 'note_add',
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    hintText: 'اضف ملاحظاتك هنا ...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              SizedBox(height: 2.h),
              // Cart Summary
              Container(
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الإجمالي',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${totalPrice.toStringAsFixed(2)} \$',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 2.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await cartController
                              .sendOrderViaWhatsApp(
                                ownerId: ownerId,
                                notes: notesController.text,
                                context: context,
                              );
                          if (success && context.mounted) {
                            await Future.delayed(const Duration(seconds: 4));
                            _showClearCartDialog(
                              context,
                              cartController,
                              theme,
                              colorScheme,
                              ownerId,
                              restaurantName,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إرسال الطلب عبر واتساب',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCartItemCard(
    Map<String, dynamic> item,
    ThemeData theme,
    ColorScheme colorScheme,
    CartController cartController,
  ) {
    final itemId = item['id'] as String? ?? '';
    final name = item['name'] ?? 'عنصر بدون اسم';
    final price = item['price'] ?? '0';
    final quantity = item['cartQuantity'] as int? ?? 1;
    final image = item['image'] ?? '';
    final totalPrice = (double.tryParse(price.toString()) ?? 0.0) * quantity;
    final ownerId = item['ownerId'] as String? ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          Padding(
            padding: EdgeInsets.all(3.w),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image.toString(),
                      width: 20.w,
                      height: 20.w,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 20.w,
                        height: 20.w,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 20.w,
                        height: 20.w,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.fastfood,
                          size: 10.w,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : Container(
                      width: 20.w,
                      height: 20.w,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.fastfood,
                        size: 10.w,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
            ),
          ),
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
                SizedBox(height: 0.5.h),
                Text(
                  '$price \$ × $quantity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'الإجمالي: ${totalPrice.toStringAsFixed(2)} \$',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Quantity controls
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: () {
                  if (ownerId.isNotEmpty) {
                    cartController.addItem(item, ownerId);
                  }
                },
                color: colorScheme.primary,
              ),
              Text(
                quantity.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                onPressed: () {
                  cartController.removeItem(itemId, ownerId: ownerId);
                },
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(
    BuildContext context,
    CartController cartController,
    ThemeData theme,
    ColorScheme colorScheme,
    String ownerId,
    String restaurantName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تم إرسال الطلب بنجاح', style: theme.textTheme.titleLarge),
        content: Text(
          'هل تريد مسح سلة $restaurantName؟',
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'لا',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              cartController.clearCart(ownerId: ownerId);
              Navigator.pop(context);
              Navigator.pop(context); // Close cart detail page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم مسح السلة بنجاح'),
                  backgroundColor: colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'نعم، مسح السلة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
