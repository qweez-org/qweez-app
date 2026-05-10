import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../theme/app_theme.dart';

/// Dedicated live quiz question screen.
/// Receives the Socket from the waiting screen and listens for question events.
class LiveQuizScreen extends StatefulWidget {
  final io.Socket socket;
  final String pin;
  final String quizTitle;
  final Map<String, dynamic> firstQuestion; // quiz_started payload

  const LiveQuizScreen({
    super.key,
    required this.socket,
    required this.pin,
    required this.quizTitle,
    required this.firstQuestion,
  });

  @override
  State<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends State<LiveQuizScreen> {
  // Question state
  int _questionIndex = 0;
  int _totalQuestions = 1;
  int _timeLimit = 30;
  Map<String, dynamic> _question = {};
  List<Map<String, dynamic>> _options = [];

  // Answer state
  String? _selectedAnswer;
  bool _answerSubmitted = false;
  Stopwatch _stopwatch = Stopwatch();

  // Between-question result
  bool _showingResult = false;
  String? _correctAnswer;
  int _correctCount = 0;
  int _wrongCount = 0;

  // Quiz ended
  bool _quizEnded = false;
  List<Map<String, dynamic>> _leaderboard = [];

  // Timer
  Timer? _timer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _loadQuestion(widget.firstQuestion);
    _setupSocketListeners();
  }

  void _loadQuestion(Map<String, dynamic> data) {
    final question = data['question'] as Map<String, dynamic>? ?? {};
    final options = (question['options'] as List?)
        ?.map((o) => Map<String, dynamic>.from(o as Map))
        .toList() ?? [];

    setState(() {
      _questionIndex = data['questionIndex'] ?? 0;
      _totalQuestions = data['totalQuestions'] ?? 1;
      _timeLimit = data['timeLimit'] ?? 30;
      _question = question;
      _options = options;
      _selectedAnswer = null;
      _answerSubmitted = false;
      _showingResult = false;
      _secondsRemaining = _timeLimit;
    });

    _stopwatch = Stopwatch()..start();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        // Auto-submit if time runs out and not yet submitted
        if (!_answerSubmitted) {
          _submitAnswer();
        }
      }
    });
  }

  void _setupSocketListeners() {
    widget.socket.on('question_start', (data) {
      debugPrint('📝 Next question: $data');
      if (mounted) {
        _loadQuestion(Map<String, dynamic>.from(data));
      }
    });

    widget.socket.on('answer_received', (data) {
      debugPrint('✅ Answer acknowledged: $data');
    });

    widget.socket.on('question_result', (data) {
      debugPrint('📊 Question result: $data');
      if (mounted) {
        final stats = data['stats'] ?? {};
        setState(() {
          _showingResult = true;
          _correctAnswer = data['correctAnswer']?.toString() ?? '';
          _correctCount = stats['correctCount'] ?? 0;
          _wrongCount = stats['wrongCount'] ?? 0;
        });
        _timer?.cancel();
      }
    });

    widget.socket.on('quiz_ended', (data) {
      debugPrint('🏆 Quiz ended');
      if (mounted) {
        final lb = (data['leaderboard'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
        setState(() {
          _quizEnded = true;
          _leaderboard = lb;
        });
        _timer?.cancel();
      }
    });

    widget.socket.on('session_cancelled', (_) {
      if (mounted) {
        _timer?.cancel();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Sesi Dibatalkan'),
            content: const Text('Guru telah membatalkan sesi live quiz.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    widget.socket.on('teacher_disconnected', (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Guru terputus dari sesi.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  void _selectAnswer(String answer) {
    if (_answerSubmitted) return;
    setState(() => _selectedAnswer = answer);
  }

  void _submitAnswer() {
    if (_answerSubmitted) return;

    _stopwatch.stop();
    setState(() => _answerSubmitted = true);

    widget.socket.emit('submit_answer', {
      'pin': widget.pin,
      'questionIndex': _questionIndex,
      'answer': _selectedAnswer ?? '',
      'timeMs': _stopwatch.elapsedMilliseconds,
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    widget.socket.disconnect();
    widget.socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_quizEnded) return _buildLeaderboard();
    if (_showingResult) return _buildResultView();
    return _buildQuestionView();
  }

  // ── Question View ──────────────────────────────────────────────────────────

  Widget _buildQuestionView() {
    final timerColor = _secondsRemaining <= 5
        ? Colors.red
        : _secondsRemaining <= 10
            ? Colors.orange
            : AppTheme.primary600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: progress + timer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soal ${_questionIndex + 1} / $_totalQuestions',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: timerColor),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_secondsRemaining),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: timerColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_questionIndex + 1) / _totalQuestions,
                  backgroundColor: AppTheme.primary100,
                  color: AppTheme.primary500,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Question text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _question['text'] ?? 'Question',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Options
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final optText = option['text'] ?? '';
                  final isSelected = _selectedAnswer == optText;
                  final letter = String.fromCharCode(65 + index);

                  return GestureDetector(
                    onTap: () => _selectAnswer(optText),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary500 : Colors.grey.shade200,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary500 : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppTheme.primary500, size: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedAnswer != null && !_answerSubmitted) ? _submitAnswer : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: _answerSubmitted ? Colors.green : null,
                  ),
                  child: _answerSubmitted
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Jawaban Terkirim!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        )
                      : const Text('Kirim Jawaban', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result View (between questions) ────────────────────────────────────────

  Widget _buildResultView() {
    final wasCorrect = _selectedAnswer == _correctAnswer;

    return Scaffold(
      backgroundColor: wasCorrect ? Colors.green.shade50 : Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                wasCorrect ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: wasCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                wasCorrect ? 'Benar! 🎉' : 'Salah 😕',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: wasCorrect ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 12),
              if (!wasCorrect)
                Text(
                  'Jawaban benar: $_correctAnswer',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statCard('Benar', '$_correctCount', Colors.green),
                  const SizedBox(width: 16),
                  _statCard('Salah', '$_wrongCount', Colors.red),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Menunggu soal selanjutnya...',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────

  Widget _buildLeaderboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Hasil Live Quiz'),
        backgroundColor: AppTheme.primary600,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppTheme.primary600,
            child: Text(
              widget.quizTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Leaderboard list
          Expanded(
            child: _leaderboard.isEmpty
                ? const Center(child: Text('Belum ada data'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final entry = _leaderboard[index];
                      final rank = entry['rank'] ?? (index + 1);
                      final name = entry['displayName'] ?? 'Siswa';
                      final score = entry['score'] ?? 0;

                      Color? bgColor;
                      String medal = '#$rank';
                      if (rank == 1) { medal = '🥇'; bgColor = Colors.amber.shade50; }
                      else if (rank == 2) { medal = '🥈'; bgColor = Colors.grey.shade50; }
                      else if (rank == 3) { medal = '🥉'; bgColor = Colors.brown.shade50; }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: bgColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: rank <= 3
                              ? Text(medal, style: const TextStyle(fontSize: 28))
                              : CircleAvatar(
                                  backgroundColor: AppTheme.primary100,
                                  child: Text(
                                    '#$rank',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.primary700,
                                    ),
                                  ),
                                ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(
                            '$score pts',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primary600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Selesai', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
