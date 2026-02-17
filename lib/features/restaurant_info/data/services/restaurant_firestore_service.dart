import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantSupabaseService {
  final SupabaseClient _supabase;

  RestaurantSupabaseService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const String _citiesTable = 'cities';

  /// Normalize restaurant map from Supabase (snake_case) to app convention (camelCase)
  static Map<String, dynamic> _normalizeRestaurantMap(Map<String, dynamic> r) {
    final out = Map<String, dynamic>.from(r);
    if (r.containsKey('owner_id') && !out.containsKey('ownerId')) {
      out['ownerId'] = r['owner_id'];
    }
    if (r.containsKey('info_completed') && !out.containsKey('infoCompleted')) {
      out['infoCompleted'] = r['info_completed'];
    }
    if (r.containsKey('logo_path') && !out.containsKey('logoPath')) {
      out['logoPath'] = r['logo_path'];
    }
    if (r.containsKey('owner_email') && !out.containsKey('ownerEmail')) {
      out['ownerEmail'] = r['owner_email'];
    }
    if (r.containsKey('city_id') && !out.containsKey('cityId')) {
      out['cityId'] = r['city_id'];
    }
    return out;
  }

  /// Get city ID from cities table by city name and governorate
  Future<String?> getCityId(String governorate, String cityName) async {
    try {
      final cityResponse = await _supabase
          .from(_citiesTable)
          .select('id')
          .eq('governorate', governorate.trim())
          .eq('name', cityName.trim())
          .maybeSingle();

      if (cityResponse != null) {
        return cityResponse['id'] as String?;
      }
      return null;
    } catch (e) {
      print('[RestaurantSupabaseService] Error getting city ID: $e');
      return null;
    }
  }

  /// Ensures the owner has a row in users table (required for restaurants.owner_id FK)
  Future<void> _ensureUsersRowExists(String ownerId, String ownerEmail) async {
    final existingById =
        await _supabase.from('users').select('id').eq('id', ownerId).maybeSingle();
    if (existingById != null) return;

    try {
      await _supabase.from('users').upsert({
        'id': ownerId,
        'email': ownerEmail,
        'role': 'owner',
        'password': 'supabase_auth',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
    } on PostgrestException catch (e) {
      if (e.code == '23505' &&
          (e.message.contains('users_email_key') ||
              e.message.contains('duplicate key'))) {
        // User exists with same email - no action needed (FK will be satisfied)
        return;
      }
      rethrow;
    }
  }

  // حفظ أو تحديث بيانات المطعم
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
    await _ensureUsersRowExists(ownerId, ownerEmail);

    // Get city_id from cities table
    String? cityId;
    try {
      cityId = await getCityId(governorate, city);
      if (cityId == null) {
        throw Exception(
          'المدينة "$city" غير موجودة في قاعدة البيانات للمحافظة "$governorate".\n\n'
          'يرجى التأكد من أن المدينة موجودة في جدول cities.',
        );
      }
    } catch (e) {
      print('[RestaurantSupabaseService] Error getting city ID: $e');
      rethrow;
    }

    // تحقق إذا المطعم موجود
    final existing = await _supabase
        .from('restaurants')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle(); // هاد بديل execute + single

    final payload = <String, dynamic>{
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'name': name,
      'phone': phone,
      'governorate': governorate,
      'city_id': cityId,
      'description': description ?? '',
      'logo_path': logoPath ?? '',
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing != null) {
      // المطعم موجود: تحديثه بالقيمة الممررة (ستكون true عندما يكمل المستخدم المعلومات)
      payload['info_completed'] = infoCompleted;
      final restaurantId = existing['id'];
      await _supabase
          .from('restaurants')
          .update(payload)
          .eq('id', restaurantId)
          .select(); // select() عشان تجيب النتيجة بعد التحديث
    } else {
      // المطعم غير موجود: إنشاء جديد - استخدم القيمة الممررة (true عند إكمال النموذج)
      payload['info_completed'] = infoCompleted;
      payload['created_at'] = DateTime.now().toIso8601String();
      await _supabase.from('restaurants').insert(payload).select();
    }
  }

  // جلب مطعم حسب ownerId
  Future<Map<String, dynamic>?> getRestaurantByOwnerId(String ownerId) async {
    try {
      // Try with JOIN first
      final response = await _supabase
          .from('restaurants')
          .select('*, cities!city_id(name)')
          .eq('owner_id', ownerId)
          .maybeSingle();
      
      if (response != null) {
        // Extract city name from the joined cities table
        final cityData = response['cities'];
        if (cityData != null && cityData is Map) {
          response['city'] = cityData['name'] as String? ?? '';
        } else if (cityData != null && cityData is List && cityData.isNotEmpty) {
          response['city'] = (cityData[0] as Map)['name'] as String? ?? '';
        }
        response.remove('cities');
      }
      return response != null ? _normalizeRestaurantMap(response) : null;
    } catch (e) {
      // If JOIN fails, try without JOIN and fetch city separately
      print('[RestaurantSupabaseService] JOIN failed, fetching city separately: $e');
      final response = await _supabase
          .from('restaurants')
          .select()
          .eq('owner_id', ownerId)
          .maybeSingle();
      
      if (response != null && response['city_id'] != null) {
        try {
          final cityId = response['city_id'] as String;
          final cityResponse = await _supabase
              .from('cities')
              .select('name')
              .eq('id', cityId)
              .maybeSingle();
          if (cityResponse != null) {
            response['city'] = cityResponse['name'] as String? ?? '';
          }
        } catch (cityError) {
          print('[RestaurantSupabaseService] Error fetching city: $cityError');
        }
      }
      return response != null ? _normalizeRestaurantMap(response) : null;
    }
  }

  /// Get restaurant by its id (when owner_id is null, cart may use restaurant id as key)
  Future<Map<String, dynamic>?> getRestaurantById(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await _supabase
          .from('restaurants')
          .select('*, cities!city_id(name)')
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        final cityData = response['cities'];
        if (cityData != null && cityData is Map) {
          response['city'] = cityData['name'] as String? ?? '';
        } else if (cityData != null && cityData is List && cityData.isNotEmpty) {
          response['city'] = (cityData[0] as Map)['name'] as String? ?? '';
        }
        response.remove('cities');
      }
      return response != null ? _normalizeRestaurantMap(response) : null;
    } catch (e) {
      print('[RestaurantSupabaseService] getRestaurantById failed: $e');
      final response = await _supabase
          .from('restaurants')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null && response['city_id'] != null) {
        try {
          final cityId = response['city_id'] as String;
          final cityResponse = await _supabase
              .from('cities')
              .select('name')
              .eq('id', cityId)
              .maybeSingle();
          if (cityResponse != null) {
            response['city'] = cityResponse['name'] as String? ?? '';
          }
        } catch (cityError) {
          print('[RestaurantSupabaseService] Error fetching city: $cityError');
        }
      }
      return response != null ? _normalizeRestaurantMap(response) : null;
    }
  }

  // البحث عن المطاعم
  Future<List<Map<String, dynamic>>> searchRestaurants(String nameQuery) async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('*, cities!city_id(name)')
          .ilike('name', '%$nameQuery%')
          .eq('info_completed', true)
          .eq('status', 'active');

      final restaurants = (response as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final restaurant in restaurants) {
        final cityData = restaurant['cities'];
        if (cityData != null && cityData is Map) {
          restaurant['city'] = cityData['name'] as String? ?? '';
        } else if (cityData != null && cityData is List && cityData.isNotEmpty) {
          restaurant['city'] = (cityData[0] as Map)['name'] as String? ?? '';
        }
        restaurant.remove('cities');
      }
      return restaurants.map((r) => _normalizeRestaurantMap(r)).toList();
    } catch (e) {
      print('[RestaurantSupabaseService] JOIN failed in searchRestaurants: $e');
      final response = await _supabase
          .from('restaurants')
          .select()
          .ilike('name', '%$nameQuery%')
          .eq('info_completed', true)
          .eq('status', 'active');

      final restaurants = (response as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final restaurant in restaurants) {
        if (restaurant['city_id'] != null) {
          try {
            final cityId = restaurant['city_id'] as String;
            final cityResponse = await _supabase
                .from('cities')
                .select('name')
                .eq('id', cityId)
                .maybeSingle();
            if (cityResponse != null) {
              restaurant['city'] = cityResponse['name'] as String? ?? '';
            }
          } catch (cityError) {
            print('[RestaurantSupabaseService] Error fetching city: $cityError');
          }
        }
      }
      return restaurants.map((r) => _normalizeRestaurantMap(r)).toList();
    }
  }

  /// جلب كل المطاعم (يمكن تعديل الفلترة حسب الحاجة)
  Future<List<Map<String, dynamic>>> getAllRestaurants({
    bool onlyActive = true,
    bool onlyCompleted = true,
  }) async {
    try {
      var query = _supabase.from('restaurants').select('*, cities!city_id(name)');

      if (onlyActive) {
        query = query.eq('status', 'active');
      }

      if (onlyCompleted) {
        query = query.eq('info_completed', true);
      }

      final response = await query;
      final restaurants = (response as List<dynamic>).cast<Map<String, dynamic>>();
      for (final restaurant in restaurants) {
        final cityData = restaurant['cities'];
        if (cityData != null && cityData is Map) {
          restaurant['city'] = cityData['name'] as String? ?? '';
        } else if (cityData != null && cityData is List && cityData.isNotEmpty) {
          restaurant['city'] = (cityData[0] as Map)['name'] as String? ?? '';
        }
        restaurant.remove('cities');
      }
      return restaurants.map((r) => _normalizeRestaurantMap(r)).toList();
    } catch (e) {
      // If JOIN fails, fetch without JOIN
      print('[RestaurantSupabaseService] JOIN failed in getAllRestaurants: $e');
      var query = _supabase.from('restaurants').select();

      if (onlyActive) {
        query = query.eq('status', 'active');
      }

      if (onlyCompleted) {
        query = query.eq('info_completed', true);
      }

      final response = await query;
      final restaurants = (response as List<dynamic>).cast<Map<String, dynamic>>();
      for (final restaurant in restaurants) {
        if (restaurant['city_id'] != null) {
          try {
            final cityId = restaurant['city_id'] as String;
            final cityResponse = await _supabase
                .from('cities')
                .select('name')
                .eq('id', cityId)
                .maybeSingle();
            if (cityResponse != null) {
              restaurant['city'] = cityResponse['name'] as String? ?? '';
            }
          } catch (cityError) {
            print('[RestaurantSupabaseService] Error fetching city: $cityError');
          }
        }
      }
      return restaurants.map((r) => _normalizeRestaurantMap(r)).toList();
    }
  }

  // جلب حالة اكتمال معلومات مطعم معيّن
  Future<bool> getRestaurantInfoCompleted({
    required String? ownerId,
    String? ownerEmail, // اختياري إذا بدك تستخدمه لاحقاً
  }) async {
    final response = await _supabase
        .from('restaurants')
        .select('info_completed')
        .eq('owner_id', ownerId!)
        .maybeSingle(); // بديل execute + single

    if (response == null) return false;

    return response['info_completed'] as bool? ?? false;
  }

  // حذف مطعم حسب ownerId
  Future<void> deleteRestaurant(String ownerId) async {
    await _supabase.from('restaurants').delete().eq('owner_id', ownerId);
  }
}
