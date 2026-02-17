import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/features/home/data/services/menu_firestore_service.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/location_firestore_service.dart';

class CustomerViewController extends GetxController {
  final MenuSupabaseService _menuService = Get.find<MenuSupabaseService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();
  final RestaurantSupabaseService _restaurantService =
      Get.find<RestaurantSupabaseService>();
  final LocationSupabaseService _locationService =
      Get.find<LocationSupabaseService>();

  // Observable state
  final RxBool isLoading = false.obs;
  final RxBool hasReceivedData = false.obs;
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> allMenuItems =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredRestaurants =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingRestaurants =
      true.obs; // Start true so UI shows loading until first load
  // Map of ownerId to list of matching menu items
  final RxMap<String, List<Map<String, dynamic>>> restaurantMatchingItems =
      <String, List<Map<String, dynamic>>>{}.obs;

  // Stream subscriptions management
  StreamSubscription<List<Map<String, dynamic>>>? _menuItemsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _restaurantsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _searchMenuItemsSubscription;
  String _currentSearchQuery =
      ''; // Track current search to ignore stale results
  Timer? _searchDebounceTimer; // Debounce timer for search

  // Shared state for search results
  final Map<String, Map<String, dynamic>> _restaurantsFromName = {};
  final Map<String, Map<String, dynamic>> _allRestaurantsMap = {};
  final Map<String, Map<String, dynamic>> _allRestaurantsCache =
      {}; // Cache by owner_id
  final Map<String, Map<String, dynamic>> _allRestaurantsByRestaurantId =
      {}; // Cache by restaurant id so item restaurant_id can resolve
  bool _hasItemMatchesForCurrentQuery =
      false; // True when current query matched at least one menu item

  // Filter state
  final Rxn<String> selectedGovernorate = Rxn<String>();
  final Rxn<String> selectedCity = Rxn<String>();

  // Categories for menu organization
  final List<String> categories = [
    'جميع العناصر',
    'المقبلات',
    'الأطباق الرئيسية',
    'الحلويات',
    'المشروبات',
  ];

