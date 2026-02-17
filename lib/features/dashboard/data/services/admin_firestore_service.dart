import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';

/// Service for admin CRUD operations on restaurants, items, and categories
class AdminFirestoreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Store admin password in memory for session restoration
  // This is only stored temporarily while admin is logged in
  static String? _storedAdminPassword;

  /// Store admin password when admin logs in
  /// This allows us to restore admin session after creating owner accounts
  static void storeAdminPassword(String password) {
    _storedAdminPassword = password;
    print(
      '[AdminFirestoreService] ✅ Admin password stored in memory (length: ${password.length})',
    );
  }

  /// Get stored admin password
  static String? getStoredAdminPassword() {
    final password = _storedAdminPassword;
    print(
      '[AdminFirestoreService] getStoredAdminPassword called. Password exists: ${password != null}',
    );
    return password;
  }

  /// Clear stored admin password (call on logout)
  static void clearStoredAdminPassword() {
    _storedAdminPassword = null;
    print('[AdminFirestoreService] Admin password cleared from memory');
  }

  static const String _restaurantsTable = 'restaurants';
  static const String _menuItemsTable = 'menu_items';
  static const String _usersTable = 'users';
  static const String _categoriesTable = 'menu_categories';
  static const String _citiesTable = 'cities';

  // ==================== RESTAURANTS ====================

  /// Get all restaurants (admin view - no filters)
  Future<List<Map<String, dynamic>>> getAllRestaurants() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('[AdminSupabaseService] WARNING: No authenticated user');
        return [];
      }

      List<Map<String, dynamic>> restaurants;

      try {
        // Try with JOIN first
        final response = await _supabase
            .from(_restaurantsTable)
            .select('*, cities!city_id(name)')
            .order('updated_at', ascending: false);

        restaurants = List<Map<String, dynamic>>.from(response as List);

        // Extract city names from joined cities table
        for (final restaurant in restaurants) {
          final cityData = restaurant['cities'];
          if (cityData != null && cityData is Map) {
            restaurant['city'] = cityData['name'] as String? ?? '';
          } else if (cityData != null &&
              cityData is List &&
              cityData.isNotEmpty) {
            restaurant['city'] = (cityData[0] as Map)['name'] as String? ?? '';
          }
          restaurant.remove('cities');
        }
      } catch (joinError) {
        // If JOIN fails, fetch without JOIN and get cities separately
        print(
          '[AdminSupabaseService] JOIN failed, fetching cities separately: $joinError',
        );
        final response = await _supabase
            .from(_restaurantsTable)
            .select()
            .order('updated_at', ascending: false);

        restaurants = List<Map<String, dynamic>>.from(response as List);

        // Fetch city names separately
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
              print('[AdminSupabaseService] Error fetching city: $cityError');
            }
          }
        }
      }

      // Fallback: sort by created_at if updated_at is missing
      restaurants.sort((a, b) {
        final aUpdated = a['updated_at'];
        final bUpdated = b['updated_at'];
        if (aUpdated != null && bUpdated != null) {
          return (bUpdated as String).compareTo(aUpdated as String);
        }
        final aCreated = a['created_at'];
        final bCreated = b['created_at'];
        if (aCreated != null && bCreated != null) {
          return (bCreated as String).compareTo(aCreated as String);
        }
        return 0;
      });

      print('[AdminSupabaseService] Loaded ${restaurants.length} restaurants');
      return restaurants;
    } catch (e) {
      print('[AdminSupabaseService] Exception in getAllRestaurants: $e');
      return [];
    }
  }

  /// Get a single restaurant by ID
  Future<Map<String, dynamic>?> getRestaurantById(String restaurantId) async {
    try {
      Map<String, dynamic>? restaurant;

      try {
        // Try with JOIN first
        final response = await _supabase
            .from(_restaurantsTable)
            .select('*, cities!city_id(name)')
            .eq('id', restaurantId)
            .limit(1);

        final data = response as List<dynamic>;
        if (data.isEmpty) return null;

        restaurant = Map<String, dynamic>.from(data.first);

        // Extract city name from joined cities table
        final cityData = restaurant['cities'];
        if (cityData != null && cityData is Map) {
          restaurant['city'] = cityData['name'] as String? ?? '';
        } else if (cityData != null &&
            cityData is List &&
            cityData.isNotEmpty) {
          restaurant['city'] = (cityData[0] as Map)['name'] as String? ?? '';
        }
        restaurant.remove('cities');
      } catch (joinError) {
        // If JOIN fails, fetch without JOIN and get city separately
        print(
          '[AdminSupabaseService] JOIN failed in getRestaurantById, fetching city separately: $joinError',
        );
        final response = await _supabase
            .from(_restaurantsTable)
            .select()
            .eq('id', restaurantId)
            .limit(1);

        final data = response as List<dynamic>;
        if (data.isEmpty) return null;

        restaurant = Map<String, dynamic>.from(data.first);

        // Fetch city name separately
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
            print('[AdminSupabaseService] Error fetching city: $cityError');
          }
        }
      }

      return restaurant;
    } catch (e) {
      throw Exception('Failed to get restaurant: $e');
    }
  }

  /// Check if owner already has a restaurant
  Future<bool> ownerHasRestaurant(String ownerId, String ownerEmail) async {
    try {
      final byIdResponse = await _supabase
          .from(_restaurantsTable)
          .select()
          .eq('owner_id', ownerId)
          .limit(1);

      if ((byIdResponse as List).isNotEmpty) return true;

      // Try to check by email (if column exists)
      try {
        final byEmailResponse = await _supabase
            .from(_restaurantsTable)
            .select()
            .eq('owner_email', ownerEmail)
            .limit(1);

        return (byEmailResponse as List).isNotEmpty;
      } catch (e) {
        // If column doesn't exist, skip email check
        if (e.toString().contains('42703') ||
            e.toString().contains('does not exist') ||
            e.toString().contains('column')) {
          print(
            '[AdminFirestoreService] ⚠️ owner_email column not found, skipping email check',
          );
          return false; // Assume no restaurant if we can't check
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('Failed to check restaurant existence: $e');
    }
  }

  /// Get user by email from users table (without creating Auth account)
  /// This is used when admin creates restaurant for existing user
  Future<Map<String, dynamic>?> getUserByEmailOnly(String email) async {
    try {
      final trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        return null;
      }

      // Search for user in users table by email
      final userResponse = await _supabase
          .from(_usersTable)
          .select()
          .eq('email', trimmedEmail)
          .maybeSingle();

      if (userResponse != null) {
        print(
          '[AdminFirestoreService] ✅ Found existing user by email: ${trimmedEmail}',
        );
        return userResponse;
      }

      print(
        '[AdminFirestoreService] ⚠️ User not found in users table: ${trimmedEmail}',
      );
      return null;
    } catch (e) {
      print('[AdminFirestoreService] Error getting user by email: $e');
      return null;
    }
  }

  /// Create or get user by email
  Future<Map<String, dynamic>> createOrGetUserByEmail(
    String email,
    String password, {
    String? adminEmail,
    String? adminPassword,
  }) async {
    try {
      // Validate email & password
      final trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty) {
        throw Exception('البريد الإلكتروني لا يمكن أن يكون فارغاً');
      }

      // Check for @ symbol
      if (!trimmedEmail.contains('@')) {
        throw Exception(
          'البريد الإلكتروني غير صالح: يجب أن يحتوي على @\n'
          'مثال: example@gmail.com',
        );
      }

      // Basic email format validation
      final emailParts = trimmedEmail.split('@');
      if (emailParts.length != 2 ||
          emailParts[0].isEmpty ||
          emailParts[1].isEmpty ||
          !emailParts[1].contains('.')) {
        throw Exception(
          'البريد الإلكتروني غير صالح: يجب أن يكون بالتنسيق الصحيح\n'
          'مثال: example@gmail.com',
        );
      }

      // Additional validation: local part (before @) should be at least 2 characters
      // Supabase Auth may reject very short emails like "m4@gmail.com"
      if (emailParts[0].length < 2) {
        throw Exception(
          'البريد الإلكتروني غير صالح: الجزء قبل @ يجب أن يكون حرفين على الأقل\n\n'
          'مثال صحيح: user123@gmail.com\n'
          'مثال غير صحيح: m4@gmail.com',
        );
      }

      if (password.trim().length < 6) {
        throw Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      }

      // Save admin session so we can restore it after creating/signing in as owner
      final adminIdBefore = _supabase.auth.currentUser?.id;
      final adminEmailBefore = _supabase.auth.currentUser?.email;
      final adminPasswordStored = getStoredAdminPassword();

      // Create Supabase Auth user
      User? supabaseUser;
      String? newUserUidFromFunction; // When we create via Edge Function without signing in
      bool isNewUser = false;

      // First, try to sign in to check if user already exists
      // This avoids hitting rate limit if user already exists
      try {
        print(
          '[AdminFirestoreService] Attempting to sign in first to check if user exists...',
        );
        final signInAttempt = await _supabase.auth.signInWithPassword(
          email: email.trim(),
          password: password.trim(),
        );
        supabaseUser = signInAttempt.user;
        isNewUser = false;
        print(
          '[AdminFirestoreService] ✅ User already exists, signed in: ${email.trim()}',
        );
      } on AuthException catch (signInError) {
        print(
          '[AdminFirestoreService] Sign in failed (user may not exist): ${signInError.message} (status: ${signInError.statusCode})',
        );

        // If sign in fails with invalid credentials, try to create new user
        if (signInError.statusCode == '400' ||
            signInError.message.toLowerCase().contains('invalid') ||
            signInError.message.toLowerCase().contains('wrong')) {
          // User doesn't exist - create via Edge Function (no confirmation email) or fallback to signUp
          print(
            '[AdminFirestoreService] User doesn\'t exist, attempting to create new user...',
          );

          // 1) Try Edge Function first: creates user with email_confirm=true (no confirmation email)
          // Do NOT sign in as the new user — keep admin session so createRestaurant works
          bool createdByFunction = false;
          try {
            final fnResponse = await _supabase.functions.invoke(
              'create-owner-user',
              body: {'email': email.trim(), 'password': password.trim()},
            );
            if (fnResponse.status == 200 &&
                fnResponse.data != null &&
                fnResponse.data['user'] != null) {
              final userData = fnResponse.data['user'] as Map<String, dynamic>;
              final uidFromResponse = userData['id'] as String?;
              if (uidFromResponse != null && uidFromResponse.isNotEmpty) {
                newUserUidFromFunction = uidFromResponse;
                isNewUser = true;
                createdByFunction = true;
                // Do not sign in as owner — session stays admin
                print(
                  '[AdminFirestoreService] ✅ Created via Edge Function (no sign-in, session stays admin): ${email.trim()}',
                );
              }
            }
          } catch (e) {
            final errStr = e.toString().toLowerCase();
            final isFailedFetch = errStr.contains('failed to fetch') ||
                errStr.contains('clientexception') ||
                errStr.contains('connection');
            print(
              '[AdminFirestoreService] Edge Function create-owner-user not available or failed: $e',
            );
            if (isFailedFetch) {
              print(
                '[AdminFirestoreService] Deploy the function: supabase functions deploy create-owner-user',
              );
            }
          }

          if (!createdByFunction) {
            // 2) Fallback: signUp (may send confirmation email if enabled in Supabase)
            try {
              final response = await _supabase.auth.signUp(
                email: email.trim(),
                password: password.trim(),
                data: {'display_name': email.split('@')[0]},
              );
              supabaseUser = response.user;
              isNewUser = true;
              print(
                '[AdminFirestoreService] ✅ Created new Supabase Auth user (signUp): ${email.trim()}',
              );
            } on AuthException catch (signUpError) {
            print(
              '[AdminFirestoreService] AuthException during signUp: ${signUpError.message} (status: ${signUpError.statusCode})',
            );

            // Handle rate limit error specifically
            if (signUpError.message.toLowerCase().contains('rate limit') ||
                signUpError.message.toLowerCase().contains(
                  'too many requests',
                ) ||
                signUpError.statusCode == '429') {
              // Instead of throwing error, allow creating restaurant without user
              // The user can sign up later from the mobile app
              print(
                '[AdminFirestoreService] ⚠️ Rate limit hit. Will create restaurant without Auth user. User can sign up later.',
              );
              // Return null to indicate that user creation failed due to rate limit
              // The calling code should handle this and create restaurant with email only
              throw Exception(
                'RATE_LIMIT_HIT', // Special error code for rate limit
              );
            }

            // Handle invalid email error from Supabase Auth
            if (signUpError.message.toLowerCase().contains('invalid') &&
                signUpError.message.toLowerCase().contains('email')) {
              throw Exception(
                'البريد الإلكتروني "$email" غير مقبول من قبل Supabase Auth.\n\n'
                'قد يكون السبب:\n'
                '• البريد الإلكتروني قصير جداً (مثل: m4@gmail.com)\n'
                '• البريد الإلكتروني يحتوي على أحرف غير مسموحة\n'
                '• البريد الإلكتروني غير صالح حسب قواعد Supabase\n\n'
                'يرجى استخدام بريد إلكتروني مختلف.\n'
                'مثال: user123@gmail.com',
              );
            }

            // If user already exists error during signup
            if (signUpError.message.toLowerCase().contains('already') ||
                signUpError.message.toLowerCase().contains('exists') ||
                signUpError.statusCode == '422') {
              // User exists but sign in failed - password might be wrong
              throw Exception(
                'المستخدم موجود بالفعل، لكن كلمة المرور غير صحيحة.\n\n'
                'يرجى استخدام كلمة المرور الصحيحة أو استخدام بريد إلكتروني مختلف.',
              );
            }

            // Error sending confirmation email (Supabase SMTP not configured or disabled)
            final msg = signUpError.message.toLowerCase();
            if (msg.contains('confirmation email') ||
                (msg.contains('sending') && msg.contains('email'))) {
              throw Exception(
                'تعذر إرسال بريد التأكيد من Supabase.\n\n'
                'حتى يعمل إنشاء الحساب من لوحة الإدارة بدون بريد تأكيد:\n'
                '1. (مفضّل) انشر الدالة: من مجلد المشروع نفّذ\n'
                '   supabase functions deploy create-owner-user\n'
                '   ثم أعد المحاولة.\n'
                '2. أو في Supabase: Authentication → Providers → Email → أوقف "Confirm email".\n'
                '3. أو إعداد SMTP في Project Settings → Auth → SMTP.\n'
                '4. أو أنشئ المستخدم يدوياً من Dashboard → Authentication → Users → Add user.',
              );
            }

            throw Exception('خطأ في إنشاء المستخدم: ${signUpError.message}');
            }
          }
        } else {
          // Other sign in errors
          throw Exception('خطأ في التحقق من المستخدم: ${signInError.message}');
        }
      }

      final uid = supabaseUser?.id ?? newUserUidFromFunction;
      if (uid == null || uid.isEmpty) {
        throw Exception('فشل في الحصول على بيانات المستخدم من Supabase Auth');
      }
      print('[AdminFirestoreService] User UID: $uid');

      // Create user record in Supabase table (if new)
      if (isNewUser) {
        final userData = {
          'id': uid,
          'email': email.trim(),
          'password': password
              .trim(), // Password is required by the users table
          'role': 'owner',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        try {
          await _supabase.from(_usersTable).insert(userData);
          print('[AdminFirestoreService] ✅ Created user record in users table');
        } catch (e) {
          print(
            '⚠️ [AdminFirestoreService] Warning: Failed to insert user row: $e',
          );
          // If it's a duplicate key error, that's OK - user might already exist
          if (e.toString().contains('23505') ||
              e.toString().contains('duplicate key')) {
            print(
              '[AdminFirestoreService] User record already exists (duplicate key), continuing...',
            );
          } else if (e.toString().contains('42501') ||
              e.toString().contains('row-level security')) {
            throw Exception(
              'خطأ في صلاحيات قاعدة البيانات (RLS).\n\n'
              'تأكد من وجود سياسة INSERT لجدول users للمستخدمين ذوي role = \'admin\'.',
            );
          } else {
            // For other errors, log but continue - we'll try to fetch the user
            print(
              '[AdminFirestoreService] Non-critical error inserting user, will try to fetch existing record',
            );
          }
        }
      }

      // Restore admin session so createRestaurant runs as admin (not as the owner we just created/signed in)
      if (adminEmailBefore != null &&
          adminEmailBefore.isNotEmpty &&
          adminPasswordStored != null &&
          _supabase.auth.currentUser?.id != adminIdBefore) {
        try {
          await _supabase.auth.signInWithPassword(
            email: adminEmailBefore,
            password: adminPasswordStored,
          );
          print(
            '[AdminFirestoreService] ✅ Restored admin session after creating owner',
          );
        } catch (e) {
          print(
            '[AdminFirestoreService] ⚠️ Failed to restore admin session: $e',
          );
        }
      }

      // Return user data - try to fetch from users table
      try {
        final userResponse = await _supabase
            .from(_usersTable)
            .select()
            .eq('id', uid)
            .limit(1);

        if ((userResponse as List).isEmpty) {
          // User doesn't exist in users table - create a minimal response
          print(
            '[AdminFirestoreService] ⚠️ User not found in users table, using minimal data',
          );
          return {
            'id': uid,
            'uid': uid,
            'email': email.trim(),
            'role': 'owner',
          };
        }

        final data = userResponse[0];
        print('[AdminFirestoreService] ✅ Fetched user data from users table');
        return data;
      } catch (e) {
        print(
          '[AdminFirestoreService] ⚠️ Error fetching user from users table: $e',
        );
        // If RLS blocks read, return minimal data
        if (e.toString().contains('42501') ||
            e.toString().contains('row-level security')) {
          print(
            '[AdminFirestoreService] RLS blocking read, using minimal user data',
          );
          return {
            'id': uid,
            'uid': uid,
            'email': email.trim(),
            'role': 'owner',
          };
        }
        rethrow;
      }
    } catch (e) {
      print('[AdminFirestoreService] ❌ Error in createOrGetUserByEmail: $e');
      // Re-throw with clearer message if it's not already a clear exception
      if (e is Exception && e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('فشل في إنشاء/الحصول على المستخدم: $e');
    }
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
      print('[AdminFirestoreService] Error getting city ID: $e');
      return null;
    }
  }

  Future<String> createRestaurant({
    required String ownerId,
    required String ownerEmail,
    required String name,
    required String phone,
    required String governorate,
    required String city,
    String? description,
    String? logoPath,
    String? status,
  }) async {
    try {
      // Ensure current user (admin) has role 'admin' in users — required for RLS on restaurants INSERT
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('يجب تسجيل الدخول أولاً.');
      }
      final me = await _supabase
          .from(_usersTable)
          .select('id, role')
          .eq('id', currentUserId)
          .maybeSingle();
      final rawRole = me?['role']?.toString();
      final myRole = rawRole?.trim().toLowerCase();
      print(
        '[AdminFirestoreService] Current user role from DB: raw="$rawRole" normalized="$myRole"',
      );
      if (myRole != 'admin') {
        throw Exception(
          'حسابك الحالي ليس أدمن. إنشاء المطاعم مسموح فقط للمستخدمين بدور admin.\n\n'
          'المستخدم الحالي: $currentUserId\n'
          'الدور الحالي: ${myRole ?? "لا يوجد صف في جدول users"}\n\n'
          'في Supabase → SQL Editor نفّذ أحد الأمرين:\n\n'
          'إذا كان لديك صف في users:\n'
          'UPDATE public.users SET role = \'admin\' WHERE id = \'$currentUserId\';\n\n'
          'إذا لم يكن لديك صف، أضف واحداً (غيّر البريد):\n'
          'INSERT INTO public.users (id, email, role)\n'
          'VALUES (\'$currentUserId\', \'admin@example.com\', \'admin\');',
        );
      }

      // Get city_id from cities table
      String? cityId;
      try {
        cityId = await getCityId(governorate, city);
        if (cityId == null) {
          print(
            '[AdminFirestoreService] ⚠️ City "$city" not found in cities table for governorate "$governorate"',
          );
          throw Exception(
            'المدينة "$city" غير موجودة في قاعدة البيانات للمحافظة "$governorate".\n\n'
            'يرجى التأكد من أن المدينة موجودة في جدول cities.',
          );
        }
        print(
          '[AdminFirestoreService] ✅ Found city ID: $cityId for city "$city"',
        );
      } catch (e) {
        // If it's our custom exception, rethrow it
        if (e.toString().contains('غير موجودة')) {
          rethrow;
        }
        // For other errors, log and continue (might be RLS or other issues)
        print('[AdminFirestoreService] ⚠️ Could not get city ID: $e');
      }
      // تحقق إذا المالك عنده مطعم مسبقاً (فقط إذا كان ownerId موجود)
      if (ownerId.isNotEmpty) {
        final hasRestaurant = await ownerHasRestaurant(ownerId, ownerEmail);
        if (hasRestaurant) {
          throw Exception('المالك لديه مطعم بالفعل.');
        }
      } else {
        // If ownerId is empty, try to check by email (if column exists)
        try {
          final byEmailResponse = await _supabase
              .from(_restaurantsTable)
              .select('id')
              .eq('owner_email', ownerEmail)
              .limit(1);

          if ((byEmailResponse as List).isNotEmpty) {
            throw Exception('يوجد مطعم مسجل بهذا البريد الإلكتروني بالفعل.');
          }
        } catch (e) {
          // If column doesn't exist, skip email check
          if (e.toString().contains('42703') ||
              e.toString().contains('does not exist') ||
              e.toString().contains('column')) {
            print(
              '[AdminFirestoreService] ⚠️ owner_email column not found, skipping email check',
            );
            // Continue - we'll create restaurant without owner_email if column doesn't exist
          } else {
            rethrow;
          }
        }
      }

      final payload = <String, dynamic>{
        'name': name,
        'phone': phone,
        'governorate': governorate,
        'description': description ?? '',
        'logo_path': logoPath ?? '',
        'status': status ?? 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // When admin creates restaurant, info_completed should be true
      // This is a required field, so we always include it
      payload['info_completed'] = true;

      // Add city_id (required)
      if (cityId != null) {
        payload['city_id'] = cityId;
      } else {
        throw Exception(
          'فشل في الحصول على معرف المدينة. يرجى التأكد من أن المدينة موجودة في قاعدة البيانات.',
        );
      }

      // Add owner_id if it's not empty
      if (ownerId.isNotEmpty) {
        payload['owner_id'] = ownerId;
      }

      // Try to add owner_email if column exists
      if (ownerEmail.isNotEmpty) {
        payload['owner_email'] = ownerEmail;
      }

      print('Creating restaurant with payload: $payload');
      print(
        '[AdminFirestoreService] Inserting as admin user: $currentUserId',
      );

      // Insert into Supabase with error handling for missing columns and RLS
      dynamic response;
      try {
        response = await _supabase
            .from(_restaurantsTable)
            .insert(payload)
            .select();
      } catch (insertError) {
        final errorStr = insertError.toString();
        print('[AdminFirestoreService] Insert error: $errorStr');

        // Check if it's an RLS error (code 42501)
        if (insertError is PostgrestException && insertError.code == '42501') {
          final uid = _supabase.auth.currentUser?.id ?? 'غير معروف';
          throw Exception(
            'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول restaurants.\n\n'
            'المستخدم المسجّل حالياً (auth.uid()) يجب أن يكون له صف في جدول public.users وقيمة role = \'admin\'.\n\n'
            'المستخدم الحالي: $uid\n\n'
            'في Supabase:\n'
            '1. Table Editor → users → تأكد من وجود صف حيث id = $uid\n'
            '2. في ذلك الصف ضع role = admin (أو نفّذ في SQL Editor):\n\n'
            '   UPDATE public.users SET role = \'admin\' WHERE id = \'$uid\';\n\n'
            'إذا لم يكن هناك صف، أضف واحداً (عدّل البريد وكلمة المرور إن لزم):\n\n'
            '   INSERT INTO public.users (id, email, role)\n'
            '   VALUES (\'$uid\', \'your-admin@email.com\', \'admin\');',
          );
        }

        // Check if it's a column not found error
        if (errorStr.contains('42703') ||
            errorStr.contains('PGRST204') ||
            errorStr.contains('does not exist') ||
            errorStr.contains('column')) {
          print(
            '[AdminFirestoreService] ⚠️ Column not found, trying to identify missing column...',
          );

          // Try to identify which column is missing
          String? missingColumn;
          if (errorStr.contains('owner_email')) {
            missingColumn = 'owner_email';
          } else if (errorStr.contains('city_id')) {
            missingColumn = 'city_id';
            throw Exception(
              'فشل في إنشاء المطعم: عمود city_id غير موجود في جدول restaurants.\n\n'
              'يرجى التحقق من أن عمود city_id موجود في Supabase.',
            );
          } else if (errorStr.contains('info_completed')) {
            // info_completed is required, so if it's missing, we need to add it to the database
            throw Exception(
              'فشل في إنشاء المطعم: عمود info_completed غير موجود في جدول restaurants.\n\n'
              'هذا العمود إجباري. يرجى إضافته في Supabase:\n\n'
              'ALTER TABLE restaurants ADD COLUMN info_completed BOOLEAN NOT NULL DEFAULT false;\n\n'
              'أو من خلال Supabase Dashboard:\n'
              '1. افتح Table Editor > restaurants\n'
              '2. أضف عمود جديد: info_completed (type: boolean, default: false)',
            );
          } else if (errorStr.contains('governorate')) {
            missingColumn = 'governorate';
          }

          if (missingColumn != null && missingColumn != 'city_id') {
            print(
              '[AdminFirestoreService] Removing missing column: $missingColumn',
            );
            payload.remove(missingColumn);
          } else if (missingColumn == null) {
            // If we can't identify, try removing only optional columns
            payload.remove('owner_email');
            // Don't remove info_completed - it's required
          }

          // Retry insert
          try {
            response = await _supabase
                .from(_restaurantsTable)
                .insert(payload)
                .select();
            print(
              '[AdminFirestoreService] ✅ Retry successful after removing missing column',
            );
          } catch (retryError) {
            print('[AdminFirestoreService] ❌ Retry also failed: $retryError');
            // Final attempt: remove only optional columns
            print(
              '[AdminFirestoreService] Final attempt: removing optional columns',
            );
            payload.remove('owner_email');
            // Don't remove info_completed - it's required

            try {
              response = await _supabase
                  .from(_restaurantsTable)
                  .insert(payload)
                  .select();
              print('[AdminFirestoreService] ✅ Final retry successful');
            } catch (finalError) {
              throw Exception(
                'فشل في إنشاء المطعم: عمود غير موجود في جدول restaurants.\n\n'
                'يرجى التحقق من الأعمدة التالية في Supabase:\n'
                '- city_id (مطلوب)\n'
                '- governorate (مطلوب)\n'
                '- info_completed (مطلوب - boolean, default: false)\n'
                '- owner_email (اختياري)\n\n'
                'لإضافة عمود info_completed:\n'
                'ALTER TABLE restaurants ADD COLUMN info_completed BOOLEAN NOT NULL DEFAULT false;\n\n'
                'الخطأ الأصلي: $insertError\n'
                'الخطأ بعد إعادة المحاولة: $finalError',
              );
            }
          }
        } else {
          rethrow;
        }
      }

      if (response.isEmpty || (response as List).isEmpty) {
        throw Exception('Failed to create restaurant');
      }

      final createdRestaurant = response[0];
      final restaurantId = createdRestaurant['id'] as String;

      print('Restaurant created successfully with ID: $restaurantId');

      return restaurantId;
    } catch (e) {
      print('ERROR creating restaurant: $e');
      throw Exception('Failed to create restaurant: $e');
    }
  }

  Future<void> updateRestaurant({
    required String restaurantId,
    String? name,
    String? phone,
    String? governorate,
    String? city,
    String? description,
    String? logoPath,
    String? status,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (governorate != null) updateData['governorate'] = governorate;

      // If city is provided, get city_id
      if (city != null && governorate != null) {
        final cityId = await getCityId(governorate, city);
        if (cityId != null) {
          updateData['city_id'] = cityId;
        } else {
          throw Exception(
            'المدينة "$city" غير موجودة في قاعدة البيانات للمحافظة "$governorate".',
          );
        }
      }
      if (description != null) updateData['description'] = description;
      if (logoPath != null) updateData['logo_path'] = logoPath;
      if (status != null) updateData['status'] = status;

      await _supabase
          .from(_restaurantsTable)
          .update(updateData)
          .eq('id', restaurantId);
    } catch (e) {
      throw Exception('Failed to update restaurant: $e');
    }
  }

  Future<Map<String, String>> deleteRestaurant(String restaurantId) async {
    try {
      // 1. جيبي بيانات المطعم قبل الحذف (maybeSingle: لا ترمي إذا 0 صفوف)
      final restaurant = await _supabase
          .from('restaurants')
          .select('owner_id, owner_email')
          .eq('id', restaurantId)
          .maybeSingle();

      if (restaurant == null) {
        throw Exception('المطعم غير موجود أو تم حذفه مسبقاً');
      }

      final ownerId = restaurant['owner_id'] as String? ?? '';
      final ownerEmail = restaurant['owner_email'] as String? ?? '';

      // 2. احذفي المطعم
      await _supabase.from('restaurants').delete().eq('id', restaurantId);

      // 3. احذفي صف المستخدم من جدول users (owner)
      if (ownerId.isNotEmpty) {
        try {
          await _supabase.from('users').delete().eq('id', ownerId);
        } catch (e) {
          print('[AdminFirestoreService] deleteRestaurant: could not delete user row: $e');
          // Continue - restaurant is already deleted
        }
      }

      // 4. رجّعي البيانات اللي بدنا نكمّل فيها
      return {'ownerId': ownerId, 'ownerEmail': ownerEmail};
    } catch (e) {
      print('[AdminFirestoreService] deleteRestaurant error: $e');
      throw Exception('Failed to delete restaurant: $e');
    }
  }

  // ==================== MENU ITEMS ====================

  /// Get all menu items (admin view - from all restaurants)
  Stream<List<Map<String, dynamic>>> getAllMenuItems() {
    return _supabase
        .from(_menuItemsTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          // Process each row to add category name from category_id
          final processedRows = <Map<String, dynamic>>[];
          for (final row in rows) {
            final processedRow = Map<String, dynamic>.from(row);

            // Always try to get category name from category_id if it exists
            if (processedRow['category_id'] != null) {
              try {
                final categoryId = processedRow['category_id'];
                print(
                  '[AdminFirestoreService] Processing item ${processedRow['id']}: category_id = $categoryId (type: ${categoryId.runtimeType})',
                );

                final categoryName = await getCategoryNameById(categoryId);
                print(
                  '[AdminFirestoreService] Got category name: $categoryName for item ${processedRow['id']}',
                );

                if (categoryName != null && categoryName.isNotEmpty) {
                  processedRow['category'] = categoryName;
                  print(
                    '[AdminFirestoreService] ✅ Set category to: $categoryName for item ${processedRow['id']}',
                  );
                } else {
                  print(
                    '[AdminFirestoreService] ⚠️ Category name is null or empty for item ${processedRow['id']}, using fallback',
                  );
                  // Set fallback if category name is not found
                  if (processedRow['category'] == null ||
                      processedRow['category'].toString().isEmpty) {
                    processedRow['category'] = 'غير مصنف';
                  }
                }
              } catch (e, stackTrace) {
                print(
                  '[AdminFirestoreService] ❌ Error getting category name for item ${processedRow['id']}: $e',
                );
                print('[AdminFirestoreService] Stack trace: $stackTrace');
                // Set fallback on error
                if (processedRow['category'] == null ||
                    processedRow['category'].toString().isEmpty) {
                  processedRow['category'] = 'غير مصنف';
                }
              }
            } else {
              // No category_id, use existing category or fallback
              if (processedRow['category'] == null ||
                  processedRow['category'].toString().isEmpty) {
                processedRow['category'] = 'غير مصنف';
                print(
                  '[AdminFirestoreService] ⚠️ No category_id for item ${processedRow['id']}, using fallback',
                );
              }
            }

            processedRows.add(processedRow);
          }
          print(
            '[AdminFirestoreService] Processed ${processedRows.length} items',
          );
          return processedRows;
        });
  }

  Future<Map<String, dynamic>?> getMenuItemById(String itemId) async {
    try {
      final response = await _supabase
          .from(_menuItemsTable)
          .select()
          .eq('id', itemId)
          .single();

      return response;
    } catch (e) {
      print('Failed to get menu item: $e');
      return null;
    }
  }

  Future<String> createMenuItem({
    required String name,
    required String category,
    required String price,
    required String ownerId,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      // Check if ownerId is an email (contains @)
      // If it is, try to find the actual owner_id from restaurants table
      String? finalOwnerId = ownerId;
      String? ownerEmail;

      if (ownerId.contains('@')) {
        // ownerId is an email, try to find owner_id from restaurants
        ownerEmail = ownerId;
        try {
          final restaurant = await _supabase
              .from(_restaurantsTable)
              .select('owner_id, owner_email')
              .eq('owner_email', ownerEmail)
              .maybeSingle();

          if (restaurant != null) {
            finalOwnerId = restaurant['owner_id'] as String? ?? '';
            // If still empty, use email as fallback
            if (finalOwnerId.isEmpty) {
              finalOwnerId = ownerEmail;
            }
          } else {
            // Restaurant not found, use email as owner_id
            finalOwnerId = ownerEmail;
          }
        } catch (e) {
          print(
            '[AdminFirestoreService] Error finding owner_id for email $ownerEmail: $e',
          );
          // Use email as fallback
          finalOwnerId = ownerEmail;
        }
      }

      // Get restaurant_id from restaurants table (needed for category lookup; categories are related to restaurant_id)
      String? restaurantId;
      try {
        if (finalOwnerId.contains('@')) {
          final restaurant = await _supabase
              .from(_restaurantsTable)
              .select('id')
              .eq('owner_email', finalOwnerId)
              .maybeSingle();
          restaurantId = restaurant?['id'] as String?;
        } else {
          final restaurant = await _supabase
              .from(_restaurantsTable)
              .select('id')
              .eq('owner_id', finalOwnerId)
              .maybeSingle();
          restaurantId = restaurant?['id'] as String?;
        }

        if (restaurantId == null) {
          throw Exception(
            'لم يتم العثور على مطعم للمالك المحدد. يرجى التأكد من أن المالك لديه مطعم مسجل.',
          );
        }
      } catch (e) {
        print('[AdminFirestoreService] Error finding restaurant_id: $e');
        throw Exception('فشل في العثور على مطعم للمالك: $e');
      }

      // Get category ID from category name (categories are related to restaurant_id)
      // If category doesn't exist for this restaurant, create it
      dynamic categoryId;
      if (category.isNotEmpty && category != 'غير مصنف') {
        final categoryDoc = await _supabase
            .from(_categoriesTable)
            .select('id')
            .eq('name', category)
            .eq('restaurant_id', restaurantId)
            .maybeSingle();

        if (categoryDoc != null && categoryDoc['id'] != null) {
          final id = categoryDoc['id'];
          categoryId = id is int ? id : (id is String ? id : id.toString());
          print(
            '[AdminFirestoreService] Found category_id for "$category" (restaurant: $restaurantId): $categoryId',
          );
        } else {
          // Category doesn't exist for this restaurant - create it
          print(
            '[AdminFirestoreService] Category "$category" not found for restaurant $restaurantId - creating it',
          );
          final inserted = await _supabase
              .from(_categoriesTable)
              .insert({
                'name': category,
                'restaurant_id': restaurantId,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select('id');
          if (inserted.isNotEmpty && inserted[0]['id'] != null) {
            final id = inserted[0]['id'];
            categoryId = id is int ? id : (id is String ? id : id.toString());
            print(
              '[AdminFirestoreService] Created category "$category" for restaurant $restaurantId: $categoryId',
            );
          }
        }
      }

      if (categoryId == null) {
        final unclassifiedDoc = await _supabase
            .from(_categoriesTable)
            .select('id')
            .eq('name', 'غير مصنف')
            .eq('restaurant_id', restaurantId)
            .maybeSingle();

        if (unclassifiedDoc != null && unclassifiedDoc['id'] != null) {
          final id = unclassifiedDoc['id'];
          categoryId = id is int ? id : (id is String ? id : id.toString());
        } else {
          final inserted = await _supabase
              .from(_categoriesTable)
              .insert({
                'name': 'غير مصنف',
                'restaurant_id': restaurantId,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select('id');
          if (inserted.isNotEmpty && inserted[0]['id'] != null) {
            final id = inserted[0]['id'];
            categoryId = id is int ? id : (id is String ? id : id.toString());
          }
        }
      }

      final menuItemData = {
        'name': name,
        'category_id': categoryId,
        'price': price,
        'description': description ?? '',
        'restaurant_id': restaurantId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // restaurant_name is not in the schema, so we don't add it

      // Add image column (try different possible column names)
      // Common names: image, image_url, image_path
      if (imageUrl != null && imageUrl.isNotEmpty) {
        menuItemData['image'] = imageUrl;
      }

      // Don't add owner_email - it's not in the schema
      // The owner_id is sufficient to link the item to the owner

      // Try to insert with image first
      dynamic response;
      try {
        response = await _supabase
            .from(_menuItemsTable)
            .insert(menuItemData)
            .select(); // هذا يرجع البيانات بعد الإدخال

        if (response.isEmpty) throw Exception('Failed to create menu item');

        final createdItem = response[0];
        return createdItem['id'] as String;
      } catch (insertError) {
        final errorStr = insertError.toString();
        print('[AdminFirestoreService] Insert error: $errorStr');

        // Check if it's an RLS error
        if (insertError is PostgrestException && insertError.code == '42501') {
          throw Exception(
            'خطأ في صلاحيات قاعدة البيانات (RLS). تأكد من وجود سياسة INSERT لجدول menu_items للمستخدمين ذوي role = \'admin\'. '
            'أضف السياسة التالية في Supabase:\n'
            'CREATE POLICY "Allow admin to insert menu_items" ON "public"."menu_items" '
            'FOR INSERT TO authenticated '
            'WITH CHECK ( EXISTS ( SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = \'admin\' ) );',
          );
        }

        // Check if it's a column not found error
        if (errorStr.contains('42703') ||
            errorStr.contains('PGRST204') ||
            errorStr.contains('does not exist')) {
          // Check which column is missing
          String? missingColumn;
          if (errorStr.contains('image')) {
            missingColumn = 'image';
            print(
              '[AdminFirestoreService] Image column not found, trying alternative names...',
            );
          } else if (errorStr.contains('restaurant_name')) {
            missingColumn = 'restaurant_name';
            print(
              '[AdminFirestoreService] restaurant_name column not found, removing it...',
            );
            menuItemData.remove('restaurant_name');
          } else if (errorStr.contains('owner_email')) {
            missingColumn = 'owner_email';
            print(
              '[AdminFirestoreService] owner_email column not found, removing it...',
            );
            menuItemData.remove('owner_email');
          }

          // If image column is missing, try alternatives
          if (missingColumn == 'image') {
            // Try image_url
            menuItemData.remove('image');
            if (imageUrl != null && imageUrl.isNotEmpty) {
              menuItemData['image_url'] = imageUrl;
            }

            try {
              response = await _supabase
                  .from(_menuItemsTable)
                  .insert(menuItemData)
                  .select();

              if (response.isEmpty)
                throw Exception('Failed to create menu item');

              final createdItem = response[0];
              print(
                '[AdminFirestoreService] ✅ Created menu item with image_url',
              );
              return createdItem['id'] as String;
            } catch (retryError) {
              // Try without image column
              print(
                '[AdminFirestoreService] Retry with image_url failed, trying without image: $retryError',
              );
              menuItemData.remove('image_url');
            }
          }

          // Final attempt: insert without optional columns
          try {
            response = await _supabase
                .from(_menuItemsTable)
                .insert(menuItemData)
                .select();

            if (response.isEmpty) throw Exception('Failed to create menu item');

            final createdItem = response[0];
            print(
              '[AdminFirestoreService] ✅ Created menu item without optional columns',
            );
            return createdItem['id'] as String;
          } catch (finalError) {
            print('Failed to create menu item after all retries: $finalError');
            throw Exception('Failed to create menu item: $finalError');
          }
        } else {
          // Other errors, rethrow
          print('Failed to create menu item: $insertError');
          throw Exception('Failed to create menu item: $insertError');
        }
      }
    } catch (e) {
      print('Failed to create menu item: $e');
      throw Exception('Failed to create menu item: $e');
    }
  }

  Future<void> updateMenuItem({
    required String itemId,
    String? name,
    String? category,
    String? price,
    String? description,
    String? imageUrl,
    String? restaurantName,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (category != null) {
        final itemRow = await _supabase
            .from(_menuItemsTable)
            .select('restaurant_id')
            .eq('id', itemId)
            .maybeSingle();
        final restaurantId = itemRow?['restaurant_id']?.toString() ?? '';

        dynamic categoryId;
        if (category.isNotEmpty && category != 'غير مصنف' && restaurantId.isNotEmpty) {
          final categoryDoc = await _supabase
              .from(_categoriesTable)
              .select('id')
              .eq('name', category)
              .eq('restaurant_id', restaurantId)
              .maybeSingle();
          if (categoryDoc != null && categoryDoc['id'] != null) {
            final id = categoryDoc['id'];
            categoryId = id is int ? id : (id is String ? id : id.toString());
          } else {
            // Category doesn't exist for this restaurant - create it
            final inserted = await _supabase
                .from(_categoriesTable)
                .insert({
                  'name': category,
                  'restaurant_id': restaurantId,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .select('id');
            if (inserted.isNotEmpty && inserted[0]['id'] != null) {
              final id = inserted[0]['id'];
              categoryId = id is int ? id : (id is String ? id : id.toString());
            }
          }
        }

        if (categoryId == null && restaurantId.isNotEmpty) {
          final unclassifiedDoc = await _supabase
              .from(_categoriesTable)
              .select('id')
              .eq('name', 'غير مصنف')
              .eq('restaurant_id', restaurantId)
              .maybeSingle();
          if (unclassifiedDoc != null && unclassifiedDoc['id'] != null) {
            final id = unclassifiedDoc['id'];
            categoryId = id is int ? id : (id is String ? id : id.toString());
          }
        }

        if (categoryId != null) {
          if (categoryId is int) {
            updateData['category_id'] = categoryId;
          } else if (categoryId is String) {
            final parsed = int.tryParse(categoryId);
            updateData['category_id'] = parsed ?? categoryId;
          } else {
            updateData['category_id'] = categoryId;
          }
        }
      }
      if (price != null) updateData['price'] = price;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['image'] = imageUrl;

      await _supabase.from(_menuItemsTable).update(updateData).eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to update menu item: $e');
    }
  }

  Future<void> deleteMenuItem(String itemId) async {
    try {
      await _supabase.from(_menuItemsTable).delete().eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to delete menu item: $e');
    }
  }

  // ==================== CATEGORIES ====================

  /// Get category name by category_id
  Future<String?> getCategoryNameById(dynamic categoryId) async {
    try {
      if (categoryId == null) {
        print(
          '[AdminFirestoreService] getCategoryNameById: categoryId is null',
        );
        return null;
      }

      print(
        '[AdminFirestoreService] getCategoryNameById: categoryId type: ${categoryId.runtimeType}, value: $categoryId',
      );

      // Handle both int, String (UUID), and other types
      dynamic id;
      if (categoryId is int) {
        id = categoryId;
      } else if (categoryId is String) {
        // Check if it's a UUID (contains hyphens) or a numeric string
        if (categoryId.contains('-')) {
          // It's a UUID, use it as is
          id = categoryId;
        } else {
          // Try to parse as int
          id = int.tryParse(categoryId);
          if (id == null) {
            // If parsing fails, use as String (might be UUID without hyphens or other format)
            id = categoryId;
          }
        }
      } else {
        // Use as is for other types
        id = categoryId;
      }

      print(
        '[AdminFirestoreService] getCategoryNameById: Using id: $id (type: ${id.runtimeType})',
      );

      final categoryDoc = await _supabase
          .from(_categoriesTable)
          .select('name')
          .eq('id', id)
          .maybeSingle();

      if (categoryDoc == null) {
        print(
          '[AdminFirestoreService] getCategoryNameById: No category found for id: $id',
        );
        return null;
      }

      final name = categoryDoc['name'];
      final result = name is String ? name : name?.toString();
      print(
        '[AdminFirestoreService] getCategoryNameById: Found category name: $result',
      );
      return result;
    } catch (e, stackTrace) {
      print('[AdminFirestoreService] Error getting category name by id: $e');
      print('[AdminFirestoreService] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get all unique categories (admin view - all restaurants)
  Future<List<String>> getAllCategories() async {
    try {
      final response = await _supabase.from(_categoriesTable).select();

      final categories = <String>{};
      for (final row in response) {
        final name = row['name'] as String?;
        if (name != null && name.isNotEmpty) {
          categories.add(name);
        }
      }

      categories.add('غير مصنف');

      final finalCategories = categories.toList()..sort();
      print('[AdminService] getAllCategories: $finalCategories');
      return finalCategories;
    } catch (e) {
      print('[AdminService] Error getting categories: $e');
      throw Exception('Failed to get categories: $e');
    }
  }

  /// Get categories for a restaurant (categories are related to restaurant_id)
  Future<List<String>> getCategoriesByRestaurantId(String restaurantId) async {
    if (restaurantId.isEmpty) return [];
    try {
      final response = await _supabase
          .from(_categoriesTable)
          .select('name')
          .eq('restaurant_id', restaurantId);

      final categories = <String>{};
      for (final row in response) {
        final name = row['name'] as String?;
        if (name != null && name.isNotEmpty) {
          categories.add(name);
        }
      }
      categories.add('غير مصنف');
      final list = categories.toList()..sort();
      print('[AdminService] getCategoriesByRestaurantId($restaurantId): $list');
      return list;
    } catch (e) {
      print('[AdminService] Error getCategoriesByRestaurantId: $e');
      return [];
    }
  }

  Future<void> updateCategoryName({
    required String oldCategory,
    required String newCategory,
    String? restaurantId,
  }) async {
    try {
      final name = newCategory.trim();
      if (name.isEmpty) throw Exception('اسم الفئة لا يمكن أن يكون فارغاً');

      var existsQuery = _supabase.from(_categoriesTable).select().eq('name', name);
      if (restaurantId != null && restaurantId.isNotEmpty) {
        existsQuery = existsQuery.eq('restaurant_id', restaurantId);
      }
      final exists = await existsQuery.limit(1);
      if (exists.isNotEmpty) throw Exception('هذه الفئة موجودة بالفعل');

      var toUpdateQuery = _supabase.from(_categoriesTable).select('id').eq('name', oldCategory);
      if (restaurantId != null && restaurantId.isNotEmpty) {
        toUpdateQuery = toUpdateQuery.eq('restaurant_id', restaurantId);
      }
      var categoryToUpdate = await toUpdateQuery.maybeSingle();

      // If old category not in DB (e.g. user added it only in UI), create it with the new name
      if (categoryToUpdate == null) {
        final insertPayload = <String, dynamic>{
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (restaurantId != null && restaurantId.isNotEmpty) {
          insertPayload['restaurant_id'] = restaurantId;
        }
        await _supabase.from(_categoriesTable).insert(insertPayload);
        print('[AdminService] Category "$oldCategory" was not in DB; created "$name"');
        return;
      }

      final categoryId = categoryToUpdate['id'];

      final updated = await _supabase
          .from(_categoriesTable)
          .update({
            'name': name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', categoryId)
          .select('id, name');

      if (updated.isEmpty) {
        throw Exception(
          'فشل تحديث الفئة: لم يتم تطبيق التغيير. تأكد من تشغيل migration: '
          'supabase/migrations/20260214_menu_categories_insert_authenticated.sql',
        );
      }

      print('[AdminService] Updated category "$oldCategory" -> "$name"');
    } catch (e) {
      print('[AdminService] Error updating category: $e');
      throw Exception('Failed to update category: $e');
    }
  }

  Future<void> deleteCategory(String category, {String? restaurantId}) async {
    try {
      const unclassified = 'غير مصنف';

      var existsQuery = _supabase.from(_categoriesTable).select().eq('name', unclassified);
      if (restaurantId != null && restaurantId.isNotEmpty) {
        existsQuery = existsQuery.eq('restaurant_id', restaurantId);
      }
      final exists = await existsQuery.limit(1);

      if (exists.isEmpty) {
        final insertPayload = <String, dynamic>{
          'name': unclassified,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (restaurantId != null && restaurantId.isNotEmpty) {
          insertPayload['restaurant_id'] = restaurantId;
        }
        await _supabase.from(_categoriesTable).insert(insertPayload);
        print('[AdminService] Created "غير مصنف" category');
      }

      var toDeleteQuery = _supabase.from(_categoriesTable).select('id').eq('name', category);
      if (restaurantId != null && restaurantId.isNotEmpty) {
        toDeleteQuery = toDeleteQuery.eq('restaurant_id', restaurantId);
      }
      final categoryToDelete = await toDeleteQuery.maybeSingle();

      if (categoryToDelete == null) {
        throw Exception('الفئة "$category" غير موجودة');
      }

      final categoryIdToDelete = categoryToDelete['id'];

      var unclassifiedQuery = _supabase.from(_categoriesTable).select('id').eq('name', unclassified);
      if (restaurantId != null && restaurantId.isNotEmpty) {
        unclassifiedQuery = unclassifiedQuery.eq('restaurant_id', restaurantId);
      }
      final unclassifiedCategory = await unclassifiedQuery.maybeSingle();

      if (unclassifiedCategory == null) {
        throw Exception('فشل في العثور على فئة "غير مصنف"');
      }

      final unclassifiedCategoryId = unclassifiedCategory['id'];

      // نقل كل العناصر إلى "غير مصنف" باستخدام category_id
      try {
        await _supabase
            .from(_menuItemsTable)
            .update({
              'category_id': unclassifiedCategoryId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('category_id', categoryIdToDelete);
        print(
          '[AdminService] Moved items from category "$category" (id: $categoryIdToDelete) to "$unclassified" (id: $unclassifiedCategoryId)',
        );
      } catch (updateError) {
        print(
          '[AdminService] ⚠️ Warning: Could not update menu_items.category_id: $updateError',
        );
        // Continue - category will be deleted even if we can't update items
      }

      // حذف الفئة نفسها
      await _supabase
          .from(_categoriesTable)
          .delete()
          .eq('id', categoryIdToDelete);

      print('[AdminService] Deleted category "$category"');
    } catch (e) {
      print('[AdminService] Error deleting category: $e');
      // Check if it's a column not found error
      if (e.toString().contains('PGRST204') ||
          e.toString().contains('Could not find') ||
          e.toString().contains('column')) {
        throw Exception(
          'خطأ: عمود category غير موجود في جدول menu_items.\n\n'
          'يرجى التحقق من:\n'
          '1. اسم العمود في جدول menu_items (قد يكون category_name أو اسم آخر)\n'
          '2. أو إضافة عمود category إلى جدول menu_items',
        );
      }
      throw Exception('فشل في حذف الفئة: $e');
    }
  }

  /// Create a category for a restaurant (categories are related to restaurant_id)
  Future<void> createCategory(String categoryName, {String? restaurantId}) async {
    try {
      final name = categoryName.trim();
      if (name.isEmpty) throw Exception('اسم الفئة لا يمكن أن يكون فارغاً');

      final query = _supabase.from(_categoriesTable).select().eq('name', name);
      final existing = restaurantId != null && restaurantId.isNotEmpty
          ? await query.eq('restaurant_id', restaurantId).limit(1)
          : await query.limit(1);

      if (existing.isNotEmpty) throw Exception('هذه الفئة موجودة بالفعل');

      final payload = <String, dynamic>{
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (restaurantId != null && restaurantId.isNotEmpty) {
        payload['restaurant_id'] = restaurantId;
      }

      try {
        await _supabase.from(_categoriesTable).insert(payload);

        print('[AdminService] Category created: $name');
      } catch (insertError) {
        // Check if it's an RLS error (code 42501)
        if (insertError is PostgrestException && insertError.code == '42501') {
          print(
            '[AdminService] RLS Error Details (create category): ${insertError.message}, Code: ${insertError.code}',
          );
          throw Exception(
            'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول menu_categories.\n\n'
            'شغّل الملف: supabase/migrations/20260214_menu_categories_insert_authenticated.sql '
            'في Supabase Dashboard → SQL Editor، أو أضف سياسة INSERT:\n\n'
            'Policy: Allow authenticated to insert menu_categories\n'
            'FOR INSERT TO authenticated WITH CHECK (true)',
          );
        }
        // Also check string representation for RLS errors
        if (insertError.toString().contains('42501') ||
            insertError.toString().contains('row-level security')) {
          throw Exception(
            'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول menu_categories. '
            'شغّل migration: 20260214_menu_categories_insert_authenticated.sql',
          );
        }
        rethrow;
      }
    } catch (e) {
      print('[AdminService] Error creating category: $e');
      // Re-throw if it's already a clear exception message
      if (e is Exception && e.toString().contains('خطأ في صلاحيات')) {
        rethrow;
      }
      throw Exception('فشل في إنشاء الفئة: $e');
    }
  }

  // ==================== USERS/OWNERS ====================

  Future<List<Map<String, dynamic>>> getAllOwners() async {
    try {
      print('[AdminFirestoreService] Fetching all owners from users table...');

      final response = await _supabase
          .from(_usersTable)
          .select()
          .eq('role', 'owner');

      final owners = response
          .map<Map<String, dynamic>>(
            (row) => {
              'id': row['id'],
              'uid': row['id'],
              'email': row['email'] ?? '',
              'displayName': row['email']?.split('@')[0] ?? '',
              ...row,
            },
          )
          .toList();

      print('[AdminFirestoreService] Found ${owners.length} owners');

      // If no owners found, try to get owners from restaurants table
      if (owners.isEmpty) {
        print(
          '[AdminFirestoreService] No owners found in users table, trying to get from restaurants...',
        );
        try {
          // Get unique owner IDs and emails from restaurants
          final restaurants = await _supabase
              .from(_restaurantsTable)
              .select('owner_id, owner_email')
              .limit(100);

          print(
            '[AdminFirestoreService] Found ${restaurants.length} restaurants',
          );

          final ownerMap = <String, Map<String, dynamic>>{};

          for (final restaurant in restaurants) {
            final ownerId = restaurant['owner_id'] as String? ?? '';
            final ownerEmail = restaurant['owner_email'] as String? ?? '';
            final restaurantId = restaurant['id'] as String? ?? '';

            // Use restaurant ID as fallback key if owner_id is empty
            final uniqueKey = ownerId.isNotEmpty
                ? ownerId
                : (ownerEmail.isNotEmpty
                      ? ownerEmail
                      : (restaurantId.isNotEmpty
                            ? 'restaurant_$restaurantId'
                            : null));

            if (uniqueKey == null) {
              print(
                '[AdminFirestoreService] Skipping restaurant with no owner info: $restaurant',
              );
              continue;
            }

            if (ownerId.isNotEmpty) {
              // Try to get user info by ID
              try {
                final userInfo = await _supabase
                    .from(_usersTable)
                    .select('id, email, role')
                    .eq('id', ownerId)
                    .maybeSingle();

                if (userInfo != null) {
                  ownerMap[uniqueKey] = {
                    'id': userInfo['id'],
                    'uid': userInfo['id'],
                    'email': userInfo['email'] ?? ownerEmail,
                    'displayName': (userInfo['email'] ?? ownerEmail)
                        .toString()
                        .split('@')[0],
                    'role': userInfo['role'] ?? 'owner',
                    ...userInfo,
                  };
                } else {
                  // User doesn't exist in users table, create a minimal entry
                  ownerMap[uniqueKey] = {
                    'id': ownerId,
                    'uid': ownerId,
                    'email': ownerEmail.isNotEmpty
                        ? ownerEmail
                        : 'unknown@example.com',
                    'displayName': ownerEmail.isNotEmpty
                        ? ownerEmail.split('@')[0]
                        : 'Unknown',
                    'role': 'owner',
                  };
                }
              } catch (userError) {
                print(
                  '[AdminFirestoreService] Error getting user $ownerId: $userError',
                );
                // Create minimal entry
                ownerMap[uniqueKey] = {
                  'id': ownerId,
                  'uid': ownerId,
                  'email': ownerEmail.isNotEmpty
                      ? ownerEmail
                      : 'unknown@example.com',
                  'displayName': ownerEmail.isNotEmpty
                      ? ownerEmail.split('@')[0]
                      : 'Unknown',
                  'role': 'owner',
                };
              }
            } else if (ownerEmail.isNotEmpty) {
              // Only email available, try to find user by email first
              try {
                final userInfo = await _supabase
                    .from(_usersTable)
                    .select('id, email, role')
                    .eq('email', ownerEmail)
                    .maybeSingle();

                if (userInfo != null) {
                  final userId = userInfo['id'] as String;
                  ownerMap[uniqueKey] = {
                    'id': userId,
                    'uid': userId,
                    'email': userInfo['email'] ?? ownerEmail,
                    'displayName': (userInfo['email'] ?? ownerEmail)
                        .toString()
                        .split('@')[0],
                    'role': userInfo['role'] ?? 'owner',
                    ...userInfo,
                  };
                } else {
                  // User doesn't exist in users table, create entry using email as ID
                  // This allows admin to select the owner even if they don't have a user account yet
                  print(
                    '[AdminFirestoreService] Creating owner entry from email: $ownerEmail',
                  );
                  ownerMap[uniqueKey] = {
                    'id': ownerEmail, // Use email as ID temporarily
                    'uid': ownerEmail,
                    'email': ownerEmail,
                    'displayName': ownerEmail.split('@')[0],
                    'role': 'owner',
                    'hasRestaurant':
                        true, // Flag to indicate this owner has a restaurant
                  };
                }
              } catch (emailError) {
                print(
                  '[AdminFirestoreService] Error getting user by email $ownerEmail: $emailError',
                );
                // Create entry anyway using email
                ownerMap[uniqueKey] = {
                  'id': ownerEmail,
                  'uid': ownerEmail,
                  'email': ownerEmail,
                  'displayName': ownerEmail.split('@')[0],
                  'role': 'owner',
                  'hasRestaurant': true,
                };
              }
            }
          }

          final ownersFromRestaurants = ownerMap.values.toList();
          print(
            '[AdminFirestoreService] Found ${ownersFromRestaurants.length} owners from restaurants',
          );

          if (ownersFromRestaurants.isNotEmpty) {
            return ownersFromRestaurants;
          }
        } catch (restaurantError) {
          print(
            '[AdminFirestoreService] Error getting owners from restaurants: $restaurantError',
          );
        }
      }

      return owners;
    } catch (e) {
      print('[AdminFirestoreService] Error getting owners: $e');

      // Check if it's an RLS error
      if (e.toString().contains('42501') ||
          e.toString().contains('row-level security') ||
          e.toString().contains('RLS')) {
        throw Exception(
          'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول users.\n\n'
          'يجب إضافة سياسة SELECT للمستخدمين ذوي دور "admin" في Supabase.\n\n'
          'افتح Supabase SQL Editor والصق:\n\n'
          'CREATE POLICY "Allow admin to select users"\n'
          'ON "public"."users"\n'
          'FOR SELECT\n'
          'TO authenticated\n'
          'USING (\n'
          '  EXISTS (\n'
          '    SELECT 1 FROM users\n'
          '    WHERE users.id = auth.uid()\n'
          '    AND users.role = \'admin\'\n'
          '  )\n'
          ');\n\n'
          'أو من خلال Supabase Dashboard:\n'
          '1. اذهب إلى Table Editor > users > Policies\n'
          '2. أضف سياسة SELECT للمستخدمين ذوي role = \'admin\'',
        );
      }

      throw Exception('فشل في جلب الملاك: $e');
    }
  }

  Future<Map<String, dynamic>?> getOwnerByEmail(String email) async {
    try {
      final response = await _supabase
          .from(_usersTable)
          .select()
          .eq('role', 'owner')
          .eq('email', email)
          .limit(1);

      if (response.isEmpty) return null;

      final row = response[0];
      return {
        'id': row['id'],
        'uid': row['id'],
        'email': row['email'] ?? '',
        'displayName': row['email']?.split('@')[0] ?? '',
        ...row,
      };
    } catch (e) {
      throw Exception('Failed to get owner by email: $e');
    }
  }
}
