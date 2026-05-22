import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_model.dart';
import '../../providers/class_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/quiz_helpers.dart';
import '../quiz_detail_screen.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/empty_state.dart';

class KelasTab extends StatefulWidget {
  final ClassModel classData;

  const KelasTab({super.key, required this.classData});

  @override
  State<KelasTab> createState() => _KelasTabState();
}

class _KelasTabState extends State<KelasTab> {
  List<TopicModel> _topics = [];
  bool _isLoading = true;
  int _refreshKey = 0;

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
        _refreshKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 3,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: ShimmerCard(height: 100),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadTopics,
            child: _topics.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_open,
                    title: 'No topics found for this class.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      return TopicCard(key: ValueKey('${_topics[index].id}_$_refreshKey'), topic: _topics[index]);
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
              final statusColor = quizStatusColor(quiz.status);
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: quiz.mode == 'live' ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.primary50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    quiz.mode == 'live' ? Icons.bolt : Icons.assignment,
                    color: quiz.mode == 'live' ? AppTheme.live : AppTheme.primary600,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(quiz.title)),
                    if (quiz.isCompleted == true)
                      const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                  ],
                ),
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
                        quizStatusLabel(quiz.status),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                trailing: Icon(quizTrailingIcon(quiz.status), color: AppTheme.textTertiary, size: 18),
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
