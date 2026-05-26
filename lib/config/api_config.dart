import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ApiConfig {
  // Build-time override: flutter run --dart-define=API_URL=https://api.example.com/api
  static const String _dartDefineUrl = String.fromEnvironment('API_URL');

  // Default: use --dart-define in release, emulator IP in debug.
  static String _baseUrl = _dartDefineUrl.isNotEmpty
      ? _dartDefineUrl
      : (kDebugMode ? 'http://10.0.2.2:5000/api' : 'http://10.0.2.2:5000/api');

  static String get baseUrl => _baseUrl;

  /// Call this in main.dart before the app starts, e.g.:
  ///   ApiConfig.setBaseUrl('http://192.168.1.10:5000/api');
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  /// Convenience setter that only changes the host portion.
  static void setHost(String host, {int port = 5000}) {
    _baseUrl = 'http://$host:$port/api';
  }

  /// Load optional runtime config from assets/config.json.
  /// Falls back to defaults if the file is missing.
  /// Works in both debug and release builds so the app can be
  /// configured without recompiling (e.g. for staging/production APKs).
  static Future<void> loadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final config = jsonDecode(raw) as Map<String, dynamic>;
      final host = config['apiHost'] as String?;
      final port = config['apiPort'] as int?;
      if (host != null && host.isNotEmpty) {
        setHost(host, port: port ?? 5000);
        debugPrint('[ApiConfig] Loaded from assets: host=$host port=$port → $baseUrl');
      } else if (config['apiUrl'] != null && (config['apiUrl'] as String).isNotEmpty) {
        setBaseUrl(config['apiUrl'] as String);
        debugPrint('[ApiConfig] Loaded from assets: apiUrl=$baseUrl');
      } else if (_dartDefineUrl.isNotEmpty) {
        debugPrint('[ApiConfig] Using --dart-define API_URL: $baseUrl');
      } else {
        debugPrint('[ApiConfig] No config override found — using default: $baseUrl');
      }
    } catch (e) {
      debugPrint('[ApiConfig] Failed to load assets/config.json — using default: $baseUrl ($e)');
    }
  }
}
