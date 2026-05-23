import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/question_model.dart';
import '../providers/quiz_provider.dart';
import '../theme/app_theme.dart';
import 'quiz_result_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import 'live_leaderboard_screen.dart';
import '../services/token_service.dart';

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;
  final num? previousBestScore;

  const QuizScreen({super.key, required this.quiz, this.previousBestScore});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  io.Socket? _socket;

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
    final token = await TokenService.getAccessToken();
    if (token == null) return;

    final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
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
    // Reset page position before loading
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    setState(() => _currentIndex = 0);

    final provider = Provider.of<QuizProvider>(context, listen: false);
    final success = await provider.startQuiz(widget.quiz);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Failed to start quiz')),
      );
      Navigator.pop(context);
      return;
    }
    // Jump to first unanswered question if resuming
    if (mounted && provider.resumeIndex > 0 && _pageController.hasClients) {
      _pageController.jumpToPage(provider.resumeIndex);
      setState(() => _currentIndex = provider.resumeIndex);
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
            final canViewAnswerKey = result['canViewAnswerKey'] == true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => QuizResultScreen(
                result: result,
                quiz: widget.quiz,
                previousBestScore: widget.previousBestScore,
                canViewAnswerKey: canViewAnswerKey,
              )),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave Quiz?'),
            content: const Text('Your progress is saved, but the timer will continue running.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: AppTheme.error))),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: SafeArea(
          child: Consumer<QuizProvider>(
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
                      border: Border(bottom: BorderSide(color: AppTheme.gray200)),
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
                            color: provider.remainingSeconds < 60 ? AppTheme.error.withValues(alpha: 0.08) : AppTheme.primary50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: provider.remainingSeconds < 60 ? AppTheme.error : AppTheme.primary600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(provider.remainingSeconds),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: provider.remainingSeconds < 60 ? AppTheme.error : AppTheme.primary600,
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
                    backgroundColor: AppTheme.gray200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary400),
                  ),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    curve: Curves.linear,
                    tween: Tween<double>(
                      begin: provider.remainingSeconds / (widget.quiz.duration * 60),
                      end: provider.remainingSeconds / (widget.quiz.duration * 60),
                    ),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: AppTheme.primary100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          provider.remainingSeconds <= 60 ? AppTheme.error : AppTheme.primary500,
                        ),
                        minHeight: 3,
                      );
                    },
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        if (_currentIndex > 0 && widget.quiz.allowBacktrack)
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
                              backgroundColor: isLastQuestion ? AppTheme.textPrimary : AppTheme.primary400,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              isLastQuestion ? 'Submit' : 'Next',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, QuizProvider provider) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
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
                        color: isSelected ? AppTheme.primary400 : AppTheme.gray300,
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
                              color: isSelected ? AppTheme.primary400 : AppTheme.gray400,
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
            })
          else if (question.type == 'true_false' && question.options != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: question.options!.map((option) {
                  final isSelected = provider.answers[question.id] == option.text;
                  final isBenar = option.text == 'Benar';
                  
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isBenar ? 0 : 8,
                        right: isBenar ? 8 : 0,
                      ),
                      child: isSelected
                          ? ElevatedButton.icon(
                              onPressed: () => provider.saveAnswer(question.id, option.text),
                              icon: Icon(isBenar ? Icons.check : Icons.close, size: 20),
                              label: Text(
                                option.text,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => provider.saveAnswer(question.id, option.text),
                              icon: Icon(isBenar ? Icons.check : Icons.close, size: 20, color: AppTheme.primary500),
                              label: Text(
                                option.text,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary500),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primary400, width: 2),
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
            )
          else if (question.type == 'short_answer')
            TextFormField(
              initialValue: provider.answers[question.id],
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Ketik jawaban Anda di sini...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                // Save after a short delay or immediately (debounce would be better, but immediately is fine for now)
                provider.saveAnswer(question.id, val);
              },
            ),
        ],
      ),
        ),
      ),
    );
  }
}
