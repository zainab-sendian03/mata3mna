import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CartController extends GetxController {
  // Multiple carts: {ownerId: {itemId: {item: Map, quantity: int, restaurantName: String}}}
  final RxMap<String, Map<String, Map<String, dynamic>>> restaurantCarts =
      <String, Map<String, Map<String, dynamic>>>{}.obs;

  // Current active cart ownerId
  final Rxn<String> currentCartOwnerId = Rxn<String>();

  final RestaurantSupabaseService _restaurantService =
      Get.find<RestaurantSupabaseService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();

  static const String _cartDataKey = 'saved_cart_data';
  static const String _currentCartOwnerIdKey = 'current_cart_owner_id';

  /// Get cart items for a specific restaurant
  Map<String, Map<String, dynamic>> getCartItems(String ownerId) {
    return restaurantCarts[ownerId] ?? <String, Map<String, dynamic>>{};
  }

  /// Get current active cart items
  Map<String, Map<String, dynamic>> get currentCartItems {
    if (currentCartOwnerId.value == null) {
      return <String, Map<String, dynamic>>{};
    }
    return getCartItems(currentCartOwnerId.value!);
  }

  /// Resolve restaurant info by owner_id or by restaurant id (when owner_id is null)
  Future<Map<String, dynamic>?> _getRestaurantInfo(String ownerOrRestaurantId) async {
    if (ownerOrRestaurantId.isEmpty) return null;
    try {
      Map<String, dynamic>? info = await _restaurantService.getRestaurantByOwnerId(
        ownerOrRestaurantId,
      );
      if (info == null) {
        info = await _restaurantService.getRestaurantById(ownerOrRestaurantId);
      }
      return info;
    } catch (e) {
      return null;
    }
  }

  /// Add item to cart, creating new cart if from different restaurant
  Future<void> addItem(Map<String, dynamic> item, String ownerId) async {
    final itemId = item['id'] as String? ?? '';

    // Get restaurant name and phone (try owner_id then restaurant id)
    String restaurantName = 'مطعم';
    String restaurantPhone = '';
    try {
      final restaurantInfo = await _getRestaurantInfo(ownerId);
      if (restaurantInfo != null) {
        restaurantName = restaurantInfo['name'] as String? ?? 'مطعم';
        restaurantPhone = (restaurantInfo['phone'] ?? '').toString().trim();
      }
    } catch (e) {
      restaurantName = 'مطعم';
    }

    // If cart doesn't exist for this restaurant, create it
    if (!restaurantCarts.containsKey(ownerId)) {
      restaurantCarts[ownerId] = <String, Map<String, dynamic>>{};
    }

    // Set as current cart if it's the first cart or if explicitly switching
    if (currentCartOwnerId.value == null ||
        currentCartOwnerId.value == ownerId) {
      currentCartOwnerId.value = ownerId;
    }

    final cart = restaurantCarts[ownerId]!;

    if (cart.containsKey(itemId)) {
      // Increase quantity (keep existing restaurantName/restaurantPhone if already set)
      final current = cart[itemId]!;
      final currentQuantity = current['quantity'] as int;
      cart[itemId] = {
        'item': item,
        'ownerId': ownerId,
        'restaurantName': current['restaurantName'] ?? restaurantName,
        'restaurantPhone': current['restaurantPhone'] ?? restaurantPhone,
        'quantity': currentQuantity + 1,
      };
    } else {
      // Add new item
      cart[itemId] = {
        'item': item,
        'ownerId': ownerId,
        'restaurantName': restaurantName,
        'restaurantPhone': restaurantPhone,
        'quantity': 1,
      };
    }

    restaurantCarts.refresh();
    update();
    _saveCartData();
  }

  @override
  void onInit() {
    super.onInit();
    _loadCartData();
  }

  void removeItem(String itemId, {String? ownerId}) {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) return;

    final cart = restaurantCarts[targetOwnerId];
    if (cart == null || !cart.containsKey(itemId)) return;

    final currentQuantity = cart[itemId]!['quantity'] as int;
    if (currentQuantity > 1) {
      // Decrease quantity
      final current = cart[itemId]!;
      cart[itemId] = {
        'item': current['item'],
        'quantity': currentQuantity - 1,
        'ownerId': current['ownerId'],
        'restaurantName': current['restaurantName'],
        'restaurantPhone': current['restaurantPhone'],
      };
    } else {
      // Remove item
      cart.remove(itemId);

      // If cart is empty, remove it
      if (cart.isEmpty) {
        restaurantCarts.remove(targetOwnerId);
        // Switch to another cart if available
        if (currentCartOwnerId.value == targetOwnerId) {
          if (restaurantCarts.isNotEmpty) {
            currentCartOwnerId.value = restaurantCarts.keys.first;
          } else {
            currentCartOwnerId.value = null;
          }
        }
      }
    }
    restaurantCarts.refresh();
    update();
    _saveCartData();
  }

  void clearCart({String? ownerId, bool clearAll = false}) {
    if (clearAll) {
      // Clear all carts
      restaurantCarts.clear();
      currentCartOwnerId.value = null;
      // Clear saved data
      _cacheHelper.removeData(key: _cartDataKey);
      _cacheHelper.removeData(key: _currentCartOwnerIdKey);
    } else {
      final targetOwnerId = ownerId ?? currentCartOwnerId.value;
      if (targetOwnerId != null) {
        restaurantCarts.remove(targetOwnerId);
        // Switch to another cart if available
        if (currentCartOwnerId.value == targetOwnerId) {
          if (restaurantCarts.isNotEmpty) {
            currentCartOwnerId.value = restaurantCarts.keys.first;
          } else {
            currentCartOwnerId.value = null;
          }
        }
      }
      // Save updated cart data
      _saveCartData();
    }
    restaurantCarts.refresh();
    update();
  }

  /// Save cart data to local storage
  Future<void> _saveCartData() async {
    try {
      // Convert cart data to JSON-serializable format
      final cartDataToSave = <String, Map<String, Map<String, dynamic>>>{};
      for (final entry in restaurantCarts.entries) {
        final ownerId = entry.key;
        final cart = entry.value;
        cartDataToSave[ownerId] = Map<String, Map<String, dynamic>>.from(cart);
      }

      // Convert to JSON string
      final cartJson = jsonEncode(cartDataToSave);
      await _cacheHelper.saveData(key: _cartDataKey, value: cartJson);

      // Save current cart owner ID
      if (currentCartOwnerId.value != null) {
        await _cacheHelper.saveData(
          key: _currentCartOwnerIdKey,
          value: currentCartOwnerId.value!,
        );
      } else {
        await _cacheHelper.removeData(key: _currentCartOwnerIdKey);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CartController] Error saving cart data: $e');
    }
  }

  /// Load cart data from local storage
  Future<void> _loadCartData() async {
    try {
      // Load cart data
      final cartJson = _cacheHelper.getDataString(key: _cartDataKey);
      if (cartJson != null && cartJson.isNotEmpty) {
        final cartData = jsonDecode(cartJson) as Map<String, dynamic>;

        // Restore cart data
        restaurantCarts.clear();
        for (final entry in cartData.entries) {
          final ownerId = entry.key;
          final cart = entry.value as Map<String, dynamic>;
          restaurantCarts[ownerId] = <String, Map<String, dynamic>>{};

          for (final itemEntry in cart.entries) {
            final itemId = itemEntry.key;
            final itemData = itemEntry.value as Map<String, dynamic>;
            restaurantCarts[ownerId]![itemId] = Map<String, dynamic>.from(
              itemData,
            );
          }
        }

        restaurantCarts.refresh();
        update();
      }

      // Load current cart owner ID
      final savedOwnerId = _cacheHelper.getDataString(
        key: _currentCartOwnerIdKey,
      );
      if (savedOwnerId != null && savedOwnerId.isNotEmpty) {
        // Only set if the cart still exists
        if (restaurantCarts.containsKey(savedOwnerId)) {
          currentCartOwnerId.value = savedOwnerId;
        } else if (restaurantCarts.isNotEmpty) {
          // If saved cart doesn't exist, use first available cart
          currentCartOwnerId.value = restaurantCarts.keys.first;
        }
      } else if (restaurantCarts.isNotEmpty) {
        // If no saved owner ID, use first available cart
        currentCartOwnerId.value = restaurantCarts.keys.first;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CartController] Error loading cart data: $e');
      // If there's an error, clear corrupted data
      await _cacheHelper.removeData(key: _cartDataKey);
      await _cacheHelper.removeData(key: _currentCartOwnerIdKey);
    }
  }

  int getItemQuantity(String itemId, {String? ownerId}) {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) return 0;
    final cart = restaurantCarts[targetOwnerId];
    return cart?[itemId]?['quantity'] as int? ?? 0;
  }

  int getTotalItems({String? ownerId}) {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) return 0;
    final cart = restaurantCarts[targetOwnerId];
    if (cart == null) return 0;
    return cart.values.fold(
      0,
      (sum, entry) => sum + (entry['quantity'] as int),
    );
  }

  double getTotalPrice({String? ownerId}) {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) return 0.0;
    final cart = restaurantCarts[targetOwnerId];
    if (cart == null) return 0.0;
    return cart.values.fold(0.0, (sum, entry) {
      final item = entry['item'] as Map<String, dynamic>;
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final quantity = entry['quantity'] as int;
      return sum + (price * quantity);
    });
  }

  List<Map<String, dynamic>> getCartItemsList({String? ownerId}) {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) return [];
    final cart = restaurantCarts[targetOwnerId];
    if (cart == null) return [];
    return cart.values.map((entry) {
      final item = entry['item'] as Map<String, dynamic>;
      final quantity = entry['quantity'] as int;
      final restaurantName = entry['restaurantName'] as String? ?? 'مطعم';
      final restaurantPhone = entry['restaurantPhone'] as String? ?? '';
      return {
        ...item,
        'cartQuantity': quantity,
        'ownerId': entry['ownerId'],
        'restaurantName': restaurantName,
        'restaurantPhone': restaurantPhone,
      };
    }).toList();
  }

  // Legacy getters for backward compatibility
  int get totalItems => getTotalItems();
  double get totalPrice => getTotalPrice();
  List<Map<String, dynamic>> get cartItemsList => getCartItemsList();

  /// Get all restaurant carts info (one map per restaurant; name and phone from stored cart)
  List<Map<String, dynamic>> get restaurantCartsInfo {
    return restaurantCarts.entries.map((entry) {
      final ownerId = entry.key;
      final cart = entry.value;
      final first = cart.values.isNotEmpty ? cart.values.first : null;
      final restaurantName = first?['restaurantName'] as String? ?? 'مطعم';
      final restaurantPhone = first?['restaurantPhone'] as String? ?? '';
      final itemCount = cart.values.fold(
        0,
        (sum, e) => sum + (e['quantity'] as int),
      );
      final total = cart.values.fold(0.0, (sum, e) {
        final item = e['item'] as Map<String, dynamic>;
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        final quantity = e['quantity'] as int;
        return sum + (price * quantity);
      });

      return {
        'ownerId': ownerId,
        'restaurantName': restaurantName,
        'restaurantPhone': restaurantPhone,
        'itemCount': itemCount,
        'totalPrice': total,
      };
    }).toList();
  }

  /// Switch to a different restaurant cart
  void switchCart(String ownerId) {
    if (restaurantCarts.containsKey(ownerId)) {
      currentCartOwnerId.value = ownerId;
      _saveCartData();
    }
  }

  /// Formats the order message with cart details for a specific restaurant
  String _formatOrderMessage({String? ownerId, String? notes}) {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) return '';

    final cart = restaurantCarts[targetOwnerId];
    if (cart == null || cart.isEmpty) return '';

    final restaurantName = cart.values.isNotEmpty
        ? cart.values.first['restaurantName'] as String? ?? 'مطعم'
        : 'مطعم';

    final buffer = StringBuffer();
    buffer.writeln('🍽️ طلب جديد من تطبيق مطاعمنا\n');
    buffer.writeln('🏪 المطعم: $restaurantName\n');
    buffer.writeln('📋 تفاصيل الطلب:\n');
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('📝 الملاحظات: $notes\n');
    }
    int itemNumber = 1;
    for (final entry in cart.values) {
      final item = entry['item'] as Map<String, dynamic>;
      final quantity = entry['quantity'] as int;
      final name = item['name'] ?? 'عنصر بدون اسم';
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final totalItemPrice = price * quantity;

      buffer.writeln('$itemNumber. $name');
      buffer.writeln('   الكمية: $quantity');
      buffer.writeln('   السعر: ${price.toStringAsFixed(2)} \$');
      buffer.writeln('   الإجمالي: ${totalItemPrice.toStringAsFixed(2)} \$');
      buffer.writeln();
      itemNumber++;
    }

    final total = getTotalPrice(ownerId: targetOwnerId);
    final itemCount = getTotalItems(ownerId: targetOwnerId);
    buffer.writeln('💰 الإجمالي الكلي: ${total.toStringAsFixed(2)} \$');
    buffer.writeln('\n📦 عدد العناصر: $itemCount');

    return buffer.toString();
  }

  /// Gets restaurant phone (from stored cart or by fetching; supports owner_id or restaurant id)
  Future<String?> _getRestaurantPhone(String ownerId) async {
    if (ownerId.isEmpty) return null;
    // Prefer phone stored in cart if available
    final cart = restaurantCarts[ownerId];
    if (cart != null && cart.isNotEmpty) {
      final first = cart.values.first;
      final stored = first['restaurantPhone'] as String?;
      if (stored != null && stored.isNotEmpty) return stored;
    }
    try {
      final restaurantInfo = await _getRestaurantInfo(ownerId);
      return restaurantInfo?['phone']?.toString();
    } catch (e) {
      print('[CartController] Error getting restaurant phone: $e');
      return null;
    }
  }

  /// Refresh restaurant name and phone for all carts (e.g. when opening cart page)
  Future<void> refreshRestaurantInfoForCarts() async {
    for (final ownerId in restaurantCarts.keys.toList()) {
      final info = await _getRestaurantInfo(ownerId);
      if (info == null) continue;
      final name = info['name'] as String? ?? 'مطعم';
      final phone = (info['phone'] ?? '').toString().trim();
      final cart = restaurantCarts[ownerId];
      if (cart == null) continue;
      for (final itemId in cart.keys.toList()) {
        final entry = cart[itemId]!;
        cart[itemId] = {
          ...entry,
          'restaurantName': name,
          'restaurantPhone': phone,
        };
      }
    }
    restaurantCarts.refresh();
    update();
    _saveCartData();
  }

  // /// Shows a dialog to select which WhatsApp app to use
  // Future<String?> showWhatsAppSelectionDialog(BuildContext context) async {
  //   // Show dialog to let user choose between WhatsApp and WhatsApp Business
  //   return await showDialog<String>(
  //     context: context,
  //     builder: (context) {
  //       final theme = Theme.of(context);
  //       final colorScheme = theme.colorScheme;

  //       return AlertDialog(
  //         title: Text('اختر تطبيق WhatsApp', style: theme.textTheme.titleLarge),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             ListTile(
  //               leading: Icon(Icons.chat, color: colorScheme.primary),
  //               title: Text('WhatsApp', style: theme.textTheme.titleMedium),
  //               onTap: () {
  //                 Navigator.of(context).pop('com.whatsapp');
  //               },
  //             ),
  //             ListTile(
  //               leading: Icon(Icons.business, color: colorScheme.primary),
  //               title: Text(
  //                 'WhatsApp Business',
  //                 style: theme.textTheme.titleMedium,
  //               ),
  //               onTap: () {
  //                 Navigator.of(context).pop('com.whatsapp.w4b');
  //               },
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: Text('إلغاء', style: TextStyle(color: colorScheme.error)),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  /// Sends order details via WhatsApp for a specific restaurant cart
  /// Returns true if message was sent successfully, false otherwise
  Future<bool> sendOrderViaWhatsApp({
    String? ownerId,
    String? notes,
    String? whatsAppPackage,
    BuildContext? context,
  }) async {
    final targetOwnerId = ownerId ?? currentCartOwnerId.value;
    if (targetOwnerId == null) {
      Get.snackbar(
        'السلة فارغة',
        'لا توجد عناصر في السلة',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final cart = restaurantCarts[targetOwnerId];
    if (cart == null || cart.isEmpty) {
      Get.snackbar(
        'السلة فارغة',
        'لا توجد عناصر في السلة',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final phone = await _getRestaurantPhone(targetOwnerId);
    if (phone == null || phone.isEmpty) {
      Get.snackbar(
        'خطأ',
        'لا يمكن العثور على رقم المطعم',

        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
      );
      return false;
    }

    // Format phone number (remove spaces, dashes, etc.)
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Ensure phone starts with country code (if not, assume Syria +963)
    String formattedPhone = cleanPhone;
    if (!formattedPhone.startsWith('+')) {
      // Remove leading 0 if present
      if (formattedPhone.startsWith('0')) {
        formattedPhone = formattedPhone.substring(1);
      }
      // Remove +963 if already present without +
      if (formattedPhone.startsWith('963')) {
        formattedPhone = '+$formattedPhone';
      } else {
        formattedPhone = '+963$formattedPhone';
      }
    }

    // If no WhatsApp package specified and context provided, show selection dialog
    String? selectedPackage = whatsAppPackage;
    if (selectedPackage == null && context != null) {
      //  selectedPackage = await showWhatsAppSelectionDialog(context);
      // If null, we'll still try to launch WhatsApp with default method (wa.me)
    }

    final message = _formatOrderMessage(ownerId: targetOwnerId, notes: notes);
    final encodedMessage = Uri.encodeComponent(message);

    // Remove + from phone number for WhatsApp URL
    final phoneForUrl = formattedPhone.replaceFirst('+', '');

    bool success = false;

    // Try multiple methods in order of preference
    try {
      // Method 1: Use whatsapp:// scheme (most reliable for Android)
      String whatsappUrl =
          'whatsapp://send?phone=$phoneForUrl&text=$encodedMessage';
      final uri = Uri.parse(whatsappUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        success = true;
      } else {
        // Method 2: Try https://wa.me/ (works on both Android and iOS)
        try {
          final waMeUrl = 'https://wa.me/$phoneForUrl?text=$encodedMessage';
          final waMeUri = Uri.parse(waMeUrl);
          final waMeLaunched = await launchUrl(
            waMeUri,
            mode: LaunchMode.externalApplication,
          );

          if (waMeLaunched) {
            success = true;
          } else {
            throw Exception('wa.me launch failed');
          }
        } catch (e2) {
          // Method 3: Try direct WhatsApp URL without encoding (fallback)
          try {
            final directUrl =
                'whatsapp://send?phone=$phoneForUrl&text=$encodedMessage';
            final directUri = Uri.parse(directUrl);
            final directLaunched = await launchUrl(
              directUri,
              mode: LaunchMode.platformDefault,
            );

            if (directLaunched) {
              success = true;
            } else {
              throw Exception('Direct launch failed');
            }
          } catch (e3) {
            // All methods failed
            // ignore: avoid_print
            print('[CartController] All WhatsApp launch methods failed');
            Get.snackbar(
              'خطأ',
              'لا يمكن فتح WhatsApp. تأكد من تثبيت التطبيق',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.error,
            );
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CartController] Error launching WhatsApp: $e');

      // Final fallback: Try wa.me URL
      try {
        final waMeUrl = 'https://wa.me/$phoneForUrl?text=$encodedMessage';
        final waMeUri = Uri.parse(waMeUrl);
        final waMeLaunched = await launchUrl(
          waMeUri,
          mode: LaunchMode.externalApplication,
        );

        if (waMeLaunched) {
          success = true;
        } else {
          Get.snackbar(
            'خطأ',
            'لا يمكن فتح WhatsApp. تأكد من تثبيت التطبيق',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.error,
          );
        }
      } catch (e2) {
        // ignore: avoid_print
        print('[CartController] Final fallback also failed: $e2');
        Get.snackbar(
          'خطأ',
          'حدث خطأ أثناء محاولة فتح WhatsApp. يرجى المحاولة مرة أخرى',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
        );
      }
    }

    if (success) {
      // Return success status so the UI can show a dialog
      return true;
    }
    return false;
  }
}
