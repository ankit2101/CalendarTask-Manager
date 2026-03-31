import 'package:shared_preferences/shared_preferences.dart';

/// Stores sensitive credentials (API keys) in the app's local preferences.
/// Kept per-device and not included in the shared sync JSON file.
/// Uses SharedPreferences (NSUserDefaults on macOS) which works reliably
/// with ad-hoc signing without requiring Keychain entitlements.
class TokenStore {
  static final TokenStore _instance = TokenStore._();

  TokenStore._();

  static TokenStore get instance => _instance;

  static const _prefix = 'token_';

  Future<String?> loadSecret(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  Future<void> saveSecret(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);
  }

  Future<void> deleteSecret(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
