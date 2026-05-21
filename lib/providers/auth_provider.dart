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
    } on SocketException catch (e) {
      debugPrint('LOGIN NETWORK ERROR: $e');
      _isLoading = false;
      _authError = 'Cannot connect to server. Check your network and make sure the API is running.';
      notifyListeners();
      return false;
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
    } on SocketException catch (e) {
      debugPrint('REGISTER NETWORK ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return 'Cannot connect to server. Check your network and make sure the API is running.';
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return 'Registration failed. Please try again.';
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
