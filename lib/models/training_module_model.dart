// Training Module data models — hierarchical:
// TrainingModule → ModuleTopic → ModuleSubtopic → ContentItem
//
// ContentItem types: notes (HTML), test (links to AltroTest), video (YouTube)

class ContentItem {
  final int id;
  final int subtopicId;
  final String type; // 'notes' | 'test' | 'video'
  final String title;
  final int order;

  // Type-specific fields
  final String? htmlContent; // for notes
  final int? testId; // for test — links to existing AltroTest
  final String? testTitle; // display name for linked test
  final String? youtubeUrl; // for video

  ContentItem({
    required this.id,
    required this.subtopicId,
    required this.type,
    required this.title,
    this.order = 0,
    this.htmlContent,
    this.testId,
    this.testTitle,
    this.youtubeUrl,
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) => ContentItem(
        id: j['id'] ?? 0,
        subtopicId: j['subtopic_id'] ?? 0,
        type: j['type'] ?? 'notes',
        title: j['title'] ?? '',
        order: j['order'] ?? 0,
        htmlContent: j['html_content'],
        testId: j['test_id'],
        testTitle: j['test_title'],
        youtubeUrl: j['youtube_url'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subtopic_id': subtopicId,
        'type': type,
        'title': title,
        'order': order,
        if (htmlContent != null) 'html_content': htmlContent,
        if (testId != null) 'test_id': testId,
        if (testTitle != null) 'test_title': testTitle,
        if (youtubeUrl != null) 'youtube_url': youtubeUrl,
      };

  ContentItem copyWith({
    int? id,
    int? subtopicId,
    String? type,
    String? title,
    int? order,
    String? htmlContent,
    int? testId,
    String? testTitle,
    String? youtubeUrl,
  }) =>
      ContentItem(
        id: id ?? this.id,
        subtopicId: subtopicId ?? this.subtopicId,
        type: type ?? this.type,
        title: title ?? this.title,
        order: order ?? this.order,
        htmlContent: htmlContent ?? this.htmlContent,
        testId: testId ?? this.testId,
        testTitle: testTitle ?? this.testTitle,
        youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      );
}

class ModuleSubtopic {
  final int id;
  final int topicId;
  final String title;
  final int order;
  final List<ContentItem> contentItems;

  ModuleSubtopic({
    required this.id,
    required this.topicId,
    required this.title,
    this.order = 0,
    this.contentItems = const [],
  });

  factory ModuleSubtopic.fromJson(Map<String, dynamic> j) => ModuleSubtopic(
        id: j['id'] ?? 0,
        topicId: j['topic_id'] ?? 0,
        title: j['title'] ?? '',
        order: j['order'] ?? 0,
        contentItems: (j['content_items'] as List?)
                ?.map((c) => ContentItem.fromJson(Map<String, dynamic>.from(c)))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic_id': topicId,
        'title': title,
        'order': order,
        'content_items': contentItems.map((c) => c.toJson()).toList(),
      };

  ModuleSubtopic copyWith({
    int? id,
    int? topicId,
    String? title,
    int? order,
    List<ContentItem>? contentItems,
  }) =>
      ModuleSubtopic(
        id: id ?? this.id,
        topicId: topicId ?? this.topicId,
        title: title ?? this.title,
        order: order ?? this.order,
        contentItems: contentItems ?? List.from(this.contentItems),
      );
}

class ModuleTopic {
  final int id;
  final int moduleId;
  final String title;
  final int order;
  final List<ModuleSubtopic> subtopics;

  ModuleTopic({
    required this.id,
    required this.moduleId,
    required this.title,
    this.order = 0,
    this.subtopics = const [],
  });

  factory ModuleTopic.fromJson(Map<String, dynamic> j) => ModuleTopic(
        id: j['id'] ?? 0,
        moduleId: j['module_id'] ?? 0,
        title: j['title'] ?? '',
        order: j['order'] ?? 0,
        subtopics: (j['subtopics'] as List?)
                ?.map(
                    (s) => ModuleSubtopic.fromJson(Map<String, dynamic>.from(s)))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_id': moduleId,
        'title': title,
        'order': order,
        'subtopics': subtopics.map((s) => s.toJson()).toList(),
      };

  /// Total content items across all subtopics
  int get totalContentItems =>
      subtopics.fold(0, (sum, s) => sum + s.contentItems.length);
}

class TrainingModule {
  final int id;
  final int instituteId;
  final String title;
  final String description;
  final String iconName; // Material icon name
  final String color; // Hex color string
  final bool isPublished;
  final DateTime? createdAt;
  final List<ModuleTopic> topics;

  TrainingModule({
    required this.id,
    required this.instituteId,
    required this.title,
    this.description = '',
    this.iconName = 'school',
    this.color = '#7C4DFF',
    this.isPublished = false,
    this.createdAt,
    this.topics = const [],
  });

  factory TrainingModule.fromJson(Map<String, dynamic> j) => TrainingModule(
        id: j['id'] ?? 0,
        instituteId: j['institute_id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        iconName: j['icon_name'] ?? 'school',
        color: j['color'] ?? '#7C4DFF',
        isPublished: j['is_published'] ?? false,
        createdAt:
            j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
        topics: (j['topics'] as List?)
                ?.map(
                    (t) => ModuleTopic.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'institute_id': instituteId,
        'title': title,
        'description': description,
        'icon_name': iconName,
        'color': color,
        'is_published': isPublished,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'topics': topics.map((t) => t.toJson()).toList(),
      };

  /// Total topics
  int get topicCount => topics.length;

  /// Total subtopics across all topics
  int get subtopicCount =>
      topics.fold(0, (sum, t) => sum + t.subtopics.length);

  /// Total content items across entire module
  int get totalContentItems =>
      topics.fold(0, (sum, t) => sum + t.totalContentItems);

  TrainingModule copyWith({
    int? id,
    int? instituteId,
    String? title,
    String? description,
    String? iconName,
    String? color,
    bool? isPublished,
    DateTime? createdAt,
    List<ModuleTopic>? topics,
  }) =>
      TrainingModule(
        id: id ?? this.id,
        instituteId: instituteId ?? this.instituteId,
        title: title ?? this.title,
        description: description ?? this.description,
        iconName: iconName ?? this.iconName,
        color: color ?? this.color,
        isPublished: isPublished ?? this.isPublished,
        createdAt: createdAt ?? this.createdAt,
        topics: topics ?? List.from(this.topics),
      );
}

/// Tracks a student's progress through a module.
class ModuleProgress {
  final int moduleId;
  final int studentId;
  final Set<int> completedItemIds; // content item IDs that are done
  final int totalItems;

  ModuleProgress({
    required this.moduleId,
    required this.studentId,
    this.completedItemIds = const {},
    this.totalItems = 0,
  });

  double get percentage =>
      totalItems > 0 ? (completedItemIds.length / totalItems) * 100 : 0;

  int get completedCount => completedItemIds.length;

  bool isCompleted(int contentItemId) =>
      completedItemIds.contains(contentItemId);

  factory ModuleProgress.fromJson(Map<String, dynamic> j) => ModuleProgress(
        moduleId: j['module_id'] ?? 0,
        studentId: j['student_id'] ?? 0,
        completedItemIds:
            Set<int>.from(j['completed_item_ids'] ?? []),
        totalItems: j['total_items'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'module_id': moduleId,
        'student_id': studentId,
        'completed_item_ids': completedItemIds.toList(),
        'total_items': totalItems,
      };
}
