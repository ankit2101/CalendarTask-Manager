import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores sensitive credentials (API keys) in the OS secure credential store:
/// - macOS: Keychain Services
/// - Windows: Windows Credential Manager
///
/// On first use after upgrading from the old SharedPreferences backend, any
/// existing key is transparently migrated to secure storage and deleted from
/// SharedPreferences so it no longer sits in a world-readable plist.
class TokenStore {
  static final TokenStore _instance = TokenStore._();

  TokenStore._();

  static TokenStore get instance => _instance;

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'token_';

  Future<String?> loadSecret(String key) async {
    // Read from secure storage (Keychain / Credential Manager).
    try {
      final val = await _storage.read(key: '$_prefix$key');
      if (val != null) return val;
    } catch (_) {}

    // Migration path: check the legacy SharedPreferences store.
    // If a value is found, move it to secure storage and wipe the plaintext.
    try {
      final prefs  = await SharedPreferences.getInstance();
      final legacy = prefs.getString('$_prefix$key');
      if (legacy != null && legacy.isNotEmpty) {
        await saveSecret(key, legacy);
        await prefs.remove('$_prefix$key');
        return legacy;
      }
    } catch (_) {}

    return null;
  }

  Future<void> saveSecret(String key, String value) async {
    await _storage.write(key: '$_prefix$key', value: value);
  }

  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: '$_prefix$key');
    // Also clean up any residual legacy key.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }
}
