import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static final TokenStore _instance = TokenStore._();

  TokenStore._();

  static TokenStore get instance => _instance;

  Future<String?> loadSecret(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token_$key');
  }

  Future<void> saveSecret(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token_$key', value);
  }

  Future<void> deleteSecret(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token_$key');
  }
}
