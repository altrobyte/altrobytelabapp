class Question {
  String question;
  Map<String, String> options;
  String correct;
  String explanation;
  String difficulty;
  String topic;
  int qualityScore;
  List<String> qualityIssues;
  int estimatedTimeSecs;

  Question({
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
    required this.difficulty,
    required this.topic,
    this.qualityScore = 100,
    this.qualityIssues = const [],
    this.estimatedTimeSecs = 60,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        question: j['question'] ?? '',
        options: Map<String, String>.from(j['options'] ?? {}),
        correct: j['correct'] ?? 'A',
        explanation: j['explanation'] ?? '',
        difficulty: j['difficulty'] ?? 'Medium',
        topic: j['topic'] ?? '',
        qualityScore: j['quality_score'] ?? 100,
        qualityIssues: List<String>.from(j['quality_issues'] ?? []),
        estimatedTimeSecs: j['estimated_time_seconds'] ?? 60,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correct': correct,
        'explanation': explanation,
        'difficulty': difficulty,
        'topic': topic,
        'quality_score': qualityScore,
        'quality_issues': qualityIssues,
        'estimated_time_seconds': estimatedTimeSecs,
      };

  Question copyWith({
    String? question,
    Map<String, String>? options,
    String? correct,
    String? explanation,
    String? difficulty,
    String? topic,
    int? qualityScore,
    List<String>? qualityIssues,
    int? estimatedTimeSecs,
  }) {
    return Question(
      question: question ?? this.question,
      options: options ?? Map.from(this.options),
      correct: correct ?? this.correct,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      topic: topic ?? this.topic,
      qualityScore: qualityScore ?? this.qualityScore,
      qualityIssues: qualityIssues ?? List.from(this.qualityIssues),
      estimatedTimeSecs: estimatedTimeSecs ?? this.estimatedTimeSecs,
    );
  }
}

class AltroTest {
  final int id;
  final int instituteId;
  final int? batchId;
  final String title;
  final String subject;
  final String topic;
  final String difficulty;
  final String examType;
  List<Question> questions; // Mutable for expert review
  final int durationMins;

  /// Total time for the paper, in seconds. Overrides [durationMins] when
  /// set — the only way to express a test shorter than a minute.
  final int durationSeconds;
  final DateTime? createdAt;
  final int? attempts;
  int qualityScore;

  AltroTest({
    required this.id,
    required this.instituteId,
    this.batchId,
    required this.title,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.examType,
    required this.questions,
    required this.durationMins,
    this.durationSeconds = 0,
    this.createdAt,
    this.attempts,
    this.qualityScore = 0,
  });

  factory AltroTest.fromJson(Map<String, dynamic> j) {
    List<Question> qs = [];
    final raw = j['questions_json'];
    if (raw is List) {
      qs = raw.map((q) => Question.fromJson(Map<String, dynamic>.from(q))).toList();
    }
    return AltroTest(
      id: j['id'] ?? 0,
      instituteId: j['institute_id'] ?? 0,
      batchId: j['batch_id'],
      title: j['title'] ?? '',
      subject: j['subject'] ?? '',
      topic: j['topic'] ?? '',
      difficulty: j['difficulty'] ?? 'Medium',
      examType: j['exam_type'] ?? 'General',
      questions: qs,
      durationMins: j['duration_mins'] ?? 30,
      durationSeconds: j['duration_seconds'] ?? 0,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      attempts: j['attempts'],
      qualityScore: j['quality_score'] ?? 0,
    );
  }

  /// Recalculate average quality score from questions
  void recalculateQuality() {
    if (questions.isEmpty) {
      qualityScore = 0;
      return;
    }
    qualityScore = questions.fold<int>(0, (sum, q) => sum + q.qualityScore) ~/ questions.length;
  }

  /// Topic distribution counts
  Map<String, int> get topicDistribution {
    final map = <String, int>{};
    for (final q in questions) {
      final t = q.topic.isNotEmpty ? q.topic : 'Other';
      map[t] = (map[t] ?? 0) + 1;
    }
    return map;
  }

  /// Difficulty distribution counts
  Map<String, int> get difficultyDistribution {
    final map = <String, int>{};
    for (final q in questions) {
      final d = q.difficulty.isNotEmpty ? q.difficulty : 'Medium';
      map[d] = (map[d] ?? 0) + 1;
    }
    return map;
  }
}

class TestAttemptResult {
  final int id;
  final int testId;
  final int score;
  final int total;
  final double percentage;
  final DateTime? completedAt;

  TestAttemptResult({
    required this.id,
    required this.testId,
    required this.score,
    required this.total,
    required this.percentage,
    this.completedAt,
  });

  factory TestAttemptResult.fromJson(Map<String, dynamic> j) =>
      TestAttemptResult(
        id: j['id'] ?? 0,
        testId: j['test_id'] ?? 0,
        score: j['score'] ?? 0,
        total: j['total'] ?? 0,
        percentage: (j['percentage'] ?? 0).toDouble(),
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'])
            : null,
      );
}