  // Governorates and cities data (loaded from Firestore)
  final RxList<String> governorates = <String>[].obs;
  final RxMap<String, List<String>> citiesByGovernorate =
      <String, List<String>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLocations();
    loadAllMenuItems();
    _loadFilteredRestaurants();
    print('[CustomerViewController] Controller initialized');
  }

  @override
  void onClose() {
    try {
      _menuItemsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling menu items subscription: $e',
      );
    }
    _menuItemsSubscription = null;

    try {
      _restaurantsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling restaurants subscription: $e',
      );
    }
    _restaurantsSubscription = null;

    try {
      _searchMenuItemsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling search menu items subscription: $e',
      );
    }
    _searchMenuItemsSubscription = null;

    _searchDebounceTimer?.cancel();
    super.onClose();
  }

  /// Load governorates and cities from Firestore
  Future<void> _loadLocations() async {
    try {
      print('[CustomerViewController] Loading locations...');
      // Load governorates
      final loadedGovernorates = await _locationService.getGovernorates();
      print(
        '[CustomerViewController] Loaded ${loadedGovernorates.length} governorates',
      );

      // If no governorates exist, initialize default locations
      if (loadedGovernorates.isEmpty) {
        print(
          '[CustomerViewController] No governorates found, initializing default locations...',
        );
        await _locationService.initializeDefaultLocations();
        final reloadedGovernorates = await _locationService.getGovernorates();
        governorates.value = reloadedGovernorates;
        print(
          '[CustomerViewController] Initialized ${reloadedGovernorates.length} governorates',
        );
      } else {
        governorates.value = loadedGovernorates;
      }

      // Load cities grouped by governorate
      print('[CustomerViewController] Loading cities...');
      final loadedCitiesMap = await _locationService
          .getCitiesByGovernorateMap();
      citiesByGovernorate.value = loadedCitiesMap;
      print(
        '[CustomerViewController] Loaded cities for ${loadedCitiesMap.length} governorates',
      );
      for (final entry in loadedCitiesMap.entries) {
        print(
          '[CustomerViewController]   ${entry.key}: ${entry.value.length} cities',
        );
      }
    } catch (e) {
      print('[CustomerViewController] Error loading locations: $e');
      // Fallback to empty lists if loading fails
      governorates.value = [];
      citiesByGovernorate.value = {};
    }
  }

  void loadAllMenuItems() {
    if (!hasReceivedData.value) {
      isLoading.value = true;
    }

    // Cancel previous subscription to avoid duplicates (safely)
    try {
      _menuItemsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling previous subscription: $e',
      );
    }
    _menuItemsSubscription = null;

    print('[CustomerViewController] Starting menu items stream...');
    _menuItemsSubscription = _menuService.getAllMenuItemsStream().listen(
      (items) {
        print(
          '[CustomerViewController] Menu items stream updated: ${items.length} items',
        );

        // Group items by ownerId for debugging
        final itemsByOwner = <String, int>{};
        final itemsByRestaurant = <String, int>{};
        for (final item in items) {
          final ownerId = (item['ownerId'] as String? ?? '').trim();
          final restaurantName = (item['restaurantName'] as String? ?? '')
              .trim();

          if (ownerId.isNotEmpty) {
            itemsByOwner[ownerId] = (itemsByOwner[ownerId] ?? 0) + 1;
          }

          if (restaurantName.isNotEmpty) {
            itemsByRestaurant[restaurantName] =
                (itemsByRestaurant[restaurantName] ?? 0) + 1;
          }
        }

        print(
          '[CustomerViewController] Items by restaurant: ${itemsByOwner.length} restaurants',
        );
        for (final entry in itemsByOwner.entries) {
          final restaurantName =
              items.firstWhere(
                    (item) =>
                        (item['ownerId'] as String? ?? '').trim() == entry.key,
                    orElse: () => {},
                  )['restaurantName']
                  as String? ??
              'Unknown';
          print(
            '[CustomerViewController]   $restaurantName (ownerId: ${entry.key}): ${entry.value} items',
          );
        }

        // Update the observable list - this will trigger UI updates
        allMenuItems.value = items;
        hasReceivedData.value = true;
        isLoading.value = false;

        print(
          '[CustomerViewController] Menu items list updated in UI (allMenuItems.length = ${allMenuItems.length})',
        );
      },
      onError: (error) {
        print('[CustomerViewController] Error loading menu items: $error');
        print(
          '[CustomerViewController] Error stack trace: ${error.stackTrace}',
        );
        isLoading.value = false;
      },
    );
  }

  /// Normalize Arabic for search: variants to common form, remove diacritics, Arabic numerals to Western.
  String normalizeArabic(String text) {
    if (text.isEmpty) return text;
    // Diacritics and letter variants
    const Map<String, String> replacements = {
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ى': 'ي',
      'ة': 'ه',
      'ؤ': 'و',
      'ئ': 'ي',
      'ً': '',
      'ٌ': '',
      'ٍ': '',
      'َ': '',
      'ُ': '',
      'ِ': '',
      'ّ': '',
      'ْ': '',
    };
    for (final e in replacements.entries) {
      text = text.replaceAll(e.key, e.value);
    }
    // Arabic numerals (٠١٢٣٤٥٦٧٨٩) -> Western (0-9) so "مطعم ١" matches "مطعم 1"
    const String arabicNumerals = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(arabicNumerals[i], i.toString());
    }
    return text;
  }

  List<Map<String, dynamic>> getFilteredItems(int selectedCategoryIndex) {
    String currentCategory = categories[selectedCategoryIndex];

    List<Map<String, dynamic>> filtered = currentCategory == 'جميع العناصر'
        ? List.from(allMenuItems)
        : allMenuItems
              .where((item) => item['category'] == currentCategory)
              .toList();

    // Apply filters
    if (selectedGovernorate.value != null) {
      filtered = filtered.where((item) {
        final governorate = (item['governorate'] ?? '').toString();
        return governorate == selectedGovernorate.value;
      }).toList();
    }

    if (selectedCity.value != null) {
      filtered = filtered.where((item) {
        final city = (item['city'] ?? '').toString();
        return city == selectedCity.value;
      }).toList();
    }

    // Apply search query
    if (searchQuery.value.isNotEmpty) {
      filtered = filtered.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final description = (item['description'] ?? '')
            .toString()
            .toLowerCase();
        final restaurantName = (item['restaurantName'] ?? '')
            .toString()
            .toLowerCase();
        final governorates = (item['governorate'] ?? '')
            .toString()
            .toLowerCase();
        final citiesByGovernorate = (item['city'] ?? '')
            .toString()
            .toLowerCase();
        final query = normalizeArabic(searchQuery.value.toLowerCase());
        return name.contains(query) ||
            description.contains(query) ||
            restaurantName.contains(query) ||
            citiesByGovernorate.contains(query) ||
            governorates.contains(query);
      }).toList();
    }

    return filtered;
  }

  bool get hasActiveFilters {
    return selectedGovernorate.value != null || selectedCity.value != null;
  }

  void clearFilters() {
    selectedGovernorate.value = null;
    selectedCity.value = null;
    _loadFilteredRestaurants();
  }

  void setGovernorate(String? value) {
    selectedGovernorate.value = value;
    // Clear city if it's not in the new governorate's cities
    if (value != null && selectedCity.value != null) {
      final cities = citiesByGovernorate[value] ?? [];
      if (!cities.contains(selectedCity.value)) {
        selectedCity.value = null;
      }
    } else {
      selectedCity.value = null;
    }
    _loadFilteredRestaurants();
  }

  void setCity(String? value) {
    selectedCity.value = value;
    _loadFilteredRestaurants();
  }

  List<String> getAvailableCities() {
    if (selectedGovernorate.value == null) {
      print(
        '[CustomerViewController] getAvailableCities: No governorate selected',
      );
      return [];
    }
    final cities = citiesByGovernorate[selectedGovernorate.value] ?? [];
    print(
      '[CustomerViewController] getAvailableCities: Found ${cities.length} cities for ${selectedGovernorate.value}',
    );
    return cities;
  }

  Future<void> handleRefresh() async {
    isLoading.value = true;
    isLoadingRestaurants.value = true;

    print('[CustomerViewController] Refreshing data...');

    // Cancel existing subscriptions to force fresh data (safely)
    try {
      _menuItemsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling menu items subscription: $e',
      );
    }
    _menuItemsSubscription = null;

    try {
      _restaurantsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling restaurants subscription: $e',
      );
    }
    _restaurantsSubscription = null; // Set to null to force recreation

    // Clear current data to show loading state
    allMenuItems.clear();
    filteredRestaurants.clear();
    _allRestaurantsCache.clear(); // Clear cache too
    _restaurantsFromName.clear();
    _allRestaurantsMap.clear();

    // Wait a bit to show the refresh indicator
    await Future.delayed(Duration(milliseconds: 300));

    // Reload menu items - this will create a new stream subscription
    loadAllMenuItems();

    // Reload restaurants - this will create a new subscription since _restaurantsSubscription is null
    // This will force a fresh server fetch
    _loadFilteredRestaurants();

    // Wait a bit more to ensure data is loaded from server
    await Future.delayed(Duration(milliseconds: 1000));

    HapticFeedback.mediumImpact();
    isLoading.value = false;
    isLoadingRestaurants.value = false;

    // Show success message
    Get.snackbar(
      'نجح',
      'تم تحديث القوائم بنجاح',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
      margin: EdgeInsets.all(16),
    );
  }

  void handleLogout() {
    _cacheHelper.removeData(key: "userRole");
    _cacheHelper.removeData(key: "isLoggedIn");
    Get.offAllNamed(AppPages.root);
  }

  void clearSearch() {
    searchQuery.value = '';
    restaurantMatchingItems.clear();
    _loadFilteredRestaurants();
  }

  void updateSearchQuery(String value) {
    searchQuery.value = value;

    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();

    if (value.isEmpty) {
      restaurantMatchingItems.clear();
      _currentSearchQuery = '';
      _loadFilteredRestaurants();
      return;
    }

    restaurantMatchingItems.clear();
    // Don't clear filteredRestaurants here – wait until we have new results so UI never shows empty

    // Debounce search to avoid too many requests
    _searchDebounceTimer = Timer(Duration(milliseconds: 300), () {
      _loadFilteredRestaurants();
    });
  }

  // Get matching items for a specific restaurant
  List<Map<String, dynamic>> getMatchingItemsForRestaurant(String ownerId) {
    return restaurantMatchingItems[ownerId] ?? [];
  }

  /// Get unique categories for a specific restaurant
  List<String> getRestaurantCategories(String ownerId) {
    final restaurantItems = allMenuItems
        .where((item) => _getOwnerIdForMenuItem(item) == ownerId)
        .toList();

    final categorySet = <String>{};
    for (var item in restaurantItems) {
      final category = item['category'] as String?;
      if (category != null && category.isNotEmpty) {
        categorySet.add(category);
      }
    }

    return categorySet.toList()..sort();
  }

  // Load restaurants based on filters and search (always show restaurants)
  void _loadFilteredRestaurants() async {
    // Cancel previous subscriptions if any (safely)
    try {
      _restaurantsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling restaurants subscription: $e',
      );
    }
    _restaurantsSubscription = null;

    try {
      _searchMenuItemsSubscription?.cancel();
    } catch (e) {
      print(
        '[CustomerViewController] Error cancelling search menu items subscription: $e',
      );
    }
    _searchMenuItemsSubscription = null;

    isLoadingRestaurants.value = true;
    final currentQuery = searchQuery.value.trim();
    _currentSearchQuery = currentQuery;

    // Normalize query for search (restaurant name + item name/description/category)
    final normalizedQuery = normalizeArabic(currentQuery.toLowerCase());

    // Clear previous results
    _restaurantsFromName.clear();
    _allRestaurantsMap.clear();
    _hasItemMatchesForCurrentQuery = false;

    try {
      // Load all restaurants at once from Supabase
      final allRestaurantsList = await _restaurantService.getAllRestaurants();

      // Build caches: by owner_id and by restaurant id (so items can resolve via restaurant_id)
      // When owner_id is null, key by restaurant id so search and cards still work
      _allRestaurantsCache.clear();
      _allRestaurantsByRestaurantId.clear();
      for (final restaurant in allRestaurantsList) {
        final rid = (restaurant['id'] ?? '').toString().trim();
        if (rid.isNotEmpty) {
          _allRestaurantsByRestaurantId[rid] = restaurant;
        }
        final ownerId = (restaurant['owner_id'] ?? restaurant['ownerId'] ?? '')
            .toString()
            .trim();
        final cacheKey = ownerId.isNotEmpty ? ownerId : rid;
        if (cacheKey.isNotEmpty) {
          _allRestaurantsCache[cacheKey] = restaurant;
        }
      }

      // Empty query: show all restaurants with location filters
      if (currentQuery.isEmpty) {
        _applyLocationFiltersToRestaurants(List.from(allRestaurantsList));
        return;
      }

      // Search by restaurant name (normalize both so "مطعم 1" matches "مطعم ١")
      // Use owner_id as key when present, else restaurant id (your DB may have owner_id null)
      for (final restaurant in allRestaurantsList) {
        final rawName =
            (restaurant['name'] ?? restaurant['restaurant_name'] ?? '')
                .toString()
                .trim();
        if (rawName.isEmpty) continue;
        final normalizedRestaurantName = normalizeArabic(rawName.toLowerCase());
        final queryMatchesName = normalizedRestaurantName.contains(
          normalizedQuery,
        );
        if (queryMatchesName) {
          final ownerId =
              (restaurant['owner_id'] ?? restaurant['ownerId'] ?? '')
                  .toString()
                  .trim();
          final rid = (restaurant['id'] ?? '').toString().trim();
          final key = ownerId.isNotEmpty ? ownerId : rid;
          if (key.isNotEmpty) {
            _restaurantsFromName[key] = restaurant;
            _allRestaurantsMap[key] = restaurant;
          }
        }
      }

      // If no restaurant name matched, show all (avoid empty screen) so user can still browse
      if (_allRestaurantsMap.isEmpty) {
        for (final restaurant in allRestaurantsList) {
          final ownerId =
              (restaurant['owner_id'] ?? restaurant['ownerId'] ?? '')
                  .toString()
                  .trim();
          final rid = (restaurant['id'] ?? '').toString().trim();
          final key = ownerId.isNotEmpty ? ownerId : rid;
          if (key.isNotEmpty) {
            _allRestaurantsMap[key] = restaurant;
          }
        }
      }

      // Search menu items by food name (optional; don't block showing restaurant name matches)
      try {
        final allItems = List<Map<String, dynamic>>.from(allMenuItems);
        if (allItems.isNotEmpty) {
          await _processMenuItemsSearch(
            allItems,
            currentQuery,
            normalizedQuery,
          );
        } else {
          final menuItems = await _menuService.getAllMenuItems();
          await _processMenuItemsSearch(
            menuItems,
            currentQuery,
            normalizedQuery,
          );
        }
      } catch (e) {
        print(
          '[CustomerViewController] Menu items search error (continuing with restaurant matches): $e',
        );
      }

      // Always apply results so UI updates (restaurant name matches + any item matches)
      _combineAndApplyResults(currentQuery);
    } catch (e) {
      print('[CustomerViewController] Error loading restaurants: $e');
      isLoadingRestaurants.value = false;
      // On error still try to show something: apply empty or last state
      _applyLocationFiltersToRestaurants([]);
    } finally {
      isLoadingRestaurants.value = false;
    }
  }

  /// Resolve ownerId (or restaurant id as fallback) for a menu item so we can show the restaurant in search.
  String _getOwnerIdForMenuItem(Map<String, dynamic> item) {
    final ownerId = (item['ownerId'] as String? ?? '').toString().trim();
    if (ownerId.isNotEmpty) return ownerId;
    final restaurantId = (item['restaurant_id'] as String? ?? '').toString().trim();
    if (restaurantId.isEmpty) return '';
    // Prefer lookup by restaurant id map (has all restaurants)
    final restaurant = _allRestaurantsByRestaurantId[restaurantId];
    if (restaurant != null) {
      final oid = (restaurant['owner_id'] ?? restaurant['ownerId'] ?? '').toString().trim();
      return oid.isNotEmpty ? oid : restaurantId;
    }
    for (final e in _allRestaurantsCache.entries) {
      final rid = e.value['id']?.toString() ?? '';
      if (rid == restaurantId) return e.key;
    }
    return '';
  }

  Future<void> _processMenuItemsSearch(
    List<Map<String, dynamic>> allItems,
    String currentQuery,
    String normalizedQuery,
  ) async {
    // Check if this result is still relevant (query hasn't changed)
    if (_currentSearchQuery != currentQuery) {
      return; // Ignore stale results
    }

    // Find items that match: item name, description, or category
    final matchingItems = <Map<String, dynamic>>[];
    for (final item in allItems) {
      if (_currentSearchQuery != currentQuery) return;

      final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
      if (itemName.isNotEmpty &&
          normalizeArabic(itemName).contains(normalizedQuery)) {
        matchingItems.add(item);
        continue;
      }

      final itemDescription = (item['description'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (itemDescription.isNotEmpty &&
          normalizeArabic(itemDescription).contains(normalizedQuery)) {
        matchingItems.add(item);
        continue;
      }

      final itemCategory = (item['category'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (itemCategory.isNotEmpty &&
          normalizeArabic(itemCategory).contains(normalizedQuery)) {
        matchingItems.add(item);
      }
    }

    if (_currentSearchQuery != currentQuery) {
      return;
    }

    // Group matching items by ownerId (resolve from restaurant_id if needed)
    final itemsByOwnerId = <String, List<Map<String, dynamic>>>{};
    for (final item in matchingItems) {
      final ownerId = _getOwnerIdForMenuItem(item);
      if (ownerId.isNotEmpty) {
        itemsByOwnerId.putIfAbsent(ownerId, () => []).add(item);
      }
    }

    if (_currentSearchQuery != currentQuery) {
      return;
    }

    // Mark whether this query actually matched any items
    _hasItemMatchesForCurrentQuery = itemsByOwnerId.isNotEmpty;

    final finalItemsByOwnerId = <String, List<Map<String, dynamic>>>{};

    // Add all items for restaurants found by name
    for (final ownerId in _restaurantsFromName.keys) {
      if (_currentSearchQuery != currentQuery) {
        return;
      }
      final allRestaurantItems = allItems
          .where((item) => _getOwnerIdForMenuItem(item) == ownerId)
          .toList();
      if (allRestaurantItems.isNotEmpty) {
        finalItemsByOwnerId[ownerId] = allRestaurantItems;
      }
    }

    // Add matching items for restaurants found by food (but not by name)
    for (final entry in itemsByOwnerId.entries) {
      final ownerId = entry.key;
      if (!_restaurantsFromName.containsKey(ownerId)) {
        finalItemsByOwnerId[ownerId] = entry.value;
      }
    }

    // Store matching items per restaurant
    restaurantMatchingItems.value = finalItemsByOwnerId;

    // Get restaurant info for each ownerId that has matching food (but not already found by name)
    final ownerIdsToFetch = itemsByOwnerId.keys
        .where((ownerId) => !_restaurantsFromName.containsKey(ownerId))
        .toList();

    // Use cache for all lookups - key may be owner_id or restaurant_id
    for (final ownerId in ownerIdsToFetch) {
      if (_currentSearchQuery != currentQuery) return;

      final cachedRestaurant = _allRestaurantsCache[ownerId] ??
          _allRestaurantsByRestaurantId[ownerId];
      if (cachedRestaurant != null) {
        _allRestaurantsMap[ownerId] = cachedRestaurant;
      } else {
        // Not in cache, fetch and cache it
        try {
          print(
            '[CustomerViewController] Fetching restaurant info for ownerId: $ownerId',
          );
          final restaurantInfo = await _restaurantService
              .getRestaurantByOwnerId(ownerId);
          if (restaurantInfo != null) {
            final infoCompleted =
                restaurantInfo['info_completed'] ??
                restaurantInfo['infoCompleted'] ??
                false;
            final status = restaurantInfo['status'] ?? '';

            print(
              '[CustomerViewController] Restaurant info for $ownerId: infoCompleted=$infoCompleted, status=$status',
            );

            // Only include restaurants that are active and completed
            if (infoCompleted == true &&
                (status == 'active' || status.toString().isEmpty)) {
              _allRestaurantsMap[ownerId] = {
                'id': restaurantInfo['id'] ?? ownerId,
                'ownerId': ownerId,
                ...restaurantInfo,
              };
              // Update cache for future use
              _allRestaurantsCache[ownerId] = _allRestaurantsMap[ownerId]!;
              print(
                '[CustomerViewController] Added restaurant to map: ${restaurantInfo['name']}',
              );
            } else {
              print(
                '[CustomerViewController] Skipping restaurant $ownerId: not active or not completed',
              );
            }
          } else {
            print(
              '[CustomerViewController] No restaurant info found for ownerId: $ownerId',
            );
          }
        } catch (e) {
          // ignore: avoid_print
          print('[CustomerViewController] Error fetching restaurant: $e');
        }
      }
    }

    _combineAndApplyResults(currentQuery);
  }

  // Helper method to combine and apply search results
  void _combineAndApplyResults(String currentQuery) {
    if (_currentSearchQuery != currentQuery) {
      return; // Ignore stale results
    }

    // If the query matched any menu items, only show restaurants
    // that have matching items. If there are no item matches, fall
    // back to restaurant-name (and fallback) results.
    Iterable<Map<String, dynamic>> sourceRestaurants;
    if (_hasItemMatchesForCurrentQuery &&
        restaurantMatchingItems.isNotEmpty) {
      final allowedOwnerIds = restaurantMatchingItems.keys.toSet();
      sourceRestaurants = _allRestaurantsMap.entries
          .where((entry) => allowedOwnerIds.contains(entry.key))
          .map((entry) => entry.value);
    } else {
      sourceRestaurants = _allRestaurantsMap.values;
    }

    final allRestaurants = <Map<String, dynamic>>[];
    for (final restaurant in sourceRestaurants) {
      final ownerId = (restaurant['owner_id'] ?? restaurant['ownerId'] ?? '')
          .toString()
          .trim();
      final rid = (restaurant['id'] ?? '').toString().trim();
      if (ownerId.isNotEmpty || rid.isNotEmpty) {
        allRestaurants.add(restaurant);
      }
    }
    print(
      '[CustomerViewController] _combineAndApplyResults: ${allRestaurants.length} restaurants for query "$currentQuery"',
    );
    _applyLocationFiltersToRestaurants(allRestaurants);
  }

  void _applyLocationFiltersToRestaurants(
    List<Map<String, dynamic>> restaurants,
  ) {
    print(
      '[CustomerViewController] _applyLocationFiltersToRestaurants called with ${restaurants.length} restaurants',
    );
    print(
      '[CustomerViewController] Current filters - Governorate: ${selectedGovernorate.value}, City: ${selectedCity.value}',
    );
    List<Map<String, dynamic>> filtered = List.from(restaurants);

    // Apply governorate filter (support both governorate key from API)
    if (selectedGovernorate.value != null) {
      print(
        '[CustomerViewController] Applying governorate filter: ${selectedGovernorate.value}',
      );
      filtered = filtered.where((restaurant) {
        final gov = (restaurant['governorate'] ?? '').toString();
        final matches = gov == selectedGovernorate.value;
        if (!matches) {
          print(
            '[CustomerViewController]   Filtered out: ${restaurant['name']} (governorate: $gov)',
          );
        }
        return matches;
      }).toList();
      print(
        '[CustomerViewController] After governorate filter: ${filtered.length} restaurants',
      );
    }

    // Apply city filter
    if (selectedCity.value != null) {
      print(
        '[CustomerViewController] Applying city filter: ${selectedCity.value}',
      );
      filtered = filtered.where((restaurant) {
        final city = (restaurant['city'] ?? '').toString();
        final matches = city == selectedCity.value;
        if (!matches) {
          print(
            '[CustomerViewController]   Filtered out: ${restaurant['name']} (city: $city)',
          );
        }
        return matches;
      }).toList();
      print(
        '[CustomerViewController] After city filter: ${filtered.length} restaurants',
      );
    }

    print(
      '[CustomerViewController] Final filtered restaurants: ${filtered.length}',
    );
    for (final restaurant in filtered) {
      print(
        '[CustomerViewController]   - ${restaurant['name']} (${restaurant['governorate']}, ${restaurant['city']})',
      );
    }

    filteredRestaurants.assignAll(filtered);
    isLoadingRestaurants.value = false;
    print(
      '[CustomerViewController] Updated filteredRestaurants.value to ${filteredRestaurants.length} restaurants',
    );
  }
}
