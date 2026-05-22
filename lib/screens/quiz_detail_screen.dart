import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import '../theme/app_theme.dart';
import '../utils/quiz_helpers.dart';
import 'quiz_screen.dart';
import 'live_quiz_waiting_screen.dart';
import '../../config/api_config.dart';
import '../services/token_service.dart';
import '../widgets/score_badge.dart';
import 'answer_key_screen.dart';

class QuizDetailScreen extends StatefulWidget {
  final QuizModel quiz;

  const QuizDetailScreen({super.key, required this.quiz});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final String baseUrl = ApiConfig.baseUrl;
  bool _isLoading = true;
  late QuizModel _quiz;
  int _attemptCount = 0;
  int _attemptLimit = 1;
  bool _isLiveSessionOpen = false;
  Map<String, dynamic>? _lastAttemptResult;
  Map<String, dynamic>? _bestAttemptResult;
  bool _showAnswerKey = false;

  @override
  void initState() {
    super.initState();
    _quiz = widget.quiz;
    _loadQuizInfo();
  }

  Future<void> _loadQuizInfo() async {
    setState(() => _isLoading = true);

    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;

      // Fetch quiz details (for attemptLimit)
      final quizRes = await http.get(
        Uri.parse('$baseUrl/quizzes/${widget.quiz.id}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (quizRes.statusCode == 200) {
        final quizData = json.decode(quizRes.body)['quiz'];
        _quiz = QuizModel.fromJson(quizData);
        _attemptLimit = quizData['attemptLimit'] ?? 1;
        _isLiveSessionOpen = quizData['isLiveSessionOpen'] ?? false;
        _showAnswerKey = quizData['showAnswerKey'] ?? false;
      }

      // Fetch user's attempts for this quiz
      final attemptsRes = await http.get(
        Uri.parse('$baseUrl/attempts?quizId=${widget.quiz.id}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (attemptsRes.statusCode == 200) {
        final data = json.decode(attemptsRes.body);
        final List<dynamic> attempts = data['attempts'] ?? [];
        _attemptCount = attempts.length;

        // Find last submitted attempt for showing result
        final submitted = attempts.where((a) => a['status'] == 'submitted').toList();
        if (submitted.isNotEmpty) {
          _lastAttemptResult = submitted.first;

          // Find best attempt (highest score)
          Map<String, dynamic>? best;
          for (final a in submitted) {
            final score = (a['score'] ?? a['earnedPoints'] ?? 0) as num;
            final bestScore = (best?['score'] ?? best?['earnedPoints'] ?? -1) as num;
            if (best == null || score > bestScore) {
              best = a;
            }
          }
          _bestAttemptResult = best;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load quiz info. Check your connection.')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _canAttempt {
    if (_quiz.mode == 'live') {
      if (_quiz.status == 'finished' || _quiz.status == 'closed') return false;
      return _isLiveSessionOpen;
    }
    // Regular quizzes
    if (_quiz.status != 'open') return false;
    if (_attemptCount >= _attemptLimit) return false;
    return true;
  }

  bool get _canViewAnswerKey {
    if (!_showAnswerKey) return false;
    if (_attemptCount == 0) return false;
    // Allow if all attempts used OR quiz is closed/finished
    final allAttemptsUsed = _attemptCount >= _attemptLimit;
    final quizExpired = _quiz.status == 'closed' || _quiz.status == 'finished';
    if (!allAttemptsUsed && !quizExpired) return false;
    final submitted = _lastAttemptResult != null;
    return submitted;
  }

  String get _statusLabel => quizStatusLabel(_quiz.status);

  Color get _statusColor => quizStatusColor(_quiz.status);

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(DateTime? closeAt) {
    if (closeAt == null) return '-';
    final now = DateTime.now();
    if (closeAt.isBefore(now)) return 'Sudah ditutup';
    final diff = closeAt.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '${hours}j ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Detail'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Quiz Title
                Text(
                  _quiz.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                // Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_quiz.mode == 'live') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.live.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.live.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 14, color: AppTheme.live),
                            const SizedBox(width: 4),
                            Text('Live', style: TextStyle(color: AppTheme.live, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Info Cards
                _buildInfoCard(Icons.timer_outlined, 'Duration', '${_quiz.duration} minutes'),
                _buildInfoCard(Icons.repeat, 'Attempts', '$_attemptCount / $_attemptLimit used'),
                if (_quiz.questionCount != null)
                  _buildInfoCard(Icons.help_outline, 'Questions', '${_quiz.questionCount}'),
                if (_quiz.mode != 'live')
                  _buildInfoCard(
                    _quiz.allowBacktrack ? Icons.arrow_back : Icons.block,
                    'Revisi jawaban',
                    _quiz.allowBacktrack ? 'Ya (bisa kembali)' : 'Tidak (jawaban terkunci)',
                  ),
                if (_quiz.scheduledOpen != null)
                  _buildInfoCard(Icons.event, 'Opens', _formatDate(_quiz.scheduledOpen)),
                if (_quiz.scheduledClose != null)
                  _buildInfoCard(Icons.event_busy, 'Closes', _formatDate(_quiz.scheduledClose)),
                if (_quiz.mode == 'scheduled' && _quiz.scheduledClose != null) ...[
                  _buildInfoCard(Icons.hourglass_bottom, 'Sisa waktu', _formatRemaining(_quiz.scheduledClose)),
                ],
                if (_quiz.description != null && _quiz.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_quiz.description!, style: Theme.of(context).textTheme.bodyMedium),
                ],

                const SizedBox(height: 32),

                // Best Score (for multi-attempt) or Last Score
                if (_bestAttemptResult != null) ...[
                  Card(
                    color: AppTheme.primary50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: AppTheme.primary600, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _attemptLimit > 1 ? 'Nilai Terbaik' : 'Nilai Kamu',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${_bestAttemptResult!['earnedPoints'] ?? _bestAttemptResult!['score'] ?? '-'} / ${_bestAttemptResult!['totalPoints'] ?? '-'} pts',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary700),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_bestAttemptResult!['totalPoints'] != null && _bestAttemptResult!['totalPoints'] > 0)
                                      ScoreBadge(
                                        text: '${(((_bestAttemptResult!['earnedPoints'] ?? _bestAttemptResult!['score'] ?? 0) / _bestAttemptResult!['totalPoints']) * 100).round()}%',
                                        isHigh: true,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Answer Key Button
                if (_canViewAnswerKey) ...[                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnswerKeyScreen(
                              quizId: widget.quiz.id,
                              quizTitle: _quiz.title,
                              attemptId: _bestAttemptResult!['_id'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Lihat Kunci Jawaban'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.primary400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canAttempt
                        ? () async {
                            if (_quiz.mode == 'live') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LiveQuizWaitingScreen()),
                              );
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => QuizScreen(quiz: _quiz)),
                              );
                            }
                            // Refresh info after returning
                            _loadQuizInfo();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _attemptCount >= _attemptLimit
                          ? 'Attempt Limit Reached'
                          : _quiz.status == 'scheduled'
                              ? 'Quiz Not Yet Open'
                              : (_quiz.status == 'closed' || _quiz.status == 'finished')
                                  ? (_quiz.mode == 'live' ? 'Sesi Selesai' : 'Quiz Closed')
                                  : _quiz.mode == 'live'
                                      ? (_isLiveSessionOpen ? 'Join Live Quiz' : 'Menunggu Sesi Dimulai')
                                      : 'Start Quiz',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary600, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
