import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_model.dart';
import '../../providers/class_provider.dart';
import '../../theme/app_theme.dart';
import '../quiz_detail_screen.dart';

class KelasTab extends StatefulWidget {
  final ClassModel classData;

  const KelasTab({super.key, required this.classData});

  @override
  State<KelasTab> createState() => _KelasTabState();
}

class _KelasTabState extends State<KelasTab> {
  List<TopicModel> _topics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final provider = Provider.of<ClassProvider>(context, listen: false);
    final topics = await provider.fetchTopics(widget.classData.id);
    if (mounted) {
      setState(() {
        _topics = topics;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadTopics,
            child: _topics.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 64),
                      Icon(Icons.folder_open, size: 64, color: AppTheme.primary200),
                      const SizedBox(height: 16),
                      const Text(
                        'No topics found for this class.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      return TopicCard(topic: _topics[index]);
                    },
                  ),
          );
  }
}

class TopicCard extends StatefulWidget {
  final TopicModel topic;

  const TopicCard({super.key, required this.topic});

  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  List<QuizModel> _quizzes = [];
  bool _isLoadingQuizzes = false;

  Future<void> _loadQuizzes() async {
    if (_quizzes.isNotEmpty) return;
    setState(() => _isLoadingQuizzes = true);
    final provider = Provider.of<ClassProvider>(context, listen: false);
    final allQuizzes = await provider.fetchQuizzesForTopic(widget.topic.id);
    if (mounted) {
      setState(() {
        _quizzes = allQuizzes.where((q) => q.status != 'draft').toList();
        _isLoadingQuizzes = false;
      });
    }
  }

  Color _quizStatusColor(String status) {
    switch (status) {
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

  IconData _quizTrailingIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.arrow_forward_ios;
      case 'scheduled':
        return Icons.schedule;
      case 'closed':
        return Icons.lock_outline;
      default:
        return Icons.arrow_forward_ios;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          widget.topic.name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        subtitle: widget.topic.description.isNotEmpty
            ? Text(widget.topic.description, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        onExpansionChanged: (expanded) {
          if (expanded) _loadQuizzes();
        },
        children: [
          if (_isLoadingQuizzes)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_quizzes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No quizzes available in this topic.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ..._quizzes.map((quiz) {
              final statusColor = _quizStatusColor(quiz.status);
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: quiz.mode == 'live' ? Colors.orange.shade50 : AppTheme.primary50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    quiz.mode == 'live' ? Icons.bolt : Icons.assignment,
                    color: quiz.mode == 'live' ? Colors.orange : AppTheme.primary600,
                  ),
                ),
                title: Text(quiz.title),
                subtitle: Row(
                  children: [
                    Text('${quiz.duration} mins • '),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quiz.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                trailing: Icon(_quizTrailingIcon(quiz.status), color: AppTheme.textTertiary, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => QuizDetailScreen(quiz: quiz)),
                  );
                },
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
