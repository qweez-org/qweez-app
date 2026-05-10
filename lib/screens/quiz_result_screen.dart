import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../theme/app_theme.dart';

class QuizResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final QuizModel quiz;

  const QuizResultScreen({super.key, required this.result, required this.quiz});

  @override
  Widget build(BuildContext context) {
    final attempt = result['attempt'];
    final totalPoints = result['totalPoints'] ?? 0;
    final earnedPoints = result['earnedPoints'] ?? result['score'] ?? 0;
    final status = attempt['status'];

    final bool isPending = status == 'submitted' && result['needsManualGrading'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Result'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange.shade50 : AppTheme.primary50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending ? Icons.hourglass_empty : Icons.emoji_events,
                  size: 50,
                  color: isPending ? Colors.orange : AppTheme.primary400,
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
                  'Your attempt has been submitted successfully.\nIt contains essay questions that require manual grading by your teacher.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, height: 1.5),
                )
              else ...[
                const Text(
                  'Your Score',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  '$earnedPoints / $totalPoints',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.primary600),
                ),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop back to class detail or home
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Back to Dashboard'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
