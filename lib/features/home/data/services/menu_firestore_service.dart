import 'package:supabase_flutter/supabase_flutter.dart';

class MenuSupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _tableName = 'menu_items';
  static const String _categoriesTable = 'menu_categories';

  /// Resolve category_id to category name for each item (so UI shows category names, not just غير مصنف)
  Future<List<Map<String, dynamic>>> _resolveCategoryNames(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return items;
    final categoryIds = <dynamic>{};
    for (final item in items) {
      final cid = item['category_id'];
      if (cid != null) categoryIds.add(cid);
    }
    final idToName = <dynamic, String>{};
    for (final id in categoryIds) {
      try {
        final row = await _supabase
            .from(_categoriesTable)
            .select('name')
            .eq('id', id)
            .maybeSingle();
        final name = row?['name'] as String?;
        if (name != null && name.isNotEmpty) {
          idToName[id] = name;
          idToName[id.toString()] = name; // allow lookup by string category_id
        }
      } catch (_) {}
    }
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final row = Map<String, dynamic>.from(item);
      final name = row['category'] as String?;
      if (name != null && name.isNotEmpty) {
        result.add(row);
        continue;
      }
      final cid = row['category_id'];
      row['category'] = (cid != null ? (idToName[cid] ?? idToName[cid.toString()]) : null) ?? 'غير مصنف';
      result.add(row);
    }
    return result;
  }

  /// Get all menu items by restaurant_id (items are related to restaurant_id)
  Future<List<Map<String, dynamic>>> getMenuItemsByRestaurantId(String restaurantId) async {
    if (restaurantId.isEmpty) return [];
    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false);
    final items = List<Map<String, dynamic>>.from(response);
    return _resolveCategoryNames(items);
  }

  /// Stream menu items by restaurant_id (items are related to restaurant_id)
  Stream<List<Map<String, dynamic>>> getMenuItemsStreamByRestaurantId(String restaurantId) {
    if (restaurantId.isEmpty) return Stream.value([]);
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false)
        .asyncMap((event) {
          final list = List<Map<String, dynamic>>.from(event);
          return _resolveCategoryNames(list);
        });
  }

  /// Get all menu items for a specific owner (resolves owner_id -> restaurant_id)
  Future<List<Map<String, dynamic>>> getMenuItems(String ownerId) async {
    if (ownerId.isEmpty) return [];
    final restaurantId = await _getRestaurantId(ownerId);
    if (restaurantId == null || restaurantId.isEmpty) {
      print('[MenuSupabaseService] No restaurant found for ownerId: $ownerId');
      return [];
    }
    return getMenuItemsByRestaurantId(restaurantId);
  }

  /// Stream all menu items for a specific owner (resolves owner_id -> restaurant_id)
  Stream<List<Map<String, dynamic>>> getMenuItemsStream(String ownerId) {
    if (ownerId.isEmpty) return Stream.value([]);
    return Stream.fromFuture(_getRestaurantId(ownerId)).asyncExpand((restaurantId) {
      if (restaurantId == null || restaurantId.isEmpty) {
        print('[MenuSupabaseService] No restaurant found for ownerId: $ownerId');
        return Stream.value(<Map<String, dynamic>>[]);
      }
      return getMenuItemsStreamByRestaurantId(restaurantId);
    });
  }

  /// Helper method to get restaurant_id from owner_id or owner_email
  Future<String?> _getRestaurantId(String ownerId) async {
    try {
      final restaurant = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', ownerId)
          .maybeSingle();
      String? restaurantId = restaurant?['id'] as String?;
      
      // If not found by owner_id, try by owner_email
      if (restaurantId == null && ownerId.contains('@')) {
        final restaurantByEmail = await _supabase
            .from('restaurants')
            .select('id')
            .eq('owner_email', ownerId)
            .maybeSingle();
        restaurantId = restaurantByEmail?['id'] as String?;
      }
      
      return restaurantId;
    } catch (e) {
      print('[MenuSupabaseService] Error getting restaurant_id: $e');
      return null;
    }
  }

  /// Resolve category name to category_id. Uses existing categories (restaurant-specific or global with restaurant_id null) to avoid RLS insert issues.
  Future<dynamic> _getCategoryId(String restaurantId, String categoryName) async {
    final name = categoryName.isEmpty ? 'غير مصنف' : categoryName;

    // 1) Try restaurant-specific category
    var row = await _supabase
        .from(_categoriesTable)
        .select('id')
        .eq('name', name)
        .eq('restaurant_id', restaurantId)
        .maybeSingle();
    if (row != null && row['id'] != null) {
      final id = row['id'];
      return id is int ? id : (id is String ? id : id.toString());
    }

    // 2) Try global category (restaurant_id is null) — your DB has these
    final globalList = await _supabase
        .from(_categoriesTable)
        .select('id, restaurant_id')
        .eq('name', name);
    final globalRows = (globalList as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final globalMatch = globalRows.where((r) => r['restaurant_id'] == null).toList();
    if (globalMatch.isNotEmpty && globalMatch.first['id'] != null) {
      row = globalMatch.first;
    }
    if (row != null && row['id'] != null) {
      final id = row['id'];
      return id is int ? id : (id is String ? id : id.toString());
    }

    // 3) Fallback: try first category for this restaurant (e.g. "غير مصنف" from getCategories)
    if (name == 'غير مصنف') {
      final any = await _supabase
          .from(_categoriesTable)
          .select('id')
          .eq('name', 'غير مصنف')
          .limit(1)
          .maybeSingle();
      if (any != null && any['id'] != null) {
        final id = any['id'];
        return id is int ? id : (id is String ? id : id.toString());
      }
    }

    // 4) Last resort: try to insert (may fail with RLS)
    try {
      final inserted = await _supabase
          .from(_categoriesTable)
          .insert({
            'name': name,
            'restaurant_id': restaurantId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id');
      if (inserted.isNotEmpty && inserted[0]['id'] != null) {
        final id = inserted[0]['id'];
        return id is int ? id : (id is String ? id : id.toString());
      }
    } catch (_) {}

    // 5) Use any "غير مصنف" id from DB (first row)
    final fallback = await _supabase
        .from(_categoriesTable)
        .select('id')
        .limit(1)
        .maybeSingle();
    if (fallback != null && fallback['id'] != null) {
      final id = fallback['id'];
      return id is int ? id : (id is String ? id : id.toString());
    }
    throw Exception('لم يتم العثور على فئة ولا يمكن إنشاؤها');
  }

  /// Add a new menu item (schema uses category_id, not category)
  Future<String> addMenuItem({
    required String name,
    required String category,
    required String price,
    String? description,
    String? imageUrl,
    String? restaurantName,
    required String ownerId,
  }) async {
    // Get restaurant_id from restaurants table
    String? restaurantId;
    try {
      final restaurant = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', ownerId)
          .maybeSingle();
      restaurantId = restaurant?['id'] as String?;
      
      // If not found by owner_id, try by owner_email
      if (restaurantId == null && ownerId.contains('@')) {
        final restaurantByEmail = await _supabase
            .from('restaurants')
            .select('id')
            .eq('owner_email', ownerId)
            .maybeSingle();
        restaurantId = restaurantByEmail?['id'] as String?;
      }
      
      if (restaurantId == null || restaurantId.isEmpty) {
        throw Exception('لم يتم العثور على مطعم للمالك المحدد');
      }
    } catch (e) {
      print('[MenuSupabaseService] Error getting restaurant_id: $e');
      rethrow;
    }

    final categoryId = await _getCategoryId(restaurantId, category);
    final payload = <String, dynamic>{
      'name': name,
      'category_id': categoryId,
      'price': price,
      'description': description ?? '',
      'restaurant_id': restaurantId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['image'] = imageUrl;
    }

    final response = await _supabase.from(_tableName).insert(payload).select();
    return response[0]['id'] as String;
  }

  /// Get all menu items (e.g. for customer view search). Resolves category names.
  Future<List<Map<String, dynamic>>> getAllMenuItems() async {
    final data = await _supabase.from('menu_items').select();
    final items = (data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
    return _resolveCategoryNames(items);
  }

  /// Stream all menu items (e.g. for customer view). Resolves category names so search by category works.
  Stream<List<Map<String, dynamic>>> getAllMenuItemsStream() {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .asyncMap((event) {
          final list = List<Map<String, dynamic>>.from(event);
          return _resolveCategoryNames(list);
        });
  }

  /// Update an existing menu item (schema uses category_id, not category)
  Future<void> updateMenuItem({
    required String itemId,
    required String name,
    required String category,
    required String price,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    // Get restaurant_id from current item to resolve category_id
    final current = await _supabase
        .from(_tableName)
        .select('restaurant_id')
        .eq('id', itemId)
        .maybeSingle();
    final restaurantId = current?['restaurant_id'] as String?;
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('لم يتم العثور على العنصر أو مطعمه');
    }
    final categoryId = await _getCategoryId(restaurantId, category);
    final payload = <String, dynamic>{
      'name': name,
      'category_id': categoryId,
      'price': price,
      'description': description ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (imageUrl != null) payload['image'] = imageUrl;
    await _supabase
        .from(_tableName)
        .update(payload)
        .eq('id', itemId)
        .select();
  }

  /// Delete a menu item
  Future<void> deleteMenuItem(String itemId) async {
    await _supabase.from(_tableName).delete().eq('id', itemId).select();
  }

  /// Delete all menu items for a specific owner
  Future<void> deleteAllMenuItemsByOwnerId(String ownerId) async {
    if (ownerId.isEmpty) return;

    // Get restaurant_id from restaurants table
    String? restaurantId;
    try {
      final restaurant = await _supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', ownerId)
          .maybeSingle();
      restaurantId = restaurant?['id'] as String?;
      
      // If not found by owner_id, try by owner_email
      if (restaurantId == null && ownerId.contains('@')) {
        final restaurantByEmail = await _supabase
            .from('restaurants')
            .select('id')
            .eq('owner_email', ownerId)
            .maybeSingle();
        restaurantId = restaurantByEmail?['id'] as String?;
      }
    } catch (e) {
      print('[MenuSupabaseService] Error getting restaurant_id for delete: $e');
      return;
    }

    if (restaurantId == null || restaurantId.isEmpty) {
      print('[MenuSupabaseService] No restaurant found for ownerId: $ownerId');
      return;
    }

    await _supabase.from(_tableName).delete().eq('restaurant_id', restaurantId).select();
  }

  /// Get a single menu item by ID
  Future<Map<String, dynamic>?> getMenuItemById(String itemId) async {
    final response = await _supabase.from(_tableName).select().eq('id', itemId);

    if (response.isEmpty) return null;
    return Map<String, dynamic>.from(response[0]);
  }
}
