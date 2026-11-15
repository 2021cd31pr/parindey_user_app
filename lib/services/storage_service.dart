import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final Map<String, String> _memoryStorage = {};

  static Future<void> setString(String key, String value) async {
    _memoryStorage[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('SharedPreferences fallback to memory storage ($key): $e');
      }
    }
  }

  static Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(key);
      if (val != null && val.isNotEmpty) return val;
    } catch (e) {
      if (kDebugMode) {
        print('SharedPreferences fallback to memory storage ($key): $e');
      }
    }
    return _memoryStorage[key];
  }

  static Future<void> remove(String key) async {
    _memoryStorage.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      if (kDebugMode) {
        print('SharedPreferences remove error: $e');
      }
    }
  }
}
