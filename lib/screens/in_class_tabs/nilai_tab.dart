import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/class_model.dart';
import '../../theme/app_theme.dart';

import '../../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/score_badge.dart';

class NilaiTab extends StatefulWidget {
  final ClassModel classData;
  const NilaiTab({super.key, required this.classData});

  @override
  State<NilaiTab> createState() => _NilaiTabState();
}

class _NilaiTabState extends State<NilaiTab> {
  final String baseUrl = ApiConfig.baseUrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> _quizGrades = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('$baseUrl/grades/classes/${widget.classData.id}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> grades = data['grades'] ?? [];
        final List<dynamic> quizzes = data['quizzes'] ?? [];

        // Build a map: quizId -> best attempt
        final Map<String, Map<String, dynamic>> bestByQuiz = {};
        for (final g in grades) {
          final qid = g['quizId'] is Map ? g['quizId']['_id'] : g['quizId'];
          final qTitle = g['quizId'] is Map ? (g['quizId']['title'] ?? 'Quiz') : 'Quiz';
          final earned = g['earnedPoints'] ?? g['score'] ?? 0;
          if (!bestByQuiz.containsKey(qid) || earned > (bestByQuiz[qid]!['earned'] ?? 0)) {
            bestByQuiz[qid] = {'title': qTitle, 'earned': earned, 'total': g['totalPoints'] ?? 0};
          }
        }

        // Also include quizzes with no attempt
        for (final q in quizzes) {
          final qid = q['_id'];
          if (!bestByQuiz.containsKey(qid)) {
            bestByQuiz[qid] = {'title': q['title'] ?? 'Quiz', 'earned': null, 'total': null};
          }
        }

        _quizGrades = bestByQuiz.values.toList();
      }
    } catch (e) {
      _errorMessage = 'Failed to load grades. Check your connection.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 1,
        itemBuilder: (context, index) => const ShimmerCard(height: 300),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadGrades, child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (_quizGrades.isEmpty) {
      return const EmptyState(
        icon: Icons.leaderboard_outlined,
        title: 'No grades available yet.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGrades,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Gradebook', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Card(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.5),
              },
              border: TableBorder.symmetric(inside: BorderSide(color: AppTheme.gray200)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: AppTheme.primary50),
                  children: const [
                    Padding(padding: EdgeInsets.all(12), child: Text('Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Padding(padding: EdgeInsets.all(12), child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Padding(padding: EdgeInsets.all(12), child: Text('%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
                ..._quizGrades.map((g) {
                  final earned = g['earned'];
                  final total = g['total'];
                  final hasScore = earned != null && total != null;
                  final pct = hasScore && total > 0 ? (earned / total * 100).round() : null;
                  return TableRow(children: [
                    Padding(padding: const EdgeInsets.all(12), child: Text(g['title'], style: const TextStyle(fontSize: 13))),
                    Padding(padding: const EdgeInsets.all(12), child: Text(hasScore ? '$earned/$total' : '-', style: const TextStyle(fontSize: 13))),
                    Padding(padding: const EdgeInsets.all(12), child: pct != null 
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: ScoreBadge(
                            text: '$pct%',
                            isHigh: pct >= 80,
                            isMid: pct >= 60 && pct < 80,
                            isLow: pct < 60,
                          ),
                        ) 
                      : const Text('-', style: TextStyle(fontSize: 13, color: AppTheme.textTertiary))),
                  ]);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
