import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';

class LocationSupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _governoratesTable = 'governorates';
  static const String _citiesTable = 'cities';

  /// Initialize missing cities for governorates
  Future<void> initializeMissingCities() async {
    // Default cities per governorate
    const Map<String, List<String>> defaultCities = {
      'دمشق': ['المزة', 'المالكي', 'البرامكة'],
      'ريف دمشق': ['جرمانا', 'دوما', 'صحنايا'],
      'حلب': ['الجميلية', 'السليمانية'],
      'حمص': ['الزهراء', 'الوعر'],
      'حماة': ['المدينة', 'السوق'],
      'اللاذقية': ['الصليبة', 'المشروع السابع'],
      'طرطوس': ['المدينة', 'بانياس'],
    };

    // 1️⃣ جلب كل المحافظات
    final govsRes = await _supabase.from(_governoratesTable).select('name');

    final governorates = (govsRes as List)
        .map((e) => e['name'] as String)
        .toList();

    // 2️⃣ جلب كل المدن
    final citiesRes = await _supabase
        .from(_citiesTable)
        .select('governorate, name');

    final existingCities = <String, Set<String>>{};

    for (final row in citiesRes as List) {
      final gov = row['governorate'];
      final city = row['name'];

      existingCities.putIfAbsent(gov, () => <String>{});
      existingCities[gov]!.add(city);
    }

    // 3️⃣ إضافة المدن الناقصة
    for (final gov in governorates) {
      final defaultGovCities = defaultCities[gov] ?? [];

      for (final city in defaultGovCities) {
        final alreadyExists = existingCities[gov]?.contains(city) ?? false;

        if (!alreadyExists) {
          await _supabase.from(_citiesTable).insert({
            'governorate': gov,
            'name': city,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    print('[LocationSupabaseService] Missing cities initialized');
  }

  /// Initialize default governorates and cities (first-time setup)
  Future<void> initializeDefaultLocations() async {
    // Debug: Check current user and role
    try {
      final currentUser = _supabase.auth.currentUser;
      print(
        '[LocationSupabaseService] Current user: ${currentUser?.id}, email: ${currentUser?.email}',
      );

      if (currentUser != null) {
        var userDoc = await _supabase
            .from('users')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        print(
          '[LocationSupabaseService] User role from database: ${userDoc?['role']}',
        );

        // If user document doesn't exist, try to create it with admin role
        if (userDoc == null) {
          print(
            '[LocationSupabaseService] ⚠️ User document not found. Attempting to create admin user document...',
          );
          try {
            final userData = {
              'id': currentUser.id,
              'email': currentUser.email ?? '',
              'password':
                  'temp_password', // Required field, but not used for admin
              'role': 'admin',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            };

            try {
              await _supabase.from('users').insert(userData);
              print(
                '[LocationSupabaseService] ✅ Admin user document created successfully',
              );
            } catch (insertError) {
              // If duplicate key error, the user exists - try to update role
              if (insertError.toString().contains('23505') ||
                  insertError.toString().contains('duplicate key')) {
                print(
                  '[LocationSupabaseService] User document exists (duplicate key). Attempting to update role to admin...',
                );
                try {
                  await _supabase
                      .from('users')
                      .update({
                        'role': 'admin',
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', currentUser.id);
                  print(
                    '[LocationSupabaseService] ✅ User role updated to admin',
                  );
                } catch (updateError) {
                  print(
                    '[LocationSupabaseService] ⚠️ Failed to update user role (may be RLS): $updateError',
                  );
                  // Continue - RLS policy will check role when inserting governorates
                }
              } else {
                // For other errors, rethrow
                rethrow;
              }
            }

            // Try to fetch the document again after create/update
            // Note: This may still return null if RLS blocks read, but that's OK
            // The RLS policy on governorates will check the role when we try to insert
            userDoc = await _supabase
                .from('users')
                .select('role')
                .eq('id', currentUser.id)
                .maybeSingle();
            print(
              '[LocationSupabaseService] User role after create/update: ${userDoc?['role']}',
            );

            // If still null (RLS blocking read), that's OK - we'll continue
            // The RLS policy on governorates will verify the role when inserting
            if (userDoc == null) {
              print(
                '[LocationSupabaseService] ⚠️ Cannot read user document (RLS may be blocking). Continuing - RLS policy will verify admin role on insert.',
              );
            }
          } catch (createError) {
            print(
              '[LocationSupabaseService] ❌ Unexpected error with user document: $createError',
            );
            // Don't throw - continue and let RLS policy on governorates handle the check
            // If user is not admin, RLS will block the insert and throw appropriate error
          }
        }
      } else {
        print('[LocationSupabaseService] ⚠️ No authenticated user found!');
        throw Exception('يجب تسجيل الدخول أولاً');
      }
    } catch (e) {
      print('[LocationSupabaseService] Error checking user: $e');
    }

    const Map<String, List<String>> defaultLocations = {
      'دمشق': [
        'المزة',
        'المالكي',
        'البرامكة',
        'العباسيين',
        'الشعلان',
        'الميدان',
        'الصالحية',
        'القصاع',
        'باب توما',
        'باب شرقي',
        'القدسية',
        'جوبر',
        'الزاهرة',
        'الروضة',
        'كفرسوسة',
      ],
      'ريف دمشق': [
        'جرمانا',
        'دوما',
        'صحنايا',
        'داريا',
        'معضمية الشام',
        'السيدة زينب',
        'السيدة رقية',
        'كفر بطنا',
        'عين ترما',
        'زبدين',
        'قطنا',
        'الزبداني',
        'بلودان',
        'بصرى',
        'نوى',
        'إزرع',
        'التل',
        'عربين',
        'حرستا',
        'يبرود',
        'النبك',
        'القدموس',
      ],
      'حلب': [
        'الجميلية',
        'السليمانية',
        'العزيزية',
        'السكري',
        'الميدان',
        'باب الفرج',
        'باب النصر',
        'باب الحديد',
        'الشيخ مقصود',
        'السفيرة',
        'منبج',
        'الباب',
        'دير حافر',
        'عفرين',
        'عندان',
        'جبل سمعان',
        'الأتارب',
        'حريتان',
        'تل رفعت',
      ],
      'حمص': [
        'الزهراء',
        'الوعر',
        'الخالدية',
        'الغوطة',
        'الكرامة',
        'الرستن',
        'تلبيسة',
        'القصير',
        'تدمر',
        'المخرم',
        'شين',
        'القريتين',
        'المحطة',
      ],
      'حماة': [
        'المدينة',
        'السوق',
        'المشرفة',
        'مصياف',
        'السقيلبية',
        'اللطامنة',
        'كفر زيتا',
        'كفر نبودة',
        'مورك',
        'سلمية',
        'طيبة الإمام',
        'كفرطاب',
        'القدموس',
      ],
      'اللاذقية': [
        'الصليبة',
        'المشروع السابع',
        'الرمل الشمالي',
        'الرمل الجنوبي',
        'جبلة',
        'القرداحة',
        'الحفة',
        'سلحب',
        'كسب',
        'بستان الباشا',
        'القدموس',
      ],
      'طرطوس': [
        'المدينة',
        'بانياس',
        'صافيتا',
        'دريكيش',
        'الشيخ بدر',
        'القدموس',
        'الخريبة',
        'الرادو',
        'حمام واصل',
      ],
      'إدلب': [
        'إدلب',
        'معرة النعمان',
        'أريحا',
        'جسر الشغور',
        'حارم',
        'سرمين',
        'معرتمصرين',
        'كفر تخاريم',
        'دانا',
        'بينش',
      ],
      'دير الزور': [
        'دير الزور',
        'البوكمال',
        'الميادين',
        'القورية',
        'عشارة',
        'صبيخان',
        'السبع بيار',
      ],
      'الحسكة': [
        'الحسكة',
        'القامشلي',
        'رأس العين',
        'عامودا',
        'ديريك',
        'تل تمر',
        'شددي',
        'اليعربية',
      ],
      'الرقة': ['الرقة', 'تل أبيض', 'المسكنة', 'الثورة', 'الطبقة', 'معدان'],
      'السويداء': [
        'السويداء',
        'شهبا',
        'صلخد',
        'قنوات',
        'أزرع',
        'المشنف',
        'صلخد',
        'عرمان',
      ],
      'درعا': [
        'درعا',
        'إزرع',
        'نوى',
        'الشيخ مسكين',
        'داعل',
        'طفس',
        'جاسم',
        'إنخل',
        'المسمية',
      ],
      'القنيطرة': ['القنيطرة', 'فيق', 'البطيحة', 'خان أرنبة', 'مسعدة'],
    };

    // 1️⃣ جلب المحافظات الموجودة
    final govRes = await _supabase.from(_governoratesTable).select('name');

    final existingGovs = (govRes as List)
        .map((e) => e['name'] as String)
        .toSet();

    // 2️⃣ إدخال المحافظات الناقصة
    for (final gov in defaultLocations.keys) {
      if (!existingGovs.contains(gov)) {
        try {
          await _supabase.from(_governoratesTable).insert({
            'name': gov,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          // Check if it's an RLS error (code 42501)
          if (e is PostgrestException && e.code == '42501') {
            print(
              '[LocationSupabaseService] RLS Error Details: ${e.message}, Code: ${e.code}',
            );
            throw Exception(
              'خطأ في صلاحيات قاعدة البيانات (RLS).\n\n'
              'تأكد من أن السياسة تحتوي على التعريف التالي:\n\n'
              'FOR INSERT:\n'
              'WITH CHECK (\n'
              '  EXISTS (\n'
              '    SELECT 1 FROM users\n'
              '    WHERE users.id = auth.uid()\n'
              '    AND users.role = \'admin\'\n'
              '  )\n'
              ')\n\n'
              '1. افتح Supabase Dashboard\n'
              '2. اذهب إلى Table Editor > governorates > Policies\n'
              '3. افتح سياسة INSERT و تأكد من التعريف أعلاه\n'
              '4. كرر نفس الخطوات لجدول cities',
            );
          }
          // Also check string representation for RLS errors
          if (e.toString().contains('42501') ||
              e.toString().contains('row-level security')) {
            throw Exception(
              'خطأ في صلاحيات قاعدة البيانات: يجب تكوين Row-Level Security (RLS) في Supabase للسماح للمستخدمين ذوي دور "admin" بإدراج المحافظات والمدن.\n\n'
              'يرجى إضافة سياسات RLS في Supabase:\n'
              '1. افتح Supabase Dashboard\n'
              '2. اذهب إلى Table Editor > governorates > Policies\n'
              '3. أضف سياسة INSERT للمستخدمين ذوي role = \'admin\'\n'
              '4. كرر نفس الخطوات لجدول cities',
            );
          }
          rethrow;
        }
      }
    }

    // 3️⃣ جلب المدن الموجودة
    final cityRes = await _supabase
        .from(_citiesTable)
        .select('governorate, name');

    final existingCities = <String, Set<String>>{};

    for (final row in cityRes as List) {
      final gov = row['governorate'];
      final city = row['name'];

      existingCities.putIfAbsent(gov, () => <String>{});
      existingCities[gov]!.add(city);
    }

    // 4️⃣ إدخال المدن الناقصة
    for (final entry in defaultLocations.entries) {
      final gov = entry.key;
      final cities = entry.value;

      for (final city in cities) {
        final exists = existingCities[gov]?.contains(city) ?? false;

        if (!exists) {
          try {
            await _supabase.from(_citiesTable).insert({
              'governorate': gov,
              'name': city,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            // Check if it's an RLS error (code 42501)
            if (e is PostgrestException && e.code == '42501') {
              print(
                '[LocationSupabaseService] RLS Error Details (cities): ${e.message}, Code: ${e.code}',
              );
              throw Exception(
                'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول cities.\n\n'
                'تأكد من أن السياسة تحتوي على التعريف التالي:\n\n'
                'FOR INSERT:\n'
                'WITH CHECK (\n'
                '  EXISTS (\n'
                '    SELECT 1 FROM users\n'
                '    WHERE users.id = auth.uid()\n'
                '    AND users.role = \'admin\'\n'
                '  )\n'
                ')\n\n'
                '1. افتح Supabase Dashboard\n'
                '2. اذهب إلى Table Editor > cities > Policies\n'
                '3. افتح سياسة INSERT و تأكد من التعريف أعلاه',
              );
            }
            // Also check string representation for RLS errors
            if (e.toString().contains('42501') ||
                e.toString().contains('row-level security')) {
              throw Exception(
                'خطأ في صلاحيات قاعدة البيانات: يجب تكوين Row-Level Security (RLS) في Supabase للسماح للمستخدمين ذوي دور "admin" بإدراج المحافظات والمدن.\n\n'
                'يرجى إضافة سياسات RLS في Supabase:\n'
                '1. افتح Supabase Dashboard\n'
                '2. اذهب إلى Table Editor > cities > Policies\n'
                '3. أضف سياسة INSERT للمستخدمين ذوي role = \'admin\'',
              );
            }
            rethrow;
          }
        }
      }
    }

    print('[LocationSupabaseService] Default locations initialized');
  }

  /// Get all governorates
  Future<List<String>> getGovernorates() async {
    try {
      final res = await _supabase
          .from(_governoratesTable)
          .select('name')
          .order('name');

      return (res as List).map((e) => e['name'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get cities by governorate
  Future<List<String>> getCitiesByGovernorate(String governorate) async {
    try {
      final res = await _supabase
          .from(_citiesTable)
          .select('name')
          .eq('governorate', governorate.trim())
          .order('name');

      return (res as List).map((e) => e['name'] as String).toSet().toList();
    } catch (e) {
      return [];
    }
  }

  /// Get cities grouped by governorate
  Future<Map<String, List<String>>> getCitiesByGovernorateMap() async {
    try {
      final res = await _supabase
          .from(_citiesTable)
          .select('governorate, name');

      final Map<String, Set<String>> temp = {};

      for (final row in res as List) {
        final gov = row['governorate'];
        final city = row['name'];

        temp.putIfAbsent(gov, () => <String>{});
        temp[gov]!.add(city);
      }

      return temp.map((k, v) => MapEntry(k, v.toList()..sort()));
    } catch (e) {
      return {};
    }
  }

  /// Add governorate
  Future<void> addGovernorate(String name) async {
    if (name.trim().isEmpty) {
      throw Exception('اسم المحافظة لا يمكن أن يكون فارغاً');
    }

    final existing = await _supabase
        .from(_governoratesTable)
        .select('id')
        .eq('name', name.trim());

    if ((existing as List).isNotEmpty) {
      throw Exception('المحافظة موجودة بالفعل');
    }

    await _supabase.from(_governoratesTable).insert({
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Update governorate
  Future<void> updateGovernorate(String oldName, String newName) async {
    if (newName.trim().isEmpty) {
      throw Exception('اسم المحافظة لا يمكن أن يكون فارغاً');
    }

    await _supabase
        .from(_governoratesTable)
        .update({
          'name': newName.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('name', oldName);

    await _supabase
        .from(_citiesTable)
        .update({
          'governorate': newName.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('governorate', oldName);
  }

  /// Delete governorate
  Future<void> deleteGovernorate(String name) async {
    final cities = await _supabase
        .from(_citiesTable)
        .select('id')
        .eq('governorate', name);

    if ((cities as List).isNotEmpty) {
      throw Exception('لا يمكن حذف المحافظة لأنها تحتوي على مدن');
    }

    await _supabase.from(_governoratesTable).delete().eq('name', name);
  }

  /// Add city
  Future<void> addCity(String governorate, String cityName) async {
    if (cityName.trim().isEmpty || governorate.trim().isEmpty) {
      throw Exception('البيانات غير مكتملة');
    }

    final existing = await _supabase
        .from(_citiesTable)
        .select('id')
        .eq('governorate', governorate)
        .eq('name', cityName.trim());

    if ((existing as List).isNotEmpty) {
      throw Exception('المدينة موجودة بالفعل');
    }

    await _supabase.from(_citiesTable).insert({
      'governorate': governorate,
      'name': cityName.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Update city
  Future<void> updateCity(
    String governorate,
    String oldCity,
    String newCity,
  ) async {
    await _supabase
        .from(_citiesTable)
        .update({
          'name': newCity.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('governorate', governorate)
        .eq('name', oldCity);
  }

  /// Delete city
  Future<void> deleteCity(String governorate, String cityName) async {
    // Check if city is used by restaurants
    try {
      final restaurants = await _supabase
          .from('restaurants')
          .select('id')
          .eq('governorate', governorate)
          .eq('city', cityName);

      if ((restaurants as List).isNotEmpty) {
        throw Exception('المدينة مستخدمة من قبل مطاعم');
      }
    } catch (e) {
      // If the error is about table/column not existing, log it but continue
      // (maybe restaurants table doesn't exist yet or has different structure)
      if (e.toString().contains('does not exist') ||
          e.toString().contains('column') ||
          e.toString().contains('relation')) {
        print(
          '[LocationSupabaseService] ⚠️ Could not check restaurants table: $e. Continuing with delete...',
        );
        // Continue with delete - if restaurants table doesn't exist, no restaurants can use this city
      } else {
        // For other errors (like RLS), rethrow
        rethrow;
      }
    }

    // Delete the city
    try {
      await _supabase
          .from(_citiesTable)
          .delete()
          .eq('governorate', governorate)
          .eq('name', cityName);
    } catch (e) {
      // Check if it's an RLS error (code 42501)
      if (e is PostgrestException && e.code == '42501') {
        print(
          '[LocationSupabaseService] RLS Error Details (delete city): ${e.message}, Code: ${e.code}',
        );
        throw Exception(
          'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول cities.\n\n'
          'تأكد من أن السياسة DELETE تحتوي على التعريف التالي:\n\n'
          'FOR DELETE:\n'
          'USING (\n'
          '  EXISTS (\n'
          '    SELECT 1 FROM users\n'
          '    WHERE users.id = auth.uid()\n'
          '    AND users.role = \'admin\'\n'
          '  )\n'
          ')\n\n'
          '1. افتح Supabase Dashboard\n'
          '2. اذهب إلى Table Editor > cities > Policies\n'
          '3. افتح سياسة DELETE و تأكد من التعريف أعلاه',
        );
      }
      // Also check string representation for RLS errors
      if (e.toString().contains('42501') ||
          e.toString().contains('row-level security')) {
        throw Exception(
          'خطأ في صلاحيات قاعدة البيانات (RLS) لجدول cities.\n\n'
          'تأكد من وجود سياسة DELETE للمستخدمين ذوي role = \'admin\' في جدول cities.',
        );
      }
      rethrow;
    }
  }
}
