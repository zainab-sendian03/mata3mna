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
  final MenuFirestoreService _menuService = Get.find<MenuFirestoreService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();
  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();
  final LocationFirestoreService _locationService =
      Get.find<LocationFirestoreService>();

  // Observable state
  final RxBool isLoading = false.obs;
  final RxBool hasReceivedData = false.obs;
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> allMenuItems =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredRestaurants =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingRestaurants = false.obs;
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
      {}; // Cache all restaurants
  bool _restaurantsLoaded = false;
  bool _menuItemsLoaded = false;

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
    // Pre-load restaurants into cache for faster search
    _preloadRestaurants();
    // Always load restaurants
    _loadFilteredRestaurants();
  }

  /// Load governorates and cities from Firestore
  Future<void> _loadLocations() async {
    try {
      // Load governorates
      final loadedGovernorates = await _locationService.getGovernorates();
      
      // If no governorates exist, initialize default locations
      if (loadedGovernorates.isEmpty) {
        await _locationService.initializeDefaultLocations();
        final reloadedGovernorates = await _locationService.getGovernorates();
        governorates.value = reloadedGovernorates;
      } else {
        governorates.value = loadedGovernorates;
      }
      
      // Load cities grouped by governorate
      final loadedCitiesMap =
          await _locationService.getCitiesByGovernorateMap();
      citiesByGovernorate.value = loadedCitiesMap;
    } catch (e) {
      // ignore: avoid_print
      print('[CustomerViewController] Error loading locations: $e');
      // Fallback to empty lists if loading fails
      governorates.value = [];
      citiesByGovernorate.value = {};
    }
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    _menuItemsSubscription?.cancel();
    _restaurantsSubscription?.cancel();
    _searchMenuItemsSubscription?.cancel();
    super.onClose();
  }

  // Pre-load restaurants into cache for faster search
  void _preloadRestaurants() {
    _restaurantsSubscription?.cancel();
    _restaurantsSubscription = _restaurantService.getAllRestaurants().listen((
      restaurants,
    ) {
      // Cache all restaurants for quick lookup
      for (final restaurant in restaurants) {
        final ownerId = (restaurant['ownerId'] as String? ?? '').trim();
        if (ownerId.isNotEmpty) {
          _allRestaurantsCache[ownerId] = restaurant;
        }
      }
      // Cancel subscription after first load to avoid memory leaks
      _restaurantsSubscription?.cancel();
    });
  }

  void loadAllMenuItems() {
    if (!hasReceivedData.value) {
      isLoading.value = true;
    }
    _menuItemsSubscription?.cancel();
    _menuItemsSubscription = _menuService.getAllMenuItemsStream().listen((
      items,
    ) {
      allMenuItems.value = items;
      hasReceivedData.value = true;
      isLoading.value = false;
    });
  }

  String normalizeArabic(String text) {
    if (text.isEmpty) return text;

    final Map<String, String> replacements = {
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
      'غ': 'ج',
      "ج": 'غ',
    };

    replacements.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

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
      return [];
    }
    return citiesByGovernorate[selectedGovernorate.value] ?? [];
  }

  Future<void> handleRefresh() async {
    isLoading.value = true;

    // Reload menu items - the stream will update the data
    // Wait a bit to show the refresh indicator
    await Future.delayed(Duration(milliseconds: 300));

    HapticFeedback.mediumImpact();
    isLoading.value = false;

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

    // Clear previous results immediately when new search starts
    filteredRestaurants.clear();
    restaurantMatchingItems.clear();

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
        .where((item) => (item['ownerId'] as String? ?? '').trim() == ownerId)
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
  // When searching, show restaurants with matching names OR matching food items
  void _loadFilteredRestaurants() {
    // Cancel previous subscriptions
    _restaurantsSubscription?.cancel();
    _searchMenuItemsSubscription?.cancel();

    isLoadingRestaurants.value = true;
    final currentQuery = searchQuery.value;
    _currentSearchQuery = currentQuery;

    if (currentQuery.isEmpty) {
      // Use cached restaurants if available, otherwise load from stream
      if (_allRestaurantsCache.isNotEmpty) {
        final cachedRestaurants = _allRestaurantsCache.values.toList();
        _applyLocationFiltersToRestaurants(cachedRestaurants);
        return;
      }

      // Load all restaurants and apply filters
      _restaurantsSubscription = _restaurantService.getAllRestaurants().listen((
        restaurants,
      ) {
        // Only apply results if this is still the current query
        if (_currentSearchQuery.isEmpty) {
          // Update cache
          for (final restaurant in restaurants) {
            final ownerId = (restaurant['ownerId'] as String? ?? '').trim();
            if (ownerId.isNotEmpty) {
              _allRestaurantsCache[ownerId] = restaurant;
            }
          }
          _applyLocationFiltersToRestaurants(restaurants);
        }
      });
      return;
    }

    // Search by both restaurant name and food name
    final normalizedQuery = normalizeArabic(currentQuery.toLowerCase());

    // Reset shared state (but keep cache)
    _restaurantsFromName.clear();
    _allRestaurantsMap.clear();
    _restaurantsLoaded = false;
    _menuItemsLoaded = false;

    // Search restaurants by name - use cache if available
    Future<void> searchRestaurantsByName() async {
      if (_currentSearchQuery != currentQuery) {
        return; // Ignore stale results
      }

      List<Map<String, dynamic>> allRestaurantsList;

      // Use cache if available, otherwise load from stream
      if (_allRestaurantsCache.isNotEmpty) {
        allRestaurantsList = _allRestaurantsCache.values.toList();
      } else {
        // Load from stream and cache
        final completer = Completer<List<Map<String, dynamic>>>();
        _restaurantsSubscription = _restaurantService
            .getAllRestaurants()
            .listen((restaurants) {
              if (!completer.isCompleted) {
                // Update cache
                for (final restaurant in restaurants) {
                  final ownerId = (restaurant['ownerId'] as String? ?? '')
                      .trim();
                  if (ownerId.isNotEmpty) {
                    _allRestaurantsCache[ownerId] = restaurant;
                  }
                }
                completer.complete(restaurants);
              }
            });
        allRestaurantsList = await completer.future;
      }

      // Check again if query changed
      if (_currentSearchQuery != currentQuery) {
        return; // Ignore stale results
      }

      _restaurantsFromName.clear();
      _allRestaurantsMap.clear();

      // Find restaurants that match by name
      for (final restaurant in allRestaurantsList) {
        if (_currentSearchQuery != currentQuery) {
          return; // Ignore stale results
        }

        final restaurantName = (restaurant['name'] ?? '')
            .toString()
            .toLowerCase();
        final normalizedRestaurantName = normalizeArabic(restaurantName);

        if (normalizedRestaurantName.contains(normalizedQuery)) {
          final ownerId = (restaurant['ownerId'] as String? ?? '').trim();
          if (ownerId.isNotEmpty) {
            _restaurantsFromName[ownerId] = restaurant;
            _allRestaurantsMap[ownerId] = restaurant;
          }
        }
      }

      _restaurantsLoaded = true;
      _combineAndApplyResults(currentQuery);
    }

    // Search menu items by food name - use already loaded items
    Future<void> searchMenuItems() async {
      // Check if this result is still relevant (query hasn't changed)
      if (_currentSearchQuery != currentQuery) {
        return; // Ignore stale results
      }

      // Use already loaded menu items instead of waiting for stream
      final allItems = List<Map<String, dynamic>>.from(allMenuItems);
      if (allItems.isEmpty) {
        // If no items loaded yet, wait for stream (only once)
        _searchMenuItemsSubscription?.cancel();
        _searchMenuItemsSubscription = _menuService
            .getAllMenuItemsStream()
            .listen((items) async {
              await _processMenuItemsSearch(
                items,
                currentQuery,
                normalizedQuery,
              );
            });
        return;
      }

      // Process immediately with loaded items
      await _processMenuItemsSearch(allItems, currentQuery, normalizedQuery);
    }

    // Run both searches in parallel
    searchRestaurantsByName();
    searchMenuItems();
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

    // Pre-normalize query once
    // Find items that match the food name - optimized with early exit
    final matchingItems = <Map<String, dynamic>>[];
    for (final item in allItems) {
      if (_currentSearchQuery != currentQuery) {
        return; // Ignore stale results
      }

      final itemName = (item['name'] ?? '').toString().toLowerCase();
      final normalizedItemName = normalizeArabic(itemName);

      // Check name first (most common match)
      if (normalizedItemName.contains(normalizedQuery)) {
        matchingItems.add(item);
        continue;
      }

      // Only check description if name doesn't match
      final itemDescription = (item['description'] ?? '')
          .toString()
          .toLowerCase();
      final normalizedItemDescription = normalizeArabic(itemDescription);
      if (normalizedItemDescription.contains(normalizedQuery)) {
        matchingItems.add(item);
      }
    }

    // Check again if query changed during processing
    if (_currentSearchQuery != currentQuery) {
      return; // Ignore stale results
    }

    // Group matching items by ownerId - use Map for O(1) lookup
    final itemsByOwnerId = <String, List<Map<String, dynamic>>>{};
    for (final item in matchingItems) {
      final ownerId = (item['ownerId'] as String? ?? '').trim();
      if (ownerId.isNotEmpty) {
        itemsByOwnerId.putIfAbsent(ownerId, () => []).add(item);
      }
    }

    // Check again if query changed during processing
    if (_currentSearchQuery != currentQuery) {
      return; // Ignore stale results
    }

    // For restaurants found by name, show all their items
    // For restaurants found by food, show only matching items
    final finalItemsByOwnerId = <String, List<Map<String, dynamic>>>{};

    // Add all items for restaurants found by name
    for (final ownerId in _restaurantsFromName.keys) {
      if (_currentSearchQuery != currentQuery) {
        return; // Ignore stale results
      }
      // Use cached items if available, otherwise filter from allItems
      final allRestaurantItems = allItems
          .where((item) => (item['ownerId'] as String? ?? '').trim() == ownerId)
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

    // Use cache for all lookups - much faster
    for (final ownerId in ownerIdsToFetch) {
      // Check if query changed
      if (_currentSearchQuery != currentQuery) {
        return; // Ignore stale results
      }

      // Try to get from cache first (should be there from preload)
      final cachedRestaurant = _allRestaurantsCache[ownerId];
      if (cachedRestaurant != null) {
        _allRestaurantsMap[ownerId] = cachedRestaurant;
      } else {
        // Not in cache, fetch and cache it
        try {
          final restaurantInfo = await _restaurantService
              .getRestaurantInfoByOwnerId(ownerId);
          if (restaurantInfo != null &&
              (restaurantInfo['infoCompleted'] == true) &&
              (restaurantInfo['status'] == 'active' ||
                  restaurantInfo['status'] == null)) {
            _allRestaurantsMap[ownerId] = {
              'id': ownerId,
              'ownerId': ownerId,
              ...restaurantInfo,
            };
            // Update cache for future use
            _allRestaurantsCache[ownerId] = _allRestaurantsMap[ownerId]!;
          }
        } catch (e) {
          // ignore: avoid_print
          print('[CustomerViewController] Error fetching restaurant: $e');
        }
      }
    }

    _menuItemsLoaded = true;
    _combineAndApplyResults(currentQuery);
  }

  // Helper method to combine and apply search results
  void _combineAndApplyResults(String currentQuery) {
    if (!_restaurantsLoaded || !_menuItemsLoaded) {
      return; // Wait for both to complete
    }

    if (_currentSearchQuery != currentQuery) {
      return; // Ignore stale results
    }

    // Apply location filters
    final allRestaurants = <Map<String, dynamic>>[];
    for (final restaurant in _allRestaurantsMap.values) {
      final ownerId = restaurant['ownerId'] as String? ?? '';
      if (ownerId.isNotEmpty) {
        allRestaurants.add(restaurant);
      }
    }

    _applyLocationFiltersToRestaurants(allRestaurants);
  }

  void _applyLocationFiltersToRestaurants(
    List<Map<String, dynamic>> restaurants,
  ) {
    List<Map<String, dynamic>> filtered = List.from(restaurants);

    // Apply governorate filter
    if (selectedGovernorate.value != null) {
      filtered = filtered.where((restaurant) {
        final gov = (restaurant['governorate'] ?? '').toString();
        return gov == selectedGovernorate.value;
      }).toList();
    }

    // Apply city filter
    if (selectedCity.value != null) {
      filtered = filtered.where((restaurant) {
        final city = (restaurant['city'] ?? '').toString();
        return city == selectedCity.value;
      }).toList();
    }

    filteredRestaurants.value = filtered;
    isLoadingRestaurants.value = false;
  }
}
