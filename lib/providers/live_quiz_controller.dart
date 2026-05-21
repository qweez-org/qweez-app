import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class LiveQuizController extends ChangeNotifier {
  final io.Socket socket;
  final String pin;
  final List<Map<String, dynamic>> allQuestions;
  final int totalDurationSec;

  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};
  final Set<int> _submittedQuestions = {};
  final Map<int, DateTime> _questionStartTimes = {};

  Timer? _timer;
  int _secondsRemaining = 0;

  bool _finished = false;
  bool _quizEnded = false;
  List<Map<String, dynamic>> _leaderboard = [];

  // Expose state
  int get currentIndex => _currentIndex;
  Map<int, String> get selectedAnswers => _selectedAnswers;
  Set<int> get submittedQuestions => _submittedQuestions;
  int get secondsRemaining => _secondsRemaining;
  bool get finished => _finished;
  bool get quizEnded => _quizEnded;
  List<Map<String, dynamic>> get leaderboard => _leaderboard;

  // Optional: callbacks for UI dialogs
  void Function()? onSessionCancelled;
  void Function()? onTeacherDisconnected;

  LiveQuizController({
    required this.socket,
    required this.pin,
    required this.allQuestions,
    required this.totalDurationSec,
    Map<String, dynamic>? existingAnswers,
  }) {
    _secondsRemaining = totalDurationSec;
    _questionStartTimes[0] = DateTime.now();

    if (existingAnswers != null) {
      existingAnswers.forEach((qIdxStr, ansData) {
        final qIdx = int.tryParse(qIdxStr);
        if (qIdx != null) {
          _selectedAnswers[qIdx] = ansData['answer']?.toString() ?? '';
          _submittedQuestions.add(qIdx);
        }
      });

      if (_submittedQuestions.isNotEmpty) {
        for (int i = 0; i < allQuestions.length; i++) {
          if (!_submittedQuestions.contains(i)) {
            _currentIndex = i;
            break;
          }
        }
      }
    }

    _startTimer();
    _setupSocketListeners();
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    if (!_questionStartTimes.containsKey(index)) {
      _questionStartTimes[index] = DateTime.now();
    }
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _autoFinish();
      } else {
        notifyListeners();
      }
    });
  }

  void _setupSocketListeners() {
    socket.on('answer_received', (data) {
      // no-op for student
    });

    socket.on('quiz_ended', (data) {
      final lb = (data['leaderboard'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _quizEnded = true;
      _leaderboard = lb;
      _timer?.cancel();
      notifyListeners();
    });

    socket.on('session_cancelled', (_) {
      _timer?.cancel();
      onSessionCancelled?.call();
    });

    socket.on('teacher_disconnected', (_) {
      onTeacherDisconnected?.call();
    });
  }

  void selectAnswer(int questionIndex, String answer) {
    if (_submittedQuestions.contains(questionIndex)) return;
    _selectedAnswers[questionIndex] = answer;
    notifyListeners();
  }

  void submitAnswerToServer(int index) {
    final originalIndex = allQuestions[index]['_originalIndex'] ?? index;
    final selected = _selectedAnswers[index] ?? '';
    final startTime = _questionStartTimes[index];
    final timeMs = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : 0;

    socket.emit('submit_answer', {
      'pin': pin,
      'questionIndex': originalIndex,
      'answer': selected,
      'timeMs': timeMs,
    });
    _submittedQuestions.add(index);
    notifyListeners();
  }

  void submitQuiz() {
    submitAnswerToServer(_currentIndex);
    _finishQuiz();
  }

  void _finishQuiz() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    notifyListeners();

    socket.emit('submit_all_answers', {
      'pin': pin,
      'answers': allQuestions.asMap().entries.map((entry) {
        final idx = entry.key;
        final startTime = _questionStartTimes[idx];
        final timeMs = startTime != null
            ? DateTime.now().difference(startTime).inMilliseconds
            : 0;
        return {
          'questionIndex': allQuestions[idx]['_originalIndex'] ?? idx,
          'answer': _selectedAnswers[idx] ?? '',
          'timeMs': timeMs,
        };
      }).toList(),
    });
  }

  void _autoFinish() {
    _finishQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket.off('answer_received');
    socket.off('quiz_ended');
    socket.off('session_cancelled');
    socket.off('teacher_disconnected');
    super.dispose();
  }
}
