class ApiConfig {
  // Default for Android Emulator. Override with setBaseUrl() for physical devices.
  static String _baseUrl = 'http://10.0.2.2:5000/api';

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
}
