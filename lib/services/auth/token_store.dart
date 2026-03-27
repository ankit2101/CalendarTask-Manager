import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static final TokenStore _instance = TokenStore._();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  TokenStore._();

  static TokenStore get instance => _instance;

  Future<String?> loadSecret(String key) => _storage.read(key: key);

  Future<void> saveSecret(String key, String value) => _storage.write(key: key, value: value);

  Future<void> deleteSecret(String key) => _storage.delete(key: key);
}
