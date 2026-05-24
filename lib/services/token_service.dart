import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared utility for token management across all providers.
/// Fix #25: Extracted from duplicate implementations in ClassProvider and QuizProvider.
class TokenService {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'qweez_access_token';
  static const _refreshKey = 'qweez_refresh_token';
  static const _liveQuizPinKey = 'qweez_live_quiz_pin';

  static Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);
  static Future<String?> getActivePin() => _storage.read(key: _liveQuizPinKey);

  static Future<void> setTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: _accessKey, value: token);
  }

  static Future<void> setActivePin(String pin) async {
    await _storage.write(key: _liveQuizPinKey, value: pin);
  }

  static Future<void> clearActivePin() async {
    await _storage.delete(key: _liveQuizPinKey);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// Returns the Authorization header map, or null if not authenticated.
  static Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}
