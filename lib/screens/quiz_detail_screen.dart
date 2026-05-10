import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';
import 'live_quiz_waiting_screen.dart';
import '../../config/api_config.dart';
import '../services/token_service.dart';

class QuizDetailScreen extends StatefulWidget {
  final QuizModel quiz;

  const QuizDetailScreen({super.key, required this.quiz});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final String baseUrl = ApiConfig.baseUrl;
  bool _isLoading = true;
  int _attemptCount = 0;
  int _attemptLimit = 1;
  Map<String, dynamic>? _lastAttemptResult;

  @override
  void initState() {
    super.initState();
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
        _attemptLimit = quizData['attemptLimit'] ?? 1;
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
        }
      }
    } catch (e) {
      // Ignore
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _canAttempt {
    if (widget.quiz.status != 'open') return false;
    if (_attemptCount >= _attemptLimit) return false;
    return true;
  }

  String get _statusLabel {
    switch (widget.quiz.status) {
      case 'draft':
        return 'Draft';
      case 'scheduled':
        return 'Scheduled';
      case 'open':
        return 'Open';
      case 'closed':
        return 'Closed';
      default:
        return widget.quiz.status.toUpperCase();
    }
  }

  Color get _statusColor {
    switch (widget.quiz.status) {
      case 'open':
        return const Color(0xFF22C55E);
      case 'scheduled':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      default:
        return AppTheme.textTertiary;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                  widget.quiz.title,
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
                    if (widget.quiz.mode == 'live') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text('Live', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Info Cards
                _buildInfoCard(Icons.timer_outlined, 'Duration', '${widget.quiz.duration} minutes'),
                _buildInfoCard(Icons.repeat, 'Attempts', '$_attemptCount / $_attemptLimit used'),
                if (widget.quiz.questionCount != null)
                  _buildInfoCard(Icons.help_outline, 'Questions', '${widget.quiz.questionCount}'),
                if (widget.quiz.scheduledOpen != null)
                  _buildInfoCard(Icons.event, 'Opens', _formatDate(widget.quiz.scheduledOpen)),
                if (widget.quiz.scheduledClose != null)
                  _buildInfoCard(Icons.event_busy, 'Closes', _formatDate(widget.quiz.scheduledClose)),
                if (widget.quiz.description != null && widget.quiz.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(widget.quiz.description!, style: Theme.of(context).textTheme.bodyMedium),
                ],

                const SizedBox(height: 32),

                // Last Result
                if (_lastAttemptResult != null) ...[
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
                                const Text('Your Last Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_lastAttemptResult!['earnedPoints'] ?? _lastAttemptResult!['score'] ?? '-'} / ${_lastAttemptResult!['totalPoints'] ?? '-'} pts',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary700),
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

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canAttempt
                        ? () async {
                            if (widget.quiz.mode == 'live') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LiveQuizWaitingScreen()),
                              );
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => QuizScreen(quiz: widget.quiz)),
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
                          : widget.quiz.status == 'scheduled'
                              ? 'Quiz Not Yet Open'
                              : widget.quiz.status == 'closed'
                                  ? 'Quiz Closed'
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
