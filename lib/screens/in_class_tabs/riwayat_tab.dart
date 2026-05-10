import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/class_model.dart';
import '../../theme/app_theme.dart';
import '../../../config/api_config.dart';
import '../../services/token_service.dart';

class RiwayatTab extends StatefulWidget {
  final ClassModel classData;
  const RiwayatTab({super.key, required this.classData});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<RiwayatTab> {
  final String baseUrl = ApiConfig.baseUrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
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
        _attempts = grades.map<Map<String, dynamic>>((a) {
          final quiz = a['quizId'];
          return {
            'quizTitle': quiz is Map ? (quiz['title'] ?? 'Quiz') : 'Quiz',
            'totalPoints': a['totalPoints'] ?? 0,
            'earnedPoints': a['earnedPoints'] ?? a['score'] ?? 0,
            'submittedAt': a['submittedAt'],
          };
        }).toList();
      }
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.day}/${l.month}/${l.year} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_attempts.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history, size: 64, color: AppTheme.primary200),
          const SizedBox(height: 16),
          const Text('No quiz attempts yet.', style: TextStyle(color: AppTheme.textSecondary)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAttempts,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _attempts.length,
        itemBuilder: (_, i) {
          final a = _attempts[i];
          final earned = a['earnedPoints'] ?? 0;
          final total = a['totalPoints'] ?? 0;
          final pct = total > 0 ? (earned / total * 100).round() : 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: (pct >= 70 ? const Color(0xFF22C55E) : pct >= 40 ? Colors.orange : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: pct >= 70 ? const Color(0xFF22C55E) : pct >= 40 ? Colors.orange : Colors.red))),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['quizTitle'], style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text('$earned / $total pts • ${_formatDate(a['submittedAt'])}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }
}
