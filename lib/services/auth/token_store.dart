import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores sensitive credentials (API keys) in the OS secure credential store:
/// - macOS: Keychain Services (requires keychain-access-groups entitlement)
/// - Windows: Windows Credential Manager
///
/// Falls back to SharedPreferences if secure storage is unavailable (e.g. ad-hoc
/// signed macOS builds that lack the keychain-access-groups entitlement).
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

  // Set to true the first time we confirm Keychain is available on this run.
  bool? _keychainAvailable;

  Future<bool> _isKeychainAvailable() async {
    if (_keychainAvailable != null) return _keychainAvailable!;
    try {
      // Probe: attempt a benign read to verify entitlement is present.
      await _storage.read(key: '${_prefix}__probe__');
      _keychainAvailable = true;
    } catch (e) {
      // -34018 = errSecMissingEntitlement, or other Keychain errors.
      _keychainAvailable = false;
    }
    return _keychainAvailable!;
  }

  Future<String?> loadSecret(String key) async {
    if (await _isKeychainAvailable()) {
      // Read from secure storage (Keychain / Credential Manager).
      try {
        final val = await _storage.read(key: '$_prefix$key');
        if (val != null) return val;
      } catch (_) {}
    }

    // Fallback / migration path: check SharedPreferences.
    // If a value is found and Keychain is available, migrate it there.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString('$_prefix$key');
      if (legacy != null && legacy.isNotEmpty) {
        if (await _isKeychainAvailable()) {
          await saveSecret(key, legacy);
          await prefs.remove('$_prefix$key');
        }
        return legacy;
      }
    } catch (_) {}

    return null;
  }

  Future<void> saveSecret(String key, String value) async {
    if (await _isKeychainAvailable()) {
      try {
        await _storage.write(key: '$_prefix$key', value: value);
        return;
      } catch (_) {}
    }
    // Fallback to SharedPreferences when Keychain is unavailable.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);
  }

  Future<void> deleteSecret(String key) async {
    if (await _isKeychainAvailable()) {
      try {
        await _storage.delete(key: '$_prefix$key');
      } catch (_) {}
    }
    // Also clean up SharedPreferences (fallback store or legacy migration).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }
}
