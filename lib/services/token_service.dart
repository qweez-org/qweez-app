import 'package:shared_preferences/shared_preferences.dart';

/// Shared utility for token management across all providers.
/// Fix #25: Extracted from duplicate implementations in ClassProvider and QuizProvider.
class TokenService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  /// Returns the Authorization header map, or null if not authenticated.
  static Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}
