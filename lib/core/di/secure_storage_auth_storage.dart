import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterSecureStorageGotrueStorage implements GotrueAsyncStorage {
  final _storage = const FlutterSecureStorage();

  Future<void> clear() async {
    await _storage.delete(key: 'supabase.auth.token');
  }

  @override
  Future<String?> getItem({required String key}) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }
}
