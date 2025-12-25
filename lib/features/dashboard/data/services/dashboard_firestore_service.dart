import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for fetching admin dashboard statistics from Firestore
/// Shows system-wide statistics for all restaurants
class DashboardFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardFirestoreService();

  /// Get total number of restaurants in the system
  Future<int> getTotalRestaurants() async {
    try {
      final snapshot = await _firestore.collection('restaurants').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get total number of menu items across all restaurants
  Future<int> getTotalMenuItems() async {
    try {
      final snapshot = await _firestore.collection('menuItems').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get total number of categories across all restaurants
  Future<int> getTotalCategories() async {
    try {
      final snapshot = await _firestore.collection('menuItems').get();

      final categories = <String>{};
      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }
      return categories.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get total number of users
  Future<int> getTotalUsers() async {
    try {
      final snapshot = await _firestore.collection('users').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get most popular items across all restaurants
  Future<List<Map<String, dynamic>>> getPopularItems({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('menuItems')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get items by category distribution across all restaurants
  Future<Map<String, int>> getItemsByCategory() async {
    try {
      final snapshot = await _firestore.collection('menuItems').get();

      final categoryCount = <String, int>{};
      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'غير مصنف';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
      return categoryCount;
    } catch (e) {
      return {};
    }
  }

  /// Get recent items across all restaurants (last 7 days)
  Future<List<Map<String, dynamic>>> getRecentItems() async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _firestore
          .collection('menuItems')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get restaurants by status distribution
  Future<Map<String, int>> getRestaurantsByStatus() async {
    try {
      final snapshot = await _firestore.collection('restaurants').get();

      final statusCount = <String, int>{};
      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'غير محدد';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }
      return statusCount;
    } catch (e) {
      return {};
    }
  }

  /// Get recent restaurants (last 7 days)
  Future<List<Map<String, dynamic>>> getRecentRestaurants() async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _firestore
          .collection('restaurants')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
