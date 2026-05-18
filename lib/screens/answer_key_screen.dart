import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../../config/api_config.dart';
import '../services/token_service.dart';

class AnswerKeyScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final String attemptId;

  const AnswerKeyScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.attemptId,
  });

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final PageController _pageController = PageController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _review = [];
  int _score = 0;
  int _totalPoints = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchReview();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchReview() async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/attempts/${widget.attemptId}/review'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _review = List<Map<String, dynamic>>.from(data['review'] ?? []);
          _score = data['attempt']?['score'] ?? 0;
          _totalPoints = data['attempt']?['totalPoints'] ?? 0;
          _isLoading = false;
        });
      } else {
        final msg = json.decode(res.body)['message'] ?? 'Gagal memuat kunci jawaban';
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal terhubung ke server.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunci Jawaban'),
        bottom: _review.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _review.length,
                  backgroundColor: AppTheme.gray200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary400),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Kembali'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Score header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          border: Border(bottom: BorderSide(color: AppTheme.gray200)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Soal ${_currentPage + 1} / ${_review.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_score / $_totalPoints pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Question pages
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemCount: _review.length,
                          itemBuilder: (context, index) {
                            return _buildReviewCard(_review[index], index);
                          },
                        ),
                      ),
                      // Navigation
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            if (_currentPage > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: AppTheme.primary400),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Sebelumnya'),
                                ),
                              )
                            else
                              const Spacer(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentPage < _review.length - 1
                                    ? () => _pageController.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      )
                                    : () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  _currentPage < _review.length - 1 ? 'Selanjutnya' : 'Selesai',
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

  Widget _buildReviewCard(Map<String, dynamic> item, int index) {
    final isCorrect = item['isCorrect'] == true;
    final earnedPts = item['earnedPoints'] ?? 0;
    final totalPts = item['points'] ?? 0;
    final type = item['type'] ?? 'multiple_choice';
    final studentAnswer = item['studentAnswer'] as String?;
    final correctAnswers = List<String>.from(item['correctAnswers'] ?? []);
    final options = item['options'] as List?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isCorrect ? AppTheme.success : AppTheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCorrect ? 'Benar' : 'Salah',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isCorrect ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$earnedPts / $totalPts pts',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question text
          Text(
            item['text'] ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Multiple choice options with correct/incorrect indicators
          if (type == 'multiple_choice' && options != null)
            ...options.asMap().entries.map((entry) {
              final opt = Map<String, dynamic>.from(entry.value as Map);
              final optText = opt['text'] ?? '';
              final optCorrect = opt['isCorrect'] == true;
              final isStudentPick = studentAnswer == optText;

              Color bgColor = AppTheme.gray50;
              Color borderColor = AppTheme.gray300;
              double borderWidth = 1;

              if (optCorrect) {
                bgColor = AppTheme.success.withValues(alpha: 0.08);
                borderColor = AppTheme.success;
                borderWidth = 2;
              }
              if (isStudentPick && !optCorrect) {
                bgColor = AppTheme.error.withValues(alpha: 0.08);
                borderColor = AppTheme.error;
                borderWidth = 2;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Row(
                  children: [
                    Icon(
                      optCorrect
                          ? Icons.check_circle
                          : (isStudentPick ? Icons.cancel : Icons.radio_button_unchecked),
                      color: optCorrect
                          ? AppTheme.success
                          : (isStudentPick ? AppTheme.error : AppTheme.gray400),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        optText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: (optCorrect || isStudentPick) ? FontWeight.w600 : FontWeight.normal,
                          color: optCorrect
                              ? AppTheme.success
                              : (isStudentPick ? AppTheme.error : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    if (isStudentPick)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (optCorrect ? AppTheme.success : AppTheme.error).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Jawabanmu',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: optCorrect ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

          // Short answer review
          if (type == 'short_answer') ...[
            // Student's answer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppTheme.success.withValues(alpha: 0.08)
                    : AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? AppTheme.success : AppTheme.error,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jawabanmu:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCorrect ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    studentAnswer ?? '(tidak dijawab)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCorrect ? AppTheme.success : AppTheme.error,
                      fontStyle: studentAnswer == null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jawaban yang benar:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      correctAnswers.join(' / '),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
