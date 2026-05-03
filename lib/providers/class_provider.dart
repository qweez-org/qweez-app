import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_model.dart';

class ClassProvider with ChangeNotifier {
  List<ClassModel> _classes = [];
  bool _isLoading = false;

  List<ClassModel> get classes => _classes;
  bool get isLoading => _isLoading;

  final String baseUrl = 'http://192.168.1.15:5000/api'; // Changed for physical device testing

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> classList = data['classes'] ?? [];
        _classes = classList.map((c) => ClassModel.fromJson(c)).toList();
      }
    } catch (e) {
      // Ignore errors for now
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<TopicModel>> fetchTopics(String classId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/classes/topics/$classId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> topicsList = data['topics'] ?? [];
        return topicsList.map((t) => TopicModel.fromJson(t)).toList();
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
  }

  Future<List<QuizModel>> fetchQuizzesForTopic(String topicId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/topics/$topicId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> quizList = data['quizzes'] ?? [];
        return quizList.map((q) => QuizModel.fromJson(q)).toList();
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
  }

  Future<bool> joinClass(String code) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/classes/join-requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'code': code}),
      );

      if (response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      // Ignore errors
    }
    return false;
  }
}
