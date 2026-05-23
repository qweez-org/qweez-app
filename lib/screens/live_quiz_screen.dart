import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../theme/app_theme.dart';
import '../providers/live_quiz_controller.dart';

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
  late LiveQuizController _controller;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _controller = LiveQuizController(
      socket: widget.socket,
      pin: widget.pin,
      allQuestions: widget.allQuestions,
      totalDurationSec: widget.totalDurationSec,
      existingAnswers: widget.existingAnswers,
    );

    _controller.onSessionCancelled = () {
      if (mounted) {
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
    };

    _controller.onTeacherDisconnected = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Guru terputus dari sesi.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.currentIndex > 0 && _pageController.hasClients) {
        _pageController.jumpToPage(_controller.currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    // Clear stored pin only if quiz actually ended
    if (_controller.quizEnded) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('live_quiz_active_pin');
      });
    }
    super.dispose();
  }

  void _nextPage() {
    final totalQuestions = widget.allQuestions.length;
    if (_controller.currentIndex < totalQuestions - 1) {
      _controller.submitAnswerToServer(_controller.currentIndex);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_controller.currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<LiveQuizController>(
        builder: (context, controller, child) {
          if (controller.quizEnded) return _buildLeaderboard(controller);
          if (controller.finished) return _buildWaitingView(controller);
          return _buildQuizView(controller);
        },
      ),
    );
  }

  Widget _buildQuizView(LiveQuizController controller) {
    final totalQuestions = widget.allQuestions.length;
    final isLastQuestion = controller.currentIndex == totalQuestions - 1;
    final hasSelected = controller.selectedAnswers.containsKey(controller.currentIndex);
    final isSubmitted = controller.submittedQuestions.contains(controller.currentIndex);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
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
                    'Soal ${controller.currentIndex + 1} dari $totalQuestions',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.secondsRemaining < 60
                          ? AppTheme.error.withValues(alpha: 0.08)
                          : AppTheme.primary50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: controller.secondsRemaining < 60 ? AppTheme.error : AppTheme.primary600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(controller.secondsRemaining),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: controller.secondsRemaining < 60 ? AppTheme.error : AppTheme.primary600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (controller.currentIndex + 1) / totalQuestions,
              backgroundColor: AppTheme.gray200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary400),
            ),
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              tween: Tween<double>(
                begin: controller.secondsRemaining / widget.totalDurationSec,
                end: controller.secondsRemaining / widget.totalDurationSec,
              ),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: AppTheme.primary100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    controller.secondsRemaining <= 60 ? AppTheme.error : AppTheme.primary500,
                  ),
                  minHeight: 3,
                );
              },
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  controller.setCurrentIndex(idx);
                },
                itemCount: totalQuestions,
                itemBuilder: (context, index) {
                  return _buildQuestionCard(controller, widget.allQuestions[index], index);
                },
              ),
            ),
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
                  if (controller.currentIndex > 0 && widget.allowBacktrack)
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
                          ? (hasSelected || isSubmitted ? controller.submitQuiz : null)
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

  Widget _buildQuestionCard(LiveQuizController controller, Map<String, dynamic> question, int qIndex) {
    final isSubmitted = controller.submittedQuestions.contains(qIndex);
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
          if (question['type'] == 'true_false') ...[
            Row(
              children: options.map((option) {
                final optText = option['text'] ?? '';
                final isSelected = controller.selectedAnswers[qIndex] == optText;
                final isBenar = optText == 'Benar';

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isBenar ? 0 : 8,
                      right: isBenar ? 8 : 0,
                    ),
                    child: isSelected
                        ? ElevatedButton.icon(
                            onPressed: isSubmitted ? null : () => controller.selectAnswer(qIndex, optText),
                            icon: Icon(isBenar ? Icons.check : Icons.close, size: 20),
                            label: Text(
                              optText,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSubmitted ? AppTheme.success : AppTheme.primary400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: isSubmitted ? null : () => controller.selectAnswer(qIndex, optText),
                            icon: Icon(isBenar ? Icons.check : Icons.close, size: 20, color: isSubmitted ? AppTheme.gray400 : AppTheme.primary500),
                            label: Text(
                              optText,
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: isSubmitted ? AppTheme.gray400 : AppTheme.primary500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isSubmitted ? AppTheme.gray300 : AppTheme.primary400, 
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (question['type'] == 'multiple_choice')
            ...options.asMap().entries.map((optEntry) {
              final optIdx = optEntry.key;
              final option = optEntry.value;
              final optText = option['text'] ?? '';
              final isSelected = controller.selectedAnswers[qIndex] == optText;
              final letter = String.fromCharCode(65 + optIdx);

              return GestureDetector(
                onTap: isSubmitted ? null : () => controller.selectAnswer(qIndex, optText),
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
              initialValue: controller.selectedAnswers[qIndex],
              maxLines: 1,
              enabled: !isSubmitted,
              decoration: InputDecoration(
                hintText: 'Ketik jawaban Anda di sini...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isSubmitted ? AppTheme.gray100 : Colors.white,
              ),
              onChanged: (val) {
                controller.selectAnswer(qIndex, val);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingView(LiveQuizController controller) {
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
                'Sisa waktu: ${_formatTime(controller.secondsRemaining)}',
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

  Widget _buildLeaderboard(LiveQuizController controller) {
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
              child: controller.leaderboard.isEmpty
                  ? const Center(child: Text('Belum ada data'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: controller.leaderboard.length,
                      itemBuilder: (context, index) {
                        final entry = controller.leaderboard[index];
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
      ),
    );
  }
}
