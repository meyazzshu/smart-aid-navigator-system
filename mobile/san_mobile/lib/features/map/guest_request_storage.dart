import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuestRequestStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'guest_shelter_request';

  static Future<void> save(Map<String, dynamic> data) async {
    await _storage.write(key: _key, value: jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
