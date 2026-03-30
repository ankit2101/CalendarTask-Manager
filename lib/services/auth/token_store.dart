import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores sensitive credentials (OAuth refresh tokens, API keys) in the
/// platform secure store — macOS Keychain on macOS.
class TokenStore {
  static final TokenStore _instance = TokenStore._();

  TokenStore._();

  static TokenStore get instance => _instance;

  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: 'com.caltask.calendarTaskManager',
      synchronizable: false,
    ),
  );

  Future<String?> loadSecret(String key) async {
    return _storage.read(key: 'token_$key');
  }

  Future<void> saveSecret(String key, String value) async {
    await _storage.write(key: 'token_$key', value: value);
  }

  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: 'token_$key');
  }
}
