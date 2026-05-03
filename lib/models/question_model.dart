class QuestionModel {
  final String id;
  final String quizId;
  final String text;
  final String type; // multiple_choice, essay
  final int points;
  final List<OptionModel>? options;
  final int order;

  QuestionModel({
    required this.id,
    required this.quizId,
    required this.text,
    required this.type,
    required this.points,
    this.options,
    required this.order,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['_id'] ?? '',
      quizId: json['quizId'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'multiple_choice',
      points: json['points'] ?? 10,
      options: json['options'] != null
          ? (json['options'] as List).map((o) => OptionModel.fromJson(o)).toList()
          : null,
      order: json['order'] ?? 0,
    );
  }
}

class OptionModel {
  final String text;
  final bool isCorrect;

  OptionModel({required this.text, required this.isCorrect});

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      text: json['text'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
    );
  }
}

class AttemptModel {
  final String id;
  final String quizId;
  final String studentId;
  final int? score;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final String status; // in_progress, submitted, graded

  AttemptModel({
    required this.id,
    required this.quizId,
    required this.studentId,
    this.score,
    required this.startedAt,
    this.submittedAt,
    required this.status,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    return AttemptModel(
      id: json['_id'] ?? '',
      quizId: json['quizId'] ?? '',
      studentId: json['studentId'] ?? '',
      score: json['score'],
      startedAt: DateTime.tryParse(json['startedAt'] ?? '') ?? DateTime.now(),
      submittedAt: json['submittedAt'] != null ? DateTime.tryParse(json['submittedAt']) : null,
      status: json['status'] ?? 'in_progress',
    );
  }
}
