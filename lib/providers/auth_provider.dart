import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isInitializing = true;  // For app startup token check
  bool _isLoading = false;       // For login button state only
  String? _authError;

  User? get user => _user;
  String? get token => _accessToken;
  bool get isAuthenticated => _accessToken != null && _user != null && _user!.role == 'student';
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get authError => _authError;

  final String baseUrl = ApiConfig.baseUrl;

  Future<bool> _refreshAccessToken() async {
    final rt = _refreshToken ?? await TokenService.getRefreshToken();
    if (rt == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': rt}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccess = data['accessToken'] as String?;
        final newRefresh = data['refreshToken'] as String?;
        if (newAccess == null) return false;

        _accessToken = newAccess;
        if (newRefresh != null) {
          _refreshToken = newRefresh;
          await TokenService.setTokens(accessToken: newAccess, refreshToken: newRefresh);
        } else {
          await TokenService.setAccessToken(newAccess);
        }

        return true;
      }
    } catch (e) {
      debugPrint('REFRESH ERROR: $e');
    }

    return false;
  }

  Future<void> loadUser() async {
    _isInitializing = true;
    _authError = null;

    try {
      _accessToken = await TokenService.getAccessToken();
      _refreshToken = await TokenService.getRefreshToken();

      if (_accessToken != null) {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer $_accessToken'},
          ).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            _user = User.fromJson(json.decode(response.body)['user']);
            if (_user?.role != 'student') {
              _accessToken = null;
              _refreshToken = null;
              _user = null;
              _authError = 'This app is for students only. Please use a student account.';
              await TokenService.clearTokens();
            }
          } else if (response.statusCode == 401 && _refreshToken != null) {
            final ok = await _refreshAccessToken();
            if (ok) {
              final retry = await http.get(
                Uri.parse('$baseUrl/auth/me'),
                headers: {'Authorization': 'Bearer $_accessToken'},
              ).timeout(const Duration(seconds: 10));
              if (retry.statusCode == 200) {
                _user = User.fromJson(json.decode(retry.body)['user']);
                if (_user?.role != 'student') {
                  _accessToken = null;
                  _refreshToken = null;
                  _user = null;
                  _authError = 'This app is for students only. Please use a student account.';
                  await TokenService.clearTokens();
                }
              } else {
                _accessToken = null;
                _refreshToken = null;
                await TokenService.clearTokens();
              }
            } else {
              _accessToken = null;
              _refreshToken = null;
              await TokenService.clearTokens();
            }
          } else {
            _accessToken = null;
            _refreshToken = null;
            await TokenService.clearTokens();
          }
        } catch (e) {
          debugPrint('LOADUSER HTTP ERROR: $e');
          _accessToken = null;
          _refreshToken = null;
          await TokenService.clearTokens();
        }
      }
    } catch (e) {
      debugPrint('LOADUSER TOKEN ERROR: $e');
      _accessToken = null;
      _refreshToken = null;
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password, 'role': 'student'}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        _user = User.fromJson(data['user']);

        if (_user?.role != 'student') {
          _accessToken = null;
          _refreshToken = null;
          _user = null;
          _authError = 'This app is for students only. Please use a student account.';
          await TokenService.clearTokens();
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (_accessToken != null && _refreshToken != null) {
          await TokenService.setTokens(accessToken: _accessToken!, refreshToken: _refreshToken!);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
    }

    _isLoading = false;
    _authError = 'Invalid email or password.';
    notifyListeners();
    return false;
  }

  Future<String?> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'role': 'student',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        _user = User.fromJson(data['user']);

        if (_accessToken != null && _refreshToken != null) {
          await TokenService.setTokens(accessToken: _accessToken!, refreshToken: _refreshToken!);
        }

        _isLoading = false;
        notifyListeners();
        return null; // null means success
      } else if (response.statusCode == 409) {
        _isLoading = false;
        notifyListeners();
        return 'Email is already registered.';
      } else {
        _isLoading = false;
        notifyListeners();
        return 'Registration failed. Please try again.';
      }
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return 'Network error. Check your connection.';
    }
  }

  Future<void> logout() async {
    try {
      final rt = _refreshToken ?? await TokenService.getRefreshToken();
      final at = _accessToken ?? await TokenService.getAccessToken();
      if (at != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $at',
            'Content-Type': 'application/json',
          },
          body: json.encode({'refreshToken': rt}),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // ignore
    }

    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await TokenService.clearTokens();
    notifyListeners();
  }
}
