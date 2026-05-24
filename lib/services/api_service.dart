import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/token_service.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Completer<http.Response>? _refreshCompleter;

  static Future<http.Response> _retryWithRefresh(
    Future<http.Response> Function(String token) requestFn,
  ) async {
    if (_refreshCompleter != null) {
      final res = await _refreshCompleter!.future;
      if (res.statusCode == 200) {
        final token = await TokenService.getAccessToken();
        if (token != null) {
          return await requestFn(token);
        }
      }
      return http.Response('Unauthorized', 401);
    }

    _refreshCompleter = Completer<http.Response>();

    final rt = await TokenService.getRefreshToken();
    if (rt == null) {
      _refreshCompleter?.complete(http.Response('Unauthorized', 401));
      _refreshCompleter = null;
      return http.Response('Unauthorized', 401);
    }

    try {
      final refreshRes = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': rt}),
      ).timeout(const Duration(seconds: 10));

      if (refreshRes.statusCode == 200) {
        final data = json.decode(refreshRes.body);
        final newAccess = data['accessToken'] as String?;
        final newRefresh = data['refreshToken'] as String?;

        if (newAccess != null) {
          if (newRefresh != null) {
            await TokenService.setTokens(accessToken: newAccess, refreshToken: newRefresh);
          } else {
            await TokenService.setAccessToken(newAccess);
          }
          _refreshCompleter?.complete(refreshRes);
          _refreshCompleter = null;
          return await requestFn(newAccess);
        }
      }
      
      _refreshCompleter?.complete(refreshRes);
    } catch (e) {
      debugPrint('ApiService token refresh error: $e');
      if (!(_refreshCompleter?.isCompleted ?? true)) {
        _refreshCompleter?.complete(http.Response('Unauthorized', 401));
      }
    }

    _refreshCompleter = null;
    await TokenService.clearTokens();
    return http.Response('Unauthorized', 401);
  }

  static Future<http.Response> get(String endpoint) async {
    final token = await TokenService.getAccessToken();
    if (token == null) return http.Response('Unauthorized', 401);

    final url = Uri.parse('$_baseUrl$endpoint');
    Future<http.Response> reqFn(String t) => http.get(
          url,
          headers: {'Authorization': 'Bearer $t'},
        ).timeout(const Duration(seconds: 10));

    var response = await reqFn(token);
    if (response.statusCode == 401) {
      response = await _retryWithRefresh(reqFn);
    }
    return response;
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final token = await TokenService.getAccessToken();
    if (token == null) return http.Response('Unauthorized', 401);

    final url = Uri.parse('$_baseUrl$endpoint');
    Future<http.Response> reqFn(String t) => http.post(
          url,
          headers: {
            'Authorization': 'Bearer $t',
            'Content-Type': 'application/json',
          },
          body: body != null ? json.encode(body) : null,
        ).timeout(const Duration(seconds: 10));

    var response = await reqFn(token);
    if (response.statusCode == 401) {
      response = await _retryWithRefresh(reqFn);
    }
    return response;
  }

  static Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final token = await TokenService.getAccessToken();
    if (token == null) return http.Response('Unauthorized', 401);

    final url = Uri.parse('$_baseUrl$endpoint');
    Future<http.Response> reqFn(String t) => http.patch(
          url,
          headers: {
            'Authorization': 'Bearer $t',
            'Content-Type': 'application/json',
          },
          body: body != null ? json.encode(body) : null,
        ).timeout(const Duration(seconds: 10));

    var response = await reqFn(token);
    if (response.statusCode == 401) {
      response = await _retryWithRefresh(reqFn);
    }
    return response;
  }

  static Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) async {
    final token = await TokenService.getAccessToken();
    if (token == null) return http.Response('Unauthorized', 401);

    final url = Uri.parse('$_baseUrl$endpoint');
    Future<http.Response> reqFn(String t) => http.put(
          url,
          headers: {
            'Authorization': 'Bearer $t',
            'Content-Type': 'application/json',
          },
          body: body != null ? json.encode(body) : null,
        ).timeout(const Duration(seconds: 10));

    var response = await reqFn(token);
    if (response.statusCode == 401) {
      response = await _retryWithRefresh(reqFn);
    }
    return response;
  }
}
