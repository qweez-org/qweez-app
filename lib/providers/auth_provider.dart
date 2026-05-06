import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/api_config.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isInitializing = true;  // For app startup token check
  bool _isLoading = false;       // For login button state only

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;

  final String baseUrl = ApiConfig.baseUrl;

  Future<void> loadUser() async {
    _isInitializing = true;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $_token'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          _user = User.fromJson(json.decode(response.body)['user']);
        } else {
          _token = null;
          await prefs.remove('token');
        }
      } catch (e) {
        _token = null;
        await prefs.remove('token');
      }
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = User.fromJson(data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('LOGIN ERROR: $e');
    }

    _isLoading = false;
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
        _token = data['token'];
        _user = User.fromJson(data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);

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
      print('REGISTER ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return 'Network error. Check your connection.';
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
