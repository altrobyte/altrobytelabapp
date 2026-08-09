// Training Module data models — hierarchical:
// TrainingModule → ModuleTopic → ModuleSubtopic → ContentItem
//
// ContentItem types: notes (HTML), test (links to AltroTest), video
// (YouTube), resource (downloadable file link — this is what makes a
// module double as a "Course": notes + video + downloadable resources).

class ContentItem {
  final int id;
  final int subtopicId;
  final String type; // 'notes' | 'test' | 'video' | 'resource'
  final String title;
  final int order;

  // Type-specific fields
  final String? htmlContent; // for notes
  final int? testId; // for test — links to existing AltroTest
  final String? testTitle; // display name for linked test
  final String? youtubeUrl; // for video
  final String? resourceUrl; // for resource — downloadable file link

  /// The student's plan does not cover this item. The server strips the URL
  /// and body when it sets this, so a locked item genuinely has nothing to
  /// show — the UI must offer an upgrade rather than try to render it.
  final bool locked;

  /// tier_key that would unlock it, for the upgrade prompt.
  final String? upgradeRequired;

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
    this.resourceUrl,
    this.locked = false,
    this.upgradeRequired,
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
        resourceUrl: j['resource_url'],
        locked: j['locked'] == true,
        upgradeRequired: j['upgrade_required'],
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
        if (resourceUrl != null) 'resource_url': resourceUrl,
        if (locked) 'locked': true,
        if (upgradeRequired != null) 'upgrade_required': upgradeRequired,
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
    String? resourceUrl,
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
        resourceUrl: resourceUrl ?? this.resourceUrl,
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

/// The workshop this course is bundled with, if any — reverse of
/// LiveSession's linked_module_id, used to cross-link the two pages.
class LinkedSessionInfo {
  final int id;
  final String title;
  final DateTime? sessionDate;
  LinkedSessionInfo({required this.id, required this.title, this.sessionDate});

  factory LinkedSessionInfo.fromJson(Map<String, dynamic> j) => LinkedSessionInfo(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        sessionDate: j['session_date'] != null ? DateTime.tryParse(j['session_date']) : null,
      );
}

class TrainingModule {
  final int id;
  final int instituteId;
  final String title;
  final String description;
  final String iconName; // Material icon name
  final String color; // Hex color string
  final bool isPublished;
  final double price;
  final double taxPercent;
  final double? originalPrice;
  final bool locked;
  final bool loginRequired;
  final LinkedSessionInfo? linkedSession;
  final DateTime? createdAt;
  final List<ModuleTopic> topics;
  final int? topicCountFromApi;
  final int? totalContentItemsFromApi;

  TrainingModule({
    required this.id,
    required this.instituteId,
    required this.title,
    this.description = '',
    this.iconName = 'school',
    this.color = '#7C4DFF',
    this.isPublished = false,
    this.price = 0,
    this.taxPercent = 0,
    this.originalPrice,
    this.locked = false,
    this.loginRequired = false,
    this.linkedSession,
    this.createdAt,
    this.topics = const [],
    this.topicCountFromApi,
    this.totalContentItemsFromApi,
  });

  factory TrainingModule.fromJson(Map<String, dynamic> j) => TrainingModule(
        id: j['id'] ?? 0,
        instituteId: j['institute_id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        iconName: j['icon_name'] ?? 'school',
        color: j['color'] ?? '#7C4DFF',
        isPublished: j['is_published'] ?? false,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        taxPercent: (j['tax_percent'] as num?)?.toDouble() ?? 0,
        originalPrice: (j['original_price'] as num?)?.toDouble(),
        locked: j['locked'] ?? false,
        loginRequired: j['login_required'] ?? false,
        linkedSession: j['linked_session'] != null
            ? LinkedSessionInfo.fromJson(Map<String, dynamic>.from(j['linked_session']))
            : null,
        createdAt:
            j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
        topics: (j['topics'] as List?)
                ?.map(
                    (t) => ModuleTopic.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            [],
        topicCountFromApi: j['topic_count'] as int?,
        totalContentItemsFromApi: j['total_content_items'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'institute_id': instituteId,
        'title': title,
        'description': description,
        'icon_name': iconName,
        'color': color,
        'is_published': isPublished,
        'price': price,
        'tax_percent': taxPercent,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'topics': topics.map((t) => t.toJson()).toList(),
      };

  /// Total topics. Prefers the backend-computed count (present on both the
  /// list and detail endpoints) since the list view never populates
  /// `topics` itself — falling back to topics.length would always read 0
  /// there, which is exactly the "0 topics" / "X/0 completed" bug this
  /// was built to fix.
  int get topicCount => topicCountFromApi ?? topics.length;

  /// Total subtopics across all topics
  int get subtopicCount =>
      topics.fold(0, (sum, t) => sum + t.subtopics.length);

  /// Total content items across entire module — see topicCount above for
  /// why the API-provided count takes priority.
  int get totalContentItems =>
      totalContentItemsFromApi ?? topics.fold(0, (sum, t) => sum + t.totalContentItems);

  TrainingModule copyWith({
    int? id,
    int? instituteId,
    String? title,
    String? description,
    String? iconName,
    String? color,
    bool? isPublished,
    double? price,
    double? taxPercent,
    double? originalPrice,
    bool clearOriginalPrice = false,
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
        price: price ?? this.price,
        taxPercent: taxPercent ?? this.taxPercent,
        originalPrice: clearOriginalPrice ? null : (originalPrice ?? this.originalPrice),
        loginRequired: loginRequired,
        linkedSession: linkedSession,
        createdAt: createdAt ?? this.createdAt,
        topics: topics ?? List.from(this.topics),
        topicCountFromApi: topicCountFromApi,
        totalContentItemsFromApi: totalContentItemsFromApi,
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
