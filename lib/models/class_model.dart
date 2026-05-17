class Teacher {
  final String id;
  final String name;
  final String email;

  Teacher({required this.id, required this.name, required this.email});

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class ClassModel {
  final String id;
  final String name;
  final String description;
  final String code;
  final Teacher? owner;
  final String? membershipStatus; // e.g. 'approved', 'pending'

  ClassModel({
    required this.id,
    required this.name,
    required this.description,
    required this.code,
    this.owner,
    this.membershipStatus,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      code: json['code'] ?? '',
      owner: json['owner'] != null ? Teacher.fromJson(json['owner']) : null,
      membershipStatus: json['membershipStatus'],
    );
  }
}

class TopicModel {
  final String id;
  final String classId;
  final String name;
  final String description;
  final DateTime createdAt;

  TopicModel({
    required this.id,
    required this.classId,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['_id'] ?? '',
      classId: json['classId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class QuizModel {
  final String id;
  final String topicId;
  final String title;
  final String? description;
  final String mode; // scheduled, manual, live
  final String status; // draft, scheduled, open, closed, waiting, in_progress, finished
  final int duration; // minutes
  final int? questionCount;
  final DateTime? scheduledOpen;
  final DateTime? scheduledClose;
  final bool allowBacktrack;
  final bool? isCompleted;
  final bool? isLiveSessionOpen;
  final bool shuffleQuestions;
  final bool shuffleOptions;

  QuizModel({
    required this.id,
    required this.topicId,
    required this.title,
    this.description,
    required this.mode,
    required this.status,
    required this.duration,
    this.questionCount,
    this.scheduledOpen,
    this.scheduledClose,
    this.allowBacktrack = true,
    this.isCompleted,
    this.isLiveSessionOpen,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['_id'] ?? '',
      topicId: json['topicId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      mode: json['mode'] ?? 'manual',
      status: json['status'] ?? 'draft',
      duration: json['duration'] ?? 30,
      questionCount: json['questionCount'],
      scheduledOpen: json['scheduledOpen'] != null ? DateTime.tryParse(json['scheduledOpen']) : null,
      scheduledClose: json['scheduledClose'] != null ? DateTime.tryParse(json['scheduledClose']) : null,
      allowBacktrack: json['allowBacktrack'] ?? true,
      isCompleted: json['isCompleted'],
      isLiveSessionOpen: json['isLiveSessionOpen'],
      shuffleQuestions: json['shuffleQuestions'] ?? false,
      shuffleOptions: json['shuffleOptions'] ?? false,
    );
  }
}
