import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../theme/app_theme.dart';

class QuizResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final QuizModel quiz;
  final num? previousBestScore;

  const QuizResultScreen({
    super.key,
    required this.result,
    required this.quiz,
    this.previousBestScore,
  });

  @override
  Widget build(BuildContext context) {
    final attempt = result['attempt'];
    final totalPoints = result['totalPoints'] ?? 0;
    final earnedPoints = result['earnedPoints'] ?? result['score'] ?? 0;
    final status = attempt['status'];
    final bool isPending = status == 'submitted' && result['needsManualGrading'] == true;

    final bool isNewBest = previousBestScore == null || (earnedPoints as num) > previousBestScore!;
    final bool isMultiAttempt = (quiz.attemptLimit ?? 1) > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Quiz'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPending ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.primary50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending ? Icons.hourglass_empty : Icons.emoji_events,
                  size: 50,
                  color: isPending ? AppTheme.warning : AppTheme.primary400,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                quiz.title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isPending)
                const Text(
                  'Jawaban berhasil dikirim.\nMenunggu penilaian dari guru.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, height: 1.5),
                )
              else ...[
                if (isMultiAttempt && isNewBest) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🎉 Nilai Terbaik Baru!',
                      style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Nilai Kamu',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  '$earnedPoints / $totalPoints pts (${totalPoints > 0 ? ((earnedPoints / totalPoints) * 100).round() : 0}%)',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary600),
                ),
                if (isMultiAttempt && !isNewBest && previousBestScore != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Nilai Terbaik: ${previousBestScore!.toInt()} / $totalPoints pts',
                    style: const TextStyle(fontSize: 14, color: AppTheme.textTertiary),
                  ),
                ],
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Kembali'),
                ),
              )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
