import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';

/// Service responsible for persisting restaurant profiles in Firestore.
class RestaurantFirestoreService {
  RestaurantFirestoreService({
    FirebaseFirestore? firestore,
    MenuFirestoreService? menuService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _menuService = menuService;

  final FirebaseFirestore _firestore;
  final MenuFirestoreService? _menuService;

  /// Get MenuFirestoreService from GetX if not provided in constructor
  MenuFirestoreService? get _menuServiceOrFind {
    if (_menuService != null) return _menuService;
    try {
      return Get.find<MenuFirestoreService>();
    } catch (_) {
      return null;
    }
  }

  static const String _collectionName = 'restaurants';

  /// Creates or updates the restaurant profile for the given owner/email.
  Future<void> saveRestaurantInfo({
    required String ownerId,
    required String ownerEmail,
    required String name,
    required String phone,
    required String governorate,
    required String city,
    required bool infoCompleted,
    String? description,
    String? logoPath,
  }) async {
    final emailKey = _normalizedKey(ownerEmail);
    if (emailKey.isEmpty) {
      throw Exception('البريد الإلكتروني غير صالح لحفظ بيانات المطعم');
    }

    final payload = <String, dynamic>{
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'name': name,
      'phone': phone,
      'governorate': governorate,
      'city': city,
      'description': description ?? '',
      'logoPath': logoPath ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'infoCompleted': infoCompleted,
    };

    final emailDoc = _firestore.collection(_collectionName).doc(emailKey);

    // Retry logic for transient errors
    int maxRetries = 3;
    int retryCount = 0;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      try {
        final emailSnapshot = await emailDoc.get();
        if (!emailSnapshot.exists) {
          payload['createdAt'] = FieldValue.serverTimestamp();
          payload['status'] = 'active';
        }
        await emailDoc.set(payload, SetOptions(merge: true));
        success = true;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable' && retryCount < maxRetries - 1) {
          // Transient error - retry with exponential backoff
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        } else {
          // Permanent error or max retries reached
          throw Exception(
            'فشل حفظ معلومات المطعم: ${e.message ?? e.code}\n'
            'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
          );
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        } else {
          rethrow;
        }
      }
    }

    // Remove duplicate document if it exists under ownerId (to prevent duplicates)
    // Only keep the email-keyed document as the primary source
    if (ownerId.isNotEmpty && ownerId != emailKey) {
      final ownerIdDoc = _firestore.collection(_collectionName).doc(ownerId);
      final ownerIdSnapshot = await ownerIdDoc.get();

      // If a document exists under ownerId, delete it to prevent duplicates
      // The email-keyed document is now the primary source
      if (ownerIdSnapshot.exists) {
        await ownerIdDoc.delete();
      }
    }
  }

