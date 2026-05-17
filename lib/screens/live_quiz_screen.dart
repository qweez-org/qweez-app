import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../theme/app_theme.dart';

/// Live quiz screen showing questions one-by-one (same format as normal quiz).
/// Student navigates with Next/Previous. On each Next click the answer is
/// sent to the server so the teacher sees a real-time leaderboard update.
class LiveQuizScreen extends StatefulWidget {
  final io.Socket socket;
  final String pin;
  final String quizTitle;
  final List<Map<String, dynamic>> allQuestions;
  final int totalDurationSec;
  final bool allowBacktrack;
  final Map<String, dynamic>? existingAnswers;

  const LiveQuizScreen({
    super.key,
    required this.socket,
    required this.pin,
    required this.quizTitle,
    required this.allQuestions,
    required this.totalDurationSec,
    this.allowBacktrack = true,
    this.existingAnswers,
  });

  @override
  State<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends State<LiveQuizScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Map<questionIndex, selectedAnswer>
  final Map<int, String> _selectedAnswers = {};
  // Track which questions have been submitted to the server
  final Set<int> _submittedQuestions = {};

  // Timer
  Timer? _timer;
  int _secondsRemaining = 0;

  // Track when each question was first shown, for accurate timeMs
  final Map<int, DateTime> _questionStartTimes = {};

  // Quiz state
  bool _finished = false;
  bool _quizEnded = false;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.totalDurationSec;
    _questionStartTimes[0] = DateTime.now();

