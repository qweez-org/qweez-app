import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class ClassProvider with ChangeNotifier {
  List<ClassModel> _classes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ClassModel> get classes => _classes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
      final response = await ApiService.get('/classes');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> classList = data['classes'] ?? [];
        _classes = classList.map((c) => ClassModel.fromJson(c)).toList();
      } else {
        _errorMessage = 'Failed to load classes (${response.statusCode})';
      }
    } on SocketException catch (e) {
      debugPrint('CLASS FETCH NETWORK ERROR: $e');
      _errorMessage = 'Cannot connect to server (${ApiConfig.baseUrl}). Make sure the API is running and you are on the same WiFi.';
    } catch (e) {
      debugPrint('CLASS FETCH ERROR: $e');
      _errorMessage = 'Failed to load classes. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<TopicModel>> fetchTopics(String classId) async {
    try {
      final response = await ApiService.get('/classes/topics/$classId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> topicsList = data['topics'] ?? [];
        return topicsList.map((t) => TopicModel.fromJson(t)).toList();
      }
    } on SocketException catch (e) {
      debugPrint('TOPICS FETCH NETWORK ERROR: $e');
      _errorMessage = 'Cannot connect to server. Make sure the API is running.';
      notifyListeners();
    } catch (e) {
      debugPrint('TOPICS FETCH ERROR: $e');
      _errorMessage = 'Failed to load topics. Please try again.';
      notifyListeners();
    }
    return [];
  }

  Future<List<QuizModel>> fetchQuizzesForTopic(String topicId) async {
    try {
      final response = await ApiService.get('/quizzes/topics/$topicId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> quizList = data['quizzes'] ?? [];
        return quizList.map((q) => QuizModel.fromJson(q)).toList();
      }
    } on SocketException catch (e) {
      debugPrint('QUIZZES FETCH NETWORK ERROR: $e');
      _errorMessage = 'Cannot connect to server. Make sure the API is running.';
      notifyListeners();
    } catch (e) {
      debugPrint('QUIZZES FETCH ERROR: $e');
      _errorMessage = 'Failed to load quizzes. Please try again.';
      notifyListeners();
    }
    return [];
  }

  Future<bool> joinClass(String code) async {
    try {
      final response = await ApiService.post('/classes/join-requests', body: {'code': code});

      if (response.statusCode == 201) {
        return true;
      } else {
        final data = json.decode(response.body);
        _errorMessage = data['message'] ?? 'Failed to join class';
        notifyListeners();
      }
    } on SocketException catch (e) {
      debugPrint('JOIN CLASS NETWORK ERROR: $e');
      _errorMessage = 'Cannot connect to server. Make sure the API is running.';
      notifyListeners();
    } catch (e) {
      debugPrint('JOIN CLASS ERROR: $e');
      _errorMessage = 'Failed to join class. Please try again.';
      notifyListeners();
    }
    return false;
  }

  Future<bool> leaveClass(String classId) async {
    try {
      final response = await ApiService.post('/classes/$classId/leave');

      if (response.statusCode == 200) {
        _classes.removeWhere((c) => c.id == classId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to leave class';
        notifyListeners();
      }
    } on SocketException catch (e) {
      debugPrint('LEAVE CLASS NETWORK ERROR: $e');
      _errorMessage = 'Cannot connect to server. Make sure the API is running.';
      notifyListeners();
    } catch (e) {
      debugPrint('LEAVE CLASS ERROR: $e');
      _errorMessage = 'Failed to leave class. Please try again.';
      notifyListeners();
    }
    return false;
  }
}