  /// Gets restaurant info completion status using ownerId and/or email.
  /// Prioritizes field-based queries (for admin-created restaurants with random document IDs)
  /// before checking document ID-based lookups (for owner-created restaurants).
  Future<bool> getRestaurantInfoCompleted({
    String? ownerId,
    String? ownerEmail,
  }) async {
    try {
      print(
        '[RestaurantFirestoreService] getRestaurantInfoCompleted called with ownerId: $ownerId, ownerEmail: $ownerEmail',
      );

      // First, search by ownerId field (for admin-created restaurants with random document IDs)
      // This is prioritized because admin-created restaurants use .add() which generates random IDs
      if (ownerId != null && ownerId.isNotEmpty) {
        print('[RestaurantFirestoreService] Searching by ownerId: $ownerId');
        final byOwnerIdQuery = await _firestore
            .collection(_collectionName)
            .where('ownerId', isEqualTo: ownerId)
            .limit(1)
            .get();

        print(
          '[RestaurantFirestoreService] Query by ownerId returned ${byOwnerIdQuery.docs.length} documents',
        );

        if (byOwnerIdQuery.docs.isNotEmpty) {
          final data = byOwnerIdQuery.docs.first.data();
          print(
            '[RestaurantFirestoreService] Found restaurant by ownerId. Document ID: ${byOwnerIdQuery.docs.first.id}',
          );
          print('[RestaurantFirestoreService] Restaurant data: $data');

          if (data.containsKey('infoCompleted')) {
            final isCompleted = data['infoCompleted'] as bool? ?? false;
            print('[RestaurantFirestoreService] infoCompleted: $isCompleted');
            return isCompleted;
          } else {
            print(
              '[RestaurantFirestoreService] WARNING: Restaurant found but infoCompleted field is missing',
            );
          }
        }
      }

      // Also search by ownerEmail field (for admin-created restaurants)
      if (ownerEmail != null && ownerEmail.isNotEmpty) {
        final trimmedEmail = ownerEmail.trim();
        print(
          '[RestaurantFirestoreService] Searching by ownerEmail: $trimmedEmail',
        );
        final byEmailQuery = await _firestore
            .collection(_collectionName)
            .where('ownerEmail', isEqualTo: trimmedEmail)
            .limit(1)
            .get();

        print(
          '[RestaurantFirestoreService] Query by ownerEmail returned ${byEmailQuery.docs.length} documents',
        );

        if (byEmailQuery.docs.isNotEmpty) {
          final data = byEmailQuery.docs.first.data();
          print(
            '[RestaurantFirestoreService] Found restaurant by ownerEmail. Document ID: ${byEmailQuery.docs.first.id}',
          );
          print('[RestaurantFirestoreService] Restaurant data: $data');

          if (data.containsKey('infoCompleted')) {
            final isCompleted = data['infoCompleted'] as bool? ?? false;
            print('[RestaurantFirestoreService] infoCompleted: $isCompleted');
            return isCompleted;
          } else {
            print(
              '[RestaurantFirestoreService] WARNING: Restaurant found but infoCompleted field is missing',
            );
          }
        }
      }

      // Fallback: check by document ID (legacy format for owner-created restaurants)
      if (ownerId != null && ownerId.isNotEmpty) {
        final legacyDoc = await _firestore
            .collection(_collectionName)
            .doc(ownerId)
            .get();
        if (legacyDoc.exists) {
          final data = legacyDoc.data();
          if (data != null && data.containsKey('infoCompleted')) {
            return data['infoCompleted'] as bool? ?? false;
          }
        }
      }

      // Fallback: check by normalized email as document ID
      final normalizedEmail = _normalizedKey(ownerEmail);
      if (normalizedEmail.isNotEmpty) {
        final emailDoc = await _firestore
            .collection(_collectionName)
            .doc(normalizedEmail)
            .get();
        if (emailDoc.exists) {
          final data = emailDoc.data();
          if (data != null && data.containsKey('infoCompleted')) {
            return data['infoCompleted'] as bool? ?? false;
          }
        }
      }

      print(
        '[RestaurantFirestoreService] No restaurant found. Returning false.',
      );
      return false;
    } catch (e) {
      print(
        '[RestaurantFirestoreService] ERROR getting restaurant info completed: $e',
      );
      print('[RestaurantFirestoreService] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Get restaurant info by ownerId (for merging with menu items)
  /// Searches by document ID first, then by ownerId field in all documents
  /// Also searches by ownerEmail as fallback for admin-created restaurants
  Future<Map<String, dynamic>?> getRestaurantInfoByOwnerId(
    String ownerId, {
    String? ownerEmail,
  }) async {
    try {
      if (ownerId.isEmpty) return null;

      print(
        '[RestaurantFirestoreService] getRestaurantInfoByOwnerId called with ownerId: $ownerId, ownerEmail: $ownerEmail',
      );

      // Try ownerId as document ID first (for owner-created restaurants)
      final ownerDoc = await _firestore
          .collection(_collectionName)
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        print('[RestaurantFirestoreService] Found restaurant by document ID');
        return ownerDoc.data();
      }

      // If not found by document ID, search by ownerId field
      // This handles cases where restaurant is stored under email key or admin-created with random ID
      print('[RestaurantFirestoreService] Searching by ownerId field...');
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print(
          '[RestaurantFirestoreService] Found restaurant by ownerId field. Document ID: ${querySnapshot.docs.first.id}',
        );
        final data = querySnapshot.docs.first.data();
        print('[RestaurantFirestoreService] Restaurant data: $data');
        return data;
      }

      // Also search by ownerEmail field as fallback (for admin-created restaurants)
      if (ownerEmail != null && ownerEmail.isNotEmpty) {
        final trimmedEmail = ownerEmail.trim();
        print(
          '[RestaurantFirestoreService] Searching by ownerEmail field: $trimmedEmail',
        );
        final emailQuerySnapshot = await _firestore
            .collection(_collectionName)
            .where('ownerEmail', isEqualTo: trimmedEmail)
            .limit(1)
            .get();

        if (emailQuerySnapshot.docs.isNotEmpty) {
          print(
            '[RestaurantFirestoreService] Found restaurant by ownerEmail field. Document ID: ${emailQuerySnapshot.docs.first.id}',
          );
          final data = emailQuerySnapshot.docs.first.data();
          print('[RestaurantFirestoreService] Restaurant data: $data');
          return data;
        }
      }

      print(
        '[RestaurantFirestoreService] No restaurant found for ownerId: $ownerId',
      );
      return null;
    } catch (e) {
      print(
        '[RestaurantFirestoreService] ERROR getting restaurant by ownerId: $e',
      );
      return null;
    }
  }

  /// Search restaurants by name and optionally by food type
  /// Returns a stream of restaurant documents matching the search criteria
  Stream<List<Map<String, dynamic>>> searchRestaurants({
    required String restaurantName,
    String? foodType,
  }) {
    // Normalize search query
    final normalizedName = restaurantName.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collectionName)
        .where('infoCompleted', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final restaurants = <Map<String, dynamic>>[];
          final seenOwnerIds = <String>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final ownerId = (data['ownerId'] ?? '').toString();
            final name = (data['name'] ?? '').toString().toLowerCase();

            // Skip if we've already seen this ownerId (deduplicate)
            if (ownerId.isNotEmpty && seenOwnerIds.contains(ownerId)) {
              continue;
            }

            // Filter by restaurant name
            if (name.contains(normalizedName)) {
              restaurants.add({'id': doc.id, 'ownerId': ownerId, ...data});
              if (ownerId.isNotEmpty) {
                seenOwnerIds.add(ownerId);
              }
            }
          }

          return restaurants;
        });
  }

  /// Get all restaurants (for listing)
  /// Deduplicates restaurants by ownerId since restaurants may be stored under both email and ownerId
  Stream<List<Map<String, dynamic>>> getAllRestaurants() {
    return _firestore
        .collection(_collectionName)
        .where('infoCompleted', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final restaurants = <Map<String, dynamic>>[];
          final seenOwnerIds = <String>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final ownerId = (data['ownerId'] ?? '').toString();

            // Skip if we've already seen this ownerId (deduplicate)
            if (ownerId.isNotEmpty && seenOwnerIds.contains(ownerId)) {
              continue;
            }

            restaurants.add({'id': doc.id, 'ownerId': ownerId, ...data});
            if (ownerId.isNotEmpty) {
              seenOwnerIds.add(ownerId);
            }
          }

          return restaurants;
        });
  }

  /// Delete a restaurant and all its associated menu items
  /// [ownerId] - The owner ID of the restaurant to delete
  /// [ownerEmail] - The owner email (used to find the document key)
  /// [deleteMenuItems] - Whether to also delete all menu items (default: true)
  Future<void> deleteRestaurant({
    required String ownerId,
    required String ownerEmail,
    bool deleteMenuItems = true,
  }) async {
    try {
      final emailKey = _normalizedKey(ownerEmail);

      // Delete menu items first if requested
      final menuService = _menuServiceOrFind;
      if (deleteMenuItems && menuService != null) {
        try {
          await menuService.deleteAllMenuItemsByOwnerId(ownerId);
        } catch (e) {
          // Log error but continue with restaurant deletion
          // ignore: avoid_print
          print('[RestaurantFirestoreService] Error deleting menu items: $e');
        }
      }

      // Delete restaurant document(s)
      // Try to delete by email key (primary)
      if (emailKey.isNotEmpty) {
        final emailDoc = _firestore.collection(_collectionName).doc(emailKey);
        final emailSnapshot = await emailDoc.get();
        if (emailSnapshot.exists) {
          await emailDoc.delete();
        }
      }

      // Also try to delete by ownerId key (for backward compatibility)
      if (ownerId.isNotEmpty && ownerId != emailKey) {
        final ownerIdDoc = _firestore.collection(_collectionName).doc(ownerId);
        final ownerIdSnapshot = await ownerIdDoc.get();
        if (ownerIdSnapshot.exists) {
          await ownerIdDoc.delete();
        }
      }

      // Also delete any document where ownerId field matches (fallback)
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete restaurant: $e');
    }
  }

  String _normalizedKey(String? value) => value?.trim().toLowerCase() ?? '';
}