    if (widget.existingAnswers != null) {
      widget.existingAnswers!.forEach((qIdxStr, ansData) {
        final qIdx = int.tryParse(qIdxStr);
        if (qIdx != null) {
          _selectedAnswers[qIdx] = ansData['answer']?.toString() ?? '';
          _submittedQuestions.add(qIdx);
        }
      });
      
      if (_submittedQuestions.isNotEmpty) {
        for (int i = 0; i < widget.allQuestions.length; i++) {
          if (!_submittedQuestions.contains(i)) {
            _currentIndex = i;
            break;
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_currentIndex);
          }
        });
      }
    }

    _startTimer();
    _setupSocketListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _autoFinish();
      }
    });
  }

  void _setupSocketListeners() {
    widget.socket.on('answer_received', (data) {

    });

    widget.socket.on('quiz_ended', (data) {

      if (mounted) {
        final lb = (data['leaderboard'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
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

  void _selectAnswer(int questionIndex, String answer) {
    if (_submittedQuestions.contains(questionIndex)) return;
    setState(() => _selectedAnswers[questionIndex] = answer);
  }

  void _submitAnswerToServer(int currentIndex) {
    final originalIndex = widget.allQuestions[currentIndex]['_originalIndex'] ?? currentIndex;
    final selected = _selectedAnswers[currentIndex] ?? '';
    final startTime = _questionStartTimes[currentIndex];
    final timeMs = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : 0;
    widget.socket.emit('submit_answer', {
      'pin': widget.pin,
      'questionIndex': originalIndex,
      'answer': selected,
      'timeMs': timeMs,
    });
    _submittedQuestions.add(currentIndex);
  }

  void _nextPage() {
    final totalQuestions = widget.allQuestions.length;
    if (_currentIndex < totalQuestions - 1) {
      // Send current answer to server before moving forward
      _submitAnswerToServer(_currentIndex);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submitQuiz() {
    // Send last question's answer
    _submitAnswerToServer(_currentIndex);
    _finishQuiz();
  }

  void _finishQuiz() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    setState(() {});

    // Signal to server that this student is done
    widget.socket.emit('submit_all_answers', {
      'pin': widget.pin,
      'answers': widget.allQuestions.asMap().entries.map((entry) {
        final idx = entry.key;
        final startTime = _questionStartTimes[idx];
        final timeMs = startTime != null
            ? DateTime.now().difference(startTime).inMilliseconds
            : 0;
        return {
          'questionIndex': widget.allQuestions[idx]['_originalIndex'] ?? idx,
          'answer': _selectedAnswers[idx] ?? '',
          'timeMs': timeMs,
        };
      }).toList(),
    });
  }

  void _autoFinish() {
    _finishQuiz();
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_quizEnded) return _buildLeaderboard();
    if (_finished) return _buildWaitingView();
    return _buildQuizView();
  }

  // ── Quiz View (one-by-one with PageView) ──────────────────────────────────

  Widget _buildQuizView() {
    final totalQuestions = widget.allQuestions.length;
    final isLastQuestion = _currentIndex == totalQuestions - 1;
    final hasSelected = _selectedAnswers.containsKey(_currentIndex);
    final isSubmitted = _submittedQuestions.contains(_currentIndex);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: progress + timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border(bottom: BorderSide(color: AppTheme.gray200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soal ${_currentIndex + 1} dari $totalQuestions',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _secondsRemaining < 60
                          ? AppTheme.error.withValues(alpha: 0.08)
                          : AppTheme.primary50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _secondsRemaining < 60 ? AppTheme.error : AppTheme.primary600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_secondsRemaining),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _secondsRemaining < 60 ? AppTheme.error : AppTheme.primary600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Linear progress
            LinearProgressIndicator(
              value: (_currentIndex + 1) / totalQuestions,
              backgroundColor: AppTheme.gray200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary400),
            ),

            // Timer progress bar
            LinearProgressIndicator(
              value: _secondsRemaining / widget.totalDurationSec,
              backgroundColor: AppTheme.primary100,
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsRemaining <= 60 ? AppTheme.error : AppTheme.primary500,
              ),
              minHeight: 3,
            ),

            // Questions PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                  });
                  // Record start time for this question only the first time it is shown
                  if (!_questionStartTimes.containsKey(idx)) {
                    _questionStartTimes[idx] = DateTime.now();
                  }
                },
                itemCount: totalQuestions,
                itemBuilder: (context, index) {
                  return _buildQuestionCard(widget.allQuestions[index], index);
                },
              ),
            ),

            // Footer Navigation
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Row(
                children: [
                  if (_currentIndex > 0 && widget.allowBacktrack)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.primary400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Sebelumnya', style: TextStyle(color: AppTheme.primary400)),
                      ),
                    )
                  else
                    const Spacer(),

                  const SizedBox(width: 16),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLastQuestion
                          ? (hasSelected || isSubmitted ? _submitQuiz : null)
                          : (hasSelected || isSubmitted ? _nextPage : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLastQuestion ? AppTheme.textPrimary : AppTheme.primary400,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isLastQuestion ? 'Kirim' : 'Selanjutnya',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int qIndex) {
    final isSubmitted = _submittedQuestions.contains(qIndex);
    final options = (question['options'] as List?)
            ?.map((o) => Map<String, dynamic>.from(o as Map))
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSubmitted ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.primary100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'Soal ${qIndex + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSubmitted ? AppTheme.success : AppTheme.primary700,
                  ),
                ),
              ),
              if (isSubmitted) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Terkirim',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (question['points'] != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${question['points']} pts',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question['text'] ?? 'Pertanyaan',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...options.asMap().entries.map((optEntry) {
            final optIdx = optEntry.key;
            final option = optEntry.value;
            final optText = option['text'] ?? '';
            final isSelected = _selectedAnswers[qIndex] == optText;
            final letter = String.fromCharCode(65 + optIdx);

            return GestureDetector(
              onTap: isSubmitted ? null : () => _selectAnswer(qIndex, optText),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSubmitted
                      ? (isSelected ? AppTheme.success.withValues(alpha: 0.08) : AppTheme.gray100)
                      : (isSelected ? AppTheme.primary50 : AppTheme.gray50),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isSubmitted
                        ? (isSelected ? AppTheme.success : AppTheme.gray300)
                        : (isSelected ? AppTheme.primary500 : AppTheme.gray300),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSubmitted
                            ? (isSelected ? AppTheme.success : AppTheme.gray200)
                            : (isSelected ? AppTheme.primary500 : AppTheme.surfaceCard),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSubmitted
                              ? (isSelected ? AppTheme.success : AppTheme.gray400)
                              : (isSelected ? AppTheme.primary500 : AppTheme.gray400),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSubmitted
                                ? (isSelected ? Colors.white : AppTheme.gray500)
                                : (isSelected ? Colors.white : AppTheme.textSecondary),
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
                          color: isSubmitted
                              ? (isSelected ? AppTheme.success : AppTheme.gray500)
                              : (isSelected ? AppTheme.primary700 : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: isSubmitted ? AppTheme.success : AppTheme.primary500,
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          }),
          if (question['type'] == 'short_answer') ...[
            TextFormField(
              initialValue: _selectedAnswers[qIndex],
              maxLines: 1,
              enabled: !isSubmitted,
              decoration: InputDecoration(
                hintText: 'Ketik jawaban Anda di sini...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isSubmitted ? AppTheme.gray100 : Colors.white,
              ),
              onChanged: (val) {
                _selectAnswer(qIndex, val);
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Waiting View (after submit) ────────────────────────────────────────────

  Widget _buildWaitingView() {
    return Scaffold(
      backgroundColor: AppTheme.primary50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppTheme.success, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Semua Jawaban Terkirim!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Menunggu siswa lain menyelesaikan kuis...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                'Sisa waktu: ${_formatTime(_secondsRemaining)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textTertiary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
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
      body: SafeArea(
        child: Column(
          children: [
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
                        if (rank == 1) {
                          medal = '🥇';
                          bgColor = const Color(0xFFFACC15).withValues(alpha: 0.1);
                        } else if (rank == 2) {
                          medal = '🥈';
                          bgColor = AppTheme.gray100;
                        } else if (rank == 3) {
                          medal = '🥉';
                          bgColor = const Color(0xFFCD7F32).withValues(alpha: 0.1);
                        }

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
            Padding(
              padding: EdgeInsets.all(16).copyWith(bottom: 16 + MediaQuery.of(context).padding.bottom),
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
      ),
    );
  }
}
