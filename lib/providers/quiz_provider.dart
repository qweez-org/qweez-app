import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import '../models/question_model.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class QuizProvider with ChangeNotifier {
  final String baseUrl = ApiConfig.baseUrl;

  AttemptModel? _currentAttempt;
  List<QuestionModel> _questions = [];
  Map<String, String> _answers = {}; // questionId -> answer
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _timer;
  int _remainingSeconds = 0;

  AttemptModel? get currentAttempt => _currentAttempt;
  List<QuestionModel> get questions => _questions;
  Map<String, String> get answers => _answers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get remainingSeconds => _remainingSeconds;

  Future<bool> startQuiz(QuizModel quiz) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await TokenService.getToken();
      if (token == null) throw Exception('Not authenticated');

      // 1. Start or resume attempt
      final startRes = await http.post(
        Uri.parse('$baseUrl/attempts/quizzes/${quiz.id}/start'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (startRes.statusCode != 200 && startRes.statusCode != 201) {
        final errorMsg = json.decode(startRes.body)['message'] ?? 'Failed to start quiz';
        throw Exception(errorMsg);
      }

      final startData = json.decode(startRes.body);
      _currentAttempt = AttemptModel.fromJson(startData['attempt']);

      // 2. Fetch existing answers if resuming
      final attemptRes = await http.get(
        Uri.parse('$baseUrl/attempts/${_currentAttempt!.id}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (attemptRes.statusCode == 200) {
        final attemptData = json.decode(attemptRes.body);
        final List<dynamic> existingAnswers = attemptData['answers'] ?? [];
        _answers = {
          for (var a in existingAnswers) a['questionId']: a['answer']
        };
      }

      // 3. Fetch questions
      final questionsRes = await http.get(
        Uri.parse('$baseUrl/quizzes/${quiz.id}/questions'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (questionsRes.statusCode == 200) {
        final questionsData = json.decode(questionsRes.body);
        final List<dynamic> questionsList = questionsData['questions'] ?? [];
        _questions = questionsList.map((q) => QuestionModel.fromJson(q)).toList();
      } else {
        throw Exception('Failed to load questions');
      }

      // Setup Timer
      _setupTimer(quiz.duration);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _setupTimer(int durationMinutes) {
    _timer?.cancel();
    if (_currentAttempt == null) return;

    final elapsed = DateTime.now().difference(_currentAttempt!.startedAt).inSeconds;
    final totalSeconds = durationMinutes * 60;
    _remainingSeconds = totalSeconds - elapsed;

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      submitQuiz(); // Auto submit
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        submitQuiz(); // Auto submit
      }
    });
  }

  Future<void> saveAnswer(String questionId, String answer) async {
    _answers[questionId] = answer;
    notifyListeners();

    try {
      final token = await TokenService.getToken();
      if (token == null || _currentAttempt == null) return;

      await http.put(
        Uri.parse('$baseUrl/attempts/${_currentAttempt!.id}/answers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'answers': [
            {'questionId': questionId, 'answer': answer}
          ]
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Save locally even if network fails — answer is already in _answers map
      debugPrint('Failed to sync answer to server: $e');
    }
  }

  Future<Map<String, dynamic>?> submitQuiz() async {
    _timer?.cancel();
    _isLoading = true;
    notifyListeners();

    try {
      final token = await TokenService.getToken();
      if (token == null || _currentAttempt == null) throw Exception('Not authenticated');

      final res = await http.post(
        Uri.parse('$baseUrl/attempts/${_currentAttempt!.id}/submit'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _currentAttempt = AttemptModel.fromJson(data['attempt']);
        return data; // contains totalPoints, earnedPoints
      } else {
        _errorMessage = 'Failed to submit quiz';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error while submitting';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
