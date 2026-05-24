import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
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

  String get _baseUrl => ApiConfig.baseUrl;

  Future<void> loadUser() async {
    _isInitializing = true;
    _authError = null;

    try {
      _accessToken = await TokenService.getAccessToken();
      _refreshToken = await TokenService.getRefreshToken();

      if (_accessToken != null) {
        try {
          final response = await ApiService.get('/auth/me');
          if (response.statusCode == 200) {
            _user = User.fromJson(json.decode(response.body)['user']);
            if (_user?.role != 'student') {
              _accessToken = null;
              _refreshToken = null;
              _user = null;
              _authError = 'This app is for students only. Please use a student account.';
              await TokenService.clearTokens();
            }
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            _accessToken = null;
            _refreshToken = null;
            await TokenService.clearTokens();
          }
        } on SocketException catch (e) {
          debugPrint('LOADUSER NETWORK ERROR: $e');
        } catch (e) {
          debugPrint('LOADUSER ERROR: $e');
          if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
            // keep tokens on network error
          } else {
            _accessToken = null;
            _refreshToken = null;
            await TokenService.clearTokens();
          }
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
        Uri.parse('$_baseUrl/auth/login'),
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
          return false;
        }

        if (_accessToken != null && _refreshToken != null) {
          await TokenService.setTokens(accessToken: _accessToken!, refreshToken: _refreshToken!);
        }

        return true;
      }
      _authError = 'Invalid email or password.';
      return false;
    } on SocketException catch (e) {
      debugPrint('LOGIN NETWORK ERROR: $e');
      _authError = 'Cannot connect to server. Check your network and make sure the API is running.';
      return false;
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      _authError = 'Invalid email or password.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
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

        return null; // null means success
      } else if (response.statusCode == 409) {
        return 'Email is already registered.';
      } else {
        return 'Registration failed. Please try again.';
      }
    } on SocketException catch (e) {
      debugPrint('REGISTER NETWORK ERROR: $e');
      return 'Cannot connect to server. Check your network and make sure the API is running.';
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      return 'Registration failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      final rt = _refreshToken ?? await TokenService.getRefreshToken();
      if (rt != null) {
        await ApiService.post('/auth/logout', body: {'refreshToken': rt});
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
