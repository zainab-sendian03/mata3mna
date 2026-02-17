import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching admin dashboard statistics from Supabase
/// Shows system-wide statistics for all restaurants
class DashboardSupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================== COUNTS ==================

  /// Get total number of restaurants
  Future<int> getTotalRestaurants() async {
    try {
      final res = await _supabase.from('restaurants').select('id');

      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get total number of menu items
  Future<int> getTotalMenuItems() async {
    try {
      final res = await _supabase.from('menu_items').select('id');

      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get total number of unique categories
  Future<int> getTotalCategories() async {
    try {
      // Get categories from menu_categories table
      final categoriesResponse = await _supabase
          .from('menu_categories')
          .select('id');

      return (categoriesResponse as List).length;
    } catch (e) {
      print('[DashboardService] Error in getTotalCategories: $e');
      return 0;
    }
  }

  /// Get total number of users
  Future<int> getTotalUsers() async {
    try {
      final res = await _supabase.from('users').select('id');

      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ================== POPULAR / RECENT ==================

  /// Get most recent menu items
  Future<List<Map<String, dynamic>>> getPopularItems({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Items count grouped by category
  Future<Map<String, int>> getItemsByCategory() async {
    try {
      // menu_items has category_id only (no category column); resolve names from menu_categories
      final response = await _supabase
          .from('menu_items')
          .select('category_id');

      final Map<String, int> result = {};
      final Map<dynamic, String> categoryIdToName = {};

      for (final row in response) {
        final categoryId = row['category_id'];

        if (categoryId != null) {
          // If no category name, get it from category_id
          if (!categoryIdToName.containsKey(categoryId)) {
            try {
              // Get category name from menu_categories table
              dynamic id = categoryId;
              if (categoryId is String && categoryId.contains('-')) {
                // UUID
                id = categoryId;
              } else if (categoryId is String) {
                id = int.tryParse(categoryId) ?? categoryId;
              }

              final categoryDoc = await _supabase
                  .from('menu_categories')
                  .select('name')
                  .eq('id', id)
                  .maybeSingle();

              if (categoryDoc != null && categoryDoc['name'] != null) {
                categoryIdToName[categoryId] = categoryDoc['name'].toString();
              } else {
                categoryIdToName[categoryId] = 'غير مصنف';
              }
            } catch (e) {
              print('[DashboardService] Error getting category name: $e');
              categoryIdToName[categoryId] = 'غير مصنف';
            }
          }

          final name = categoryIdToName[categoryId] ?? 'غير مصنف';
          result[name] = (result[name] ?? 0) + 1;
        } else {
          // No category_id or category, use fallback
          result['غير مصنف'] = (result['غير مصنف'] ?? 0) + 1;
        }
      }

      return result;
    } catch (e) {
      print('[DashboardService] Error in getItemsByCategory: $e');
      return {};
    }
  }

  /// Get recent menu items (last 7 days)
  Future<List<Map<String, dynamic>>> getRecentItems() async {
    try {
      final weekAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final response = await _supabase
          .from('menu_items')
          .select()
          .gte('created_at', weekAgo)
          .order('created_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ================== RESTAURANTS ==================

  /// Restaurants count by status
  Future<Map<String, int>> getRestaurantsByStatus() async {
    try {
      final response = await _supabase.from('restaurants').select('status');

      final Map<String, int> result = {};
      for (final row in response) {
        final status = row['status'] ?? 'غير محدد';
        result[status] = (result[status] ?? 0) + 1;
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  /// Get recent restaurants (last 7 days)
  Future<List<Map<String, dynamic>>> getRecentRestaurants() async {
    try {
      final weekAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final response = await _supabase
          .from('restaurants')
          .select()
          .gte('created_at', weekAgo)
          .order('created_at', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
