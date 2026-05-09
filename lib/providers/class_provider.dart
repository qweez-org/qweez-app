import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class ClassProvider with ChangeNotifier {
  List<ClassModel> _classes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ClassModel> get classes => _classes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final String baseUrl = ApiConfig.baseUrl;

  /// Fix #24: Clear error state
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/classes'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> classList = data['classes'] ?? [];
        _classes = classList.map((c) => ClassModel.fromJson(c)).toList();
      } else {
        _errorMessage = 'Failed to load classes (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Network error. Check your connection.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<TopicModel>> fetchTopics(String classId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/classes/topics/$classId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> topicsList = data['topics'] ?? [];
        return topicsList.map((t) => TopicModel.fromJson(t)).toList();
      }
    } catch (e) {
      _errorMessage = 'Failed to load topics. Check your connection.';
      notifyListeners();
    }
    return [];
  }

  Future<List<QuizModel>> fetchQuizzesForTopic(String topicId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/topics/$topicId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> quizList = data['quizzes'] ?? [];
        return quizList.map((q) => QuizModel.fromJson(q)).toList();
      }
    } catch (e) {
      _errorMessage = 'Failed to load quizzes. Check your connection.';
      notifyListeners();
    }
    return [];
  }

  Future<bool> joinClass(String code) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/classes/join-requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'code': code}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return true;
      } else {
        final data = json.decode(response.body);
        _errorMessage = data['message'] ?? 'Failed to join class';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Network error. Check your connection.';
      notifyListeners();
    }
    return false;
  }

  Future<bool> leaveClass(String classId) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/classes/$classId/leave'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _classes.removeWhere((c) => c.id == classId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to leave class';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Network error. Check your connection.';
      notifyListeners();
    }
    return false;
  }
}
