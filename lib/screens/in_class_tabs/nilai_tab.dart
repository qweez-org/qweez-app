import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/class_model.dart';
import '../../theme/app_theme.dart';
import '../../../config/api_config.dart';
import '../../services/token_service.dart';

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
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_quizGrades.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.leaderboard_outlined, size: 64, color: AppTheme.primary200),
          const SizedBox(height: 16),
          const Text('No grades available yet.', style: TextStyle(color: AppTheme.textSecondary)),
        ]),
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
              border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade200)),
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
                    Padding(padding: const EdgeInsets.all(12), child: Text(pct != null ? '$pct%' : '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: pct == null ? AppTheme.textTertiary : pct >= 70 ? const Color(0xFF22C55E) : pct >= 40 ? Colors.orange : Colors.red))),
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
