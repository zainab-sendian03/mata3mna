import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing locations (governorates and cities) in Firestore
/// Allows admin to add, edit, and delete locations
class LocationFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _governoratesCollection = 'governorates';
  static const String _citiesCollection = 'cities';

  LocationFirestoreService();

  /// Get all governorates
  Future<List<String>> getGovernorates() async {
    try {
      final snapshot = await _firestore
          .collection(_governoratesCollection)
          .get();

      final governorates = snapshot.docs
          .map((doc) => doc.data()['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Sort alphabetically
      governorates.sort();
      return governorates;
    } catch (e) {
      // ignore: avoid_print
      print('[LocationFirestoreService] Error loading governorates: $e');
      return [];
    }
  }

  /// Get all cities for a specific governorate
  Future<List<String>> getCitiesByGovernorate(String governorate) async {
    try {
      final snapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: governorate)
          .get();

      // Use a Set to automatically remove duplicates
      final citiesSet = <String>{};
      for (final doc in snapshot.docs) {
        final name = doc.data()['name'] as String? ?? '';
        if (name.isNotEmpty) {
          citiesSet.add(name);
        }
      }

      // Convert to list and sort alphabetically
      final cities = citiesSet.toList()..sort();
      return cities;
    } catch (e) {
      // ignore: avoid_print
      print(
        '[LocationFirestoreService] Error loading cities for $governorate: $e',
      );
      return [];
    }
  }

  /// Get all cities grouped by governorate
  Future<Map<String, List<String>>> getCitiesByGovernorateMap() async {
    try {
      final governorates = await getGovernorates();
      final Map<String, List<String>> result = {};

      for (final governorate in governorates) {
        try {
          final cities = await getCitiesByGovernorate(governorate);
          result[governorate] = cities;
        } catch (e) {
          // ignore: avoid_print
          print(
            '[LocationFirestoreService] Error loading cities for $governorate: $e',
          );
          result[governorate] = [];
        }
      }

      return result;
    } catch (e) {
      // ignore: avoid_print
      print('[LocationFirestoreService] Error loading cities map: $e');
      return {};
    }
  }

  /// Add a new governorate
  Future<void> addGovernorate(String name) async {
    if (name.trim().isEmpty) {
      throw Exception('اسم المحافظة لا يمكن أن يكون فارغاً');
    }

    try {
      // Check if governorate already exists
      final existingSnapshot = await _firestore
          .collection(_governoratesCollection)
          .where('name', isEqualTo: name.trim())
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        throw Exception('المحافظة موجودة بالفعل');
      }

      await _firestore.collection(_governoratesCollection).add({
        'name': name.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e.toString().contains('موجودة بالفعل')) {
        rethrow;
      }
      throw Exception('حدث خطأ أثناء إضافة المحافظة: ${e.toString()}');
    }
  }

  /// Update a governorate name
  Future<void> updateGovernorate(String oldName, String newName) async {
    if (newName.trim().isEmpty) {
      throw Exception('اسم المحافظة لا يمكن أن يكون فارغاً');
    }

    try {
      // Find the governorate document
      final snapshot = await _firestore
          .collection(_governoratesCollection)
          .where('name', isEqualTo: oldName)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('المحافظة غير موجودة');
      }

      // Check if new name already exists
      final existingSnapshot = await _firestore
          .collection(_governoratesCollection)
          .where('name', isEqualTo: newName.trim())
          .get();

      if (existingSnapshot.docs.isNotEmpty &&
          existingSnapshot.docs.first.id != snapshot.docs.first.id) {
        throw Exception('المحافظة موجودة بالفعل');
      }

      // Update governorate name
      await snapshot.docs.first.reference.update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update all cities that reference this governorate
      final citiesSnapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: oldName)
          .get();

      final batch = _firestore.batch();
      for (final cityDoc in citiesSnapshot.docs) {
        batch.update(cityDoc.reference, {
          'governorate': newName.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      if (e.toString().contains('غير موجودة') ||
          e.toString().contains('موجودة بالفعل')) {
        rethrow;
      }
      throw Exception('حدث خطأ أثناء تحديث المحافظة: ${e.toString()}');
    }
  }

  /// Delete a governorate
  Future<void> deleteGovernorate(String name) async {
    try {
      // Check if governorate exists
      final snapshot = await _firestore
          .collection(_governoratesCollection)
          .where('name', isEqualTo: name)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('المحافظة غير موجودة');
      }

      // Check if there are cities in this governorate
      final citiesSnapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: name)
          .get();

      if (citiesSnapshot.docs.isNotEmpty) {
        throw Exception(
          'لا يمكن حذف المحافظة لأنها تحتوي على مدن. يرجى حذف المدن أولاً',
        );
      }

      // Delete the governorate
      await snapshot.docs.first.reference.delete();
    } catch (e) {
      if (e.toString().contains('غير موجودة') ||
          e.toString().contains('تحتوي على مدن')) {
        rethrow;
      }
      throw Exception('حدث خطأ أثناء حذف المحافظة: ${e.toString()}');
    }
  }

  /// Add a new city to a governorate
  Future<void> addCity(String governorate, String cityName) async {
    if (cityName.trim().isEmpty) {
      throw Exception('اسم المدينة لا يمكن أن يكون فارغاً');
    }

    if (governorate.trim().isEmpty) {
      throw Exception('يجب تحديد المحافظة');
    }

    try {
      // Check if governorate exists
      final governorateSnapshot = await _firestore
          .collection(_governoratesCollection)
          .where('name', isEqualTo: governorate)
          .get();

      if (governorateSnapshot.docs.isEmpty) {
        throw Exception('المحافظة غير موجودة');
      }

      // Check if city already exists in this governorate
      final existingSnapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: governorate)
          .where('name', isEqualTo: cityName.trim())
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        throw Exception('المدينة موجودة بالفعل في هذه المحافظة');
      }

      await _firestore.collection(_citiesCollection).add({
        'governorate': governorate,
        'name': cityName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e.toString().contains('موجودة بالفعل') ||
          e.toString().contains('غير موجودة') ||
          e.toString().contains('يجب تحديد')) {
        rethrow;
      }
      throw Exception('حدث خطأ أثناء إضافة المدينة: ${e.toString()}');
    }
  }

  /// Update a city name
  Future<void> updateCity(
    String governorate,
    String oldCityName,
    String newCityName,
  ) async {
    if (newCityName.trim().isEmpty) {
      throw Exception('اسم المدينة لا يمكن أن يكون فارغاً');
    }

    try {
      // Find the city document
      final snapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: governorate)
          .where('name', isEqualTo: oldCityName)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('المدينة غير موجودة');
      }

      // Check if new name already exists in this governorate
      final existingSnapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: governorate)
          .where('name', isEqualTo: newCityName.trim())
          .get();

      if (existingSnapshot.docs.isNotEmpty &&
          existingSnapshot.docs.first.id != snapshot.docs.first.id) {
        throw Exception('المدينة موجودة بالفعل في هذه المحافظة');
      }

      // Update city name
      await snapshot.docs.first.reference.update({
        'name': newCityName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e.toString().contains('غير موجودة') ||
          e.toString().contains('موجودة بالفعل')) {
        rethrow;
      }
      throw Exception('حدث خطأ أثناء تحديث المدينة: ${e.toString()}');
    }
  }

  /// Delete a city
  Future<void> deleteCity(String governorate, String cityName) async {
    try {
      // Find the city document
      final snapshot = await _firestore
          .collection(_citiesCollection)
          .where('governorate', isEqualTo: governorate)
          .where('name', isEqualTo: cityName)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('المدينة غير موجودة');
      }

      // Check if there are restaurants using this city
      final restaurantsSnapshot = await _firestore
          .collection('restaurants')
          .where('governorate', isEqualTo: governorate)
          .where('city', isEqualTo: cityName)
          .get();

      if (restaurantsSnapshot.docs.isNotEmpty) {
        throw Exception(
          'لا يمكن حذف المدينة لأنها مستخدمة من قبل مطاعم. يرجى تغيير موقع المطاعم أولاً',
        );
      }

      // Delete the city
      await snapshot.docs.first.reference.delete();
    } catch (e) {
      if (e.toString().contains('غير موجودة') ||
          e.toString().contains('مستخدمة من قبل')) {
        rethrow;
      }
      throw Exception('حدث خطأ أثناء حذف المدينة: ${e.toString()}');
    }
  }

  /// Initialize default governorates and cities (for first-time setup)
  /// This can be called once to migrate from hardcoded data to Firestore
  Future<void> initializeDefaultLocations() async {
    try {
      final defaultGovernorates = [
        'حلب',
        'دمشق',
        'دير الزور',
        'حماة',
        'الحسكة',
        'حمص',
        'إدلب',
        'اللاذقية',
        'القنيطرة',
        'الرقة',
        'ريف دمشق',
        'السويداء',
        'طرطوس',
        'درعا',
      ];

      final defaultCitiesByGovernorate = {
        "حلب": [
          "حلب",
          "جبل سمعان",
          "عين العرب",
          "الأتارب",
          "عفرين",
          "الباب",
          "دير حافر",
          "السفيرة",
          "أعزاز",
          "جرابلس",
          "منبج",
          "القباسيين",
        ],
        "دمشق": [
          "المزة",
          "المالكي",
          "البرامكة",
          "القنوات",
          "الميدان",
          "الصالحية",
          "الشعلان",
          "الحميدية",
          "باب توما",
          "القصاع",
          "ركن الدين",
          "كفرسوسة",
          "باب شرقي",
          "القدم",
          "المهاجرين",
        ],
        "درعا": ["درعا", "الصنمين", "نوى", "إزرع", "بصرى", "بصرى الشام"],
        "دير الزور": ["دير الزور", "الميادين", "البوكمال"],
        "حماة": ["حماة", "السقيلبية", "سلحب", "مصياف", "محردة", "السلمية"],
        "الحسكة": ["الحسكة", "القامشلي", "رأس العين", "المالكية", "الشدادي"],
        "حمص": ["حمص", "تدمر", "المخرم", "تلكلخ", "الرستن", "القصير", "تلدو"],
        "إدلب": ["إدلب", "حارم", "جسر الشغور", "معرة النعمان", "خان شيخون"],
        "اللاذقية": ["اللاذقية", "جبلة", "القرداحة", "الحفة"],
        "القنيطرة": ["القنيطرة", "فيق"],
        "الرقة": ["الرقة", "الثورة", "تل أبيض"],
        "ريف دمشق": [
          "ريف دمشق",
          "القطيفة",
          "النبك",
          "مركز ريف دمشق",
          "التل",
          "داريا",
          "دوما",
          "قطنا",
          "يبرود",
          "الزبداني",
          "قدسيا",
        ],
        "السويداء": ["السويداء", "شهبا", "صلخد"],
        "طرطوس": [
          "طرطوس",
          "دريكيش",
          "بانياس",
          "القدموس",
          "الشيخ بدر",
          "صافيتا",
        ],
      };

      // Add governorates
      for (final governorate in defaultGovernorates) {
        final existing = await _firestore
            .collection(_governoratesCollection)
            .where('name', isEqualTo: governorate)
            .get();

        if (existing.docs.isEmpty) {
          await _firestore.collection(_governoratesCollection).add({
            'name': governorate,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Add cities
      for (final entry in defaultCitiesByGovernorate.entries) {
        final governorate = entry.key;
        final cities = entry.value;

        for (final city in cities) {
          try {
            final existing = await _firestore
                .collection(_citiesCollection)
                .where('governorate', isEqualTo: governorate)
                .where('name', isEqualTo: city)
                .get();

            if (existing.docs.isEmpty) {
              await _firestore.collection(_citiesCollection).add({
                'governorate': governorate,
                'name': city,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            // ignore: avoid_print
            print(
              '[LocationFirestoreService] Error adding city $city to $governorate: $e',
            );
            // Continue with next city
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print(
        '[LocationFirestoreService] Error in initializeDefaultLocations: $e',
      );
      throw Exception(
        'حدث خطأ أثناء تهيئة المناطق الافتراضية: ${e.toString()}',
      );
    }
  }
}
