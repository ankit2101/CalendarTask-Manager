import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores sensitive credentials (API keys) in macOS Keychain / Windows
/// Credential Manager when the keychain-access-groups entitlement is present,
/// with SharedPreferences used only as a short-lived handoff buffer.
///
/// Write path: always stage to SharedPreferences first, then promote to
/// Keychain. If the Keychain write succeeds the SharedPreferences copy is
/// deleted immediately so the plaintext plist is never the long-term store.
///
/// Read path: prefer Keychain; if not found, check SharedPreferences and
/// auto-promote to Keychain (then delete from SharedPreferences) when the
/// entitlement is available. This covers the ad-hoc→signed-release upgrade
/// path without leaving a permanent plaintext copy.
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
      try {
        final val = await _storage.read(key: '$_prefix$key');
        if (val != null) return val;
      } catch (_) {}
    }

    // Check SharedPreferences — either the Keychain entitlement is absent
    // (ad-hoc build) or the key was staged here by a previous saveSecret and
    // the Keychain write failed.  If Keychain is now available, promote and
    // delete so the plaintext copy doesn't linger.
    try {
      final prefs = await SharedPreferences.getInstance();
      final staged = prefs.getString('$_prefix$key');
      if (staged != null && staged.isNotEmpty) {
        if (await _isKeychainAvailable()) {
          try {
            await _storage.write(key: '$_prefix$key', value: staged);
            await prefs.remove('$_prefix$key');
          } catch (_) {}
        }
        return staged;
      }
    } catch (_) {}

    return null;
  }

  Future<void> saveSecret(String key, String value) async {
    // Stage to SharedPreferences first so the key is never lost if the
    // Keychain write fails or the entitlement is absent (ad-hoc builds).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);

    if (await _isKeychainAvailable()) {
      try {
        await _storage.write(key: '$_prefix$key', value: value);
        // Keychain write succeeded — remove the plaintext staging copy.
        await prefs.remove('$_prefix$key');
      } catch (_) {}
    }
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
