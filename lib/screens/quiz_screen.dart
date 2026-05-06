import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/question_model.dart';
import '../providers/quiz_provider.dart';
import '../theme/app_theme.dart';
import 'quiz_result_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'live_leaderboard_screen.dart';

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startQuiz();
      if (widget.quiz.mode == 'live') {
        _initLiveSocket();
      }
    });
  }

  Future<void> _initLiveSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('join:quiz', widget.quiz.id);
    });

    _socket!.on('live:cancelled', (_) {
      if (mounted) {
        _socket!.disconnect();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Live Quiz Cancelled'),
            content: const Text('The teacher has ended this quiz session early.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Go back
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    });
  }

  Future<void> _startQuiz() async {
    final success = await Provider.of<QuizProvider>(context, listen: false).startQuiz(widget.quiz);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<QuizProvider>(context, listen: false).errorMessage ?? 'Failed to start quiz')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave:quiz', widget.quiz.id);
      _socket!.disconnect();
      _socket!.dispose();
    }
    super.dispose();
  }

  void _nextPage(int totalQuestions) {
    if (_currentIndex < totalQuestions - 1) {
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

  Future<void> _submitQuiz() async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: const Text('Are you sure you want to submit? You cannot change your answers after submission.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await provider.submitQuiz();
      if (mounted) {
        if (result != null) {
          if (widget.quiz.mode == 'live') {
            if (_socket != null) {
              _socket!.disconnect();
              _socket!.dispose();
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LiveLeaderboardScreen(quiz: widget.quiz, result: result)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => QuizResultScreen(result: result, quiz: widget.quiz)),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit quiz')),
          );
        }
      }
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave Quiz?'),
            content: const Text('Your progress is saved, but the timer will continue running.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Consumer<QuizProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.questions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.questions.isEmpty) {
              return const Center(child: Text('No questions available.'));
            }

            final questions = provider.questions;
            final isLastQuestion = _currentIndex == questions.length - 1;

            return Column(
              children: [
                // Header (Timer & Progress)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1} of ${questions.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: provider.remainingSeconds < 60 ? Colors.red.shade50 : AppTheme.primary50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: provider.remainingSeconds < 60 ? Colors.red : AppTheme.primary600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(provider.remainingSeconds),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: provider.remainingSeconds < 60 ? Colors.red : AppTheme.primary600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Linear Progress
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / questions.length,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary400),
                ),

                // Questions PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // Disable swipe
                    onPageChanged: (idx) {
                      setState(() {
                        _currentIndex = idx;
                      });
                    },
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      return _buildQuestionCard(questions[index], provider);
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
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppTheme.primary400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Previous', style: TextStyle(color: AppTheme.primary400)),
                          ),
                        )
                      else
                        const Spacer(),
                      
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLastQuestion ? _submitQuiz : () => _nextPage(questions.length),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLastQuestion ? Colors.black : AppTheme.primary400,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(isLastQuestion ? 'Submit Quiz' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, QuizProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${question.points} Points',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 32),
          if (question.type == 'multiple_choice' && question.options != null)
            ...question.options!.map((option) {
              final isSelected = provider.answers[question.id] == option.text;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => provider.saveAnswer(question.id, option.text),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary50 : AppTheme.surfaceCard,
                      border: Border.all(
                        color: isSelected ? AppTheme.primary400 : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary400 : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.primary400,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            option.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected ? AppTheme.primary700 : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList()
          else if (question.type == 'essay')
            TextFormField(
              initialValue: provider.answers[question.id],
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Type your answer here...',
              ),
              onChanged: (val) {
                // Save after a short delay or immediately (debounce would be better, but immediately is fine for now)
                provider.saveAnswer(question.id, val);
              },
            ),
        ],
      ),
    );
  }
}
