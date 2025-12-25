import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';

/// Service for managing menu items in Firestore
class MenuFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RestaurantFirestoreService? _restaurantService;

  MenuFirestoreService({RestaurantFirestoreService? restaurantService})
    : _restaurantService = restaurantService;

  /// Collection name for menu items
  static const String _collectionName = 'menuItems';

  /// Get all menu items for the current restaurant owner
  Stream<List<Map<String, dynamic>>> getMenuItemsStream(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collectionName)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            final data = doc.data();
            // Convert Timestamp to DateTime if present
            final item = <String, dynamic>{'id': doc.id, ...data};
            // Handle Timestamp fields
            if (item['createdAt'] != null && item['createdAt'] is Timestamp) {
              item['createdAt'] = (item['createdAt'] as Timestamp)
                  .toDate()
                  .toString();
            }
            if (item['updatedAt'] != null && item['updatedAt'] is Timestamp) {
              item['updatedAt'] = (item['updatedAt'] as Timestamp)
                  .toDate()
                  .toString();
            }
            return item;
          }).toList();
          // Sort by createdAt if available
          items.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return items;
        });
  }

  /// Get all menu items from all restaurants (for customer view)
  /// Includes restaurant location data (governorate, city) for search
  Stream<List<Map<String, dynamic>>> getAllMenuItemsStream() {
    return _firestore.collection(_collectionName).snapshots().asyncMap((
      snapshot,
    ) async {
      final items = <Map<String, dynamic>>[];

      // Process items and enrich with restaurant location data
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final item = <String, dynamic>{'id': doc.id, ...data};

        // Handle Timestamp fields
        if (item['createdAt'] != null && item['createdAt'] is Timestamp) {
          item['createdAt'] = (item['createdAt'] as Timestamp)
              .toDate()
              .toString();
        }
        if (item['updatedAt'] != null && item['updatedAt'] is Timestamp) {
          item['updatedAt'] = (item['updatedAt'] as Timestamp)
              .toDate()
              .toString();
        }

        // Enrich with restaurant location if available
        final ownerId = item['ownerId'] as String?;
        final restaurantService = _restaurantService;
        if (ownerId != null &&
            ownerId.isNotEmpty &&
            restaurantService != null) {
          try {
            final restaurantInfo = await restaurantService
                .getRestaurantInfoByOwnerId(ownerId);
            if (restaurantInfo != null) {
              item['governorate'] = restaurantInfo['governorate'] ?? '';
              item['city'] = restaurantInfo['city'] ?? '';
            } else {
              item['governorate'] = '';
              item['city'] = '';
            }
          } catch (e) {
            // If restaurant info fetch fails, continue without location data
            item['governorate'] = '';
            item['city'] = '';
          }
        } else {
          item['governorate'] = '';
          item['city'] = '';
        }

        items.add(item);
      }

      // Sort by createdAt if available
      items.sort((a, b) {
        final aTime = a['createdAt']?.toString() ?? '';
        final bTime = b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });

      return items;
    });
  }

  /// Add a new menu item
  Future<String> addMenuItem({
    required String name,
    required String category,
    required String price,
    String? description,
    String? imageUrl,
    String? restaurantName,
    String? ownerId,
  }) async {
    try {
      final currentUserId = ownerId ?? _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final menuItemData = {
        'name': name,
        'category': category,
        'price': price,
        'description': description ?? '',
        'image': imageUrl ?? '',
        'restaurantName': restaurantName ?? '',
        'ownerId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(_collectionName)
          .add(menuItemData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add menu item: $e');
    }
  }

  /// Update an existing menu item
  Future<void> updateMenuItem({
    required String itemId,
    required String name,
    required String category,
    required String price,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      final updateData = {
        'name': name,
        'category': category,
        'price': price,
        'description': description ?? '',
        'image': imageUrl ?? '',
        'restaurantName': restaurantName ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_collectionName)
          .doc(itemId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// Delete a menu item
  Future<void> deleteMenuItem(String itemId) async {
    try {
      await _firestore.collection(_collectionName).doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete menu item: $e');
    }
  }

  /// Delete all menu items for a specific restaurant (by ownerId)
  Future<void> deleteAllMenuItemsByOwnerId(String ownerId) async {
    try {
      if (ownerId.isEmpty) {
        throw Exception('Owner ID cannot be empty');
      }

      // Get all menu items for this owner
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .get();

      // Delete all items in batch
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete menu items: $e');
    }
  }

  /// Get a single menu item by ID
  Future<Map<String, dynamic>?> getMenuItemById(String itemId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(itemId)
          .get();

      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get menu item: $e');
    }
  }
}
