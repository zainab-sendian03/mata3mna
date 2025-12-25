import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static late SharedPreferences sharedPreferences;

  //! Here The Initialize of cache .
  init() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  //! this method to put data in local database using key

  String? getDataString({required String key}) {
    return sharedPreferences.getString(key);
  }

  //! this method to put data in local database using key

  Future<bool> saveData({required String key, required dynamic value}) async {
    if (value is bool) {
      return await sharedPreferences.setBool(key, value);
    }
    if (value is String) {
      return await sharedPreferences.setString(key, value);
    }
    if (value is int) {
      return await sharedPreferences.setInt(key, value);
    }
    if (value is double) {
      return await sharedPreferences.setDouble(key, value);
    }
    if (value is List<String>) {
      return await sharedPreferences.setStringList(key, value);
    }
    // Fallback: try to convert to string
    return await sharedPreferences.setString(key, value.toString());
  }

  //! this method to get data already saved in local database

  dynamic getData({required String key}) {
    return sharedPreferences.get(key);
  }

  //! this method to get string list from local database

  List<String>? getStringList({required String key}) {
    return sharedPreferences.getStringList(key);
  }

  //! remove data using specific key

  Future<bool> removeData({required String key}) async {
    return await sharedPreferences.remove(key);
  }

  //! this method to check if local database contains {key}
  Future<bool> containsKey({required String key}) async {
    return sharedPreferences.containsKey(key);
  }

  //! clear all data in the local database
  Future<bool> clearData() async {
    return await sharedPreferences.clear();
  }

  //! this method to put data in local database using key
  Future<dynamic> put({required String key, required dynamic value}) async {
    if (value is String) {
      return await sharedPreferences.setString(key, value);
    } else if (value is bool) {
      return await sharedPreferences.setBool(key, value);
    } else {
      return await sharedPreferences.setInt(key, value);
    }
  }

  /// Saves an image file to local storage and returns the file path
  /// The path is stored in SharedPreferences for later retrieval
  Future<String?> saveImageFile({
    required String key,
    required File imageFile,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/category_images');
      
      // Create directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${key}_$timestamp.jpg';
      final filePath = '${imagesDir.path}/$fileName';

      // Copy the file to local storage
      final savedFile = await imageFile.copy(filePath);

      // Store the file path in SharedPreferences
      await saveData(key: 'categoryImage_$key', value: savedFile.path);

      return savedFile.path;
    } catch (e) {
      // ignore: avoid_print
      print('Error saving image file: $e');
      return null;
    }
  }

  /// Gets the local file path for a category image
  String? getCategoryImagePath(String categoryName) {
    return getDataString(key: 'categoryImage_$categoryName');
  }

  /// Removes a category image file from local storage
  Future<bool> removeCategoryImage(String categoryName) async {
    try {
      final imagePath = getCategoryImagePath(categoryName);
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      return await removeData(key: 'categoryImage_$categoryName');
    } catch (e) {
      // ignore: avoid_print
      print('Error removing category image: $e');
      return false;
    }
  }
}
