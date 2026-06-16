import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores sensitive credentials (API keys) in macOS Keychain / Windows
/// Credential Manager when the keychain-access-groups entitlement is present,
/// with SharedPreferences used only as a short-lived handoff buffer.
///
/// Write path: always stage to SharedPreferences first, then promote to
/// Keychain. prefs.remove only runs after a confirmed successful Keychain
/// write, so a failed write leaves the pref as a fallback rather than
/// silently dropping the key.
///
/// Read path: prefer Keychain; if not found, check SharedPreferences and
/// auto-promote via saveSecret (then delete from SharedPreferences) when the
/// entitlement is available. This covers the ad-hoc to signed-release upgrade
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
    final keychainOk = await _isKeychainAvailable();
    if (keychainOk) {
      try {
        final val = await _storage.read(key: '$_prefix$key');
        if (val != null) return val;
      } catch (_) {}
    }

    // Check SharedPreferences: either the Keychain entitlement is absent
    // (ad-hoc build) or the key was staged here by a previous saveSecret and
    // the Keychain write failed. If Keychain is now available, promote via
    // saveSecret which handles the atomic stage-and-cleanup correctly.
    try {
      final prefs = await SharedPreferences.getInstance();
      final staged = prefs.getString('$_prefix$key');
      if (staged != null && staged.isNotEmpty) {
        if (keychainOk) await saveSecret(key, staged);
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
      var promoted = false;
      try {
        await _storage.write(key: '$_prefix$key', value: value);
        promoted = true;
      } catch (_) {}
      // Only remove the plaintext staging copy when the Keychain write
      // actually succeeded — a failed write leaves the pref as fallback.
      if (promoted) {
        try { await prefs.remove('$_prefix$key'); } catch (_) {}
      }
    }
  }

  Future<void> deleteSecret(String key) async {
    if (await _isKeychainAvailable()) {
      try {
        await _storage.delete(key: '$_prefix$key');
      } catch (_) {}
    }
    // Also clean up SharedPreferences (staging store or ad-hoc fallback).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }
}
