import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _tokenKey = 'access_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<String?> readToken() => _storage.read(key: _tokenKey);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<Map<String, String>> authHeaders() async {
    final token = await readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}