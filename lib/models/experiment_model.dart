// Experimental Training Platform data model.
//
// tool_type: 'mqtt' | 'websocket' | 'ble' | 'http'
// verification_type: 'manual' | 'auto'

class Experiment {
  final int id;
  final int? instituteId;
  final String title;
  final String objective;
  final String guideHtml;
  final String toolType;
  final Map<String, dynamic> toolConfig;
  final String verificationType;
  final Map<String, dynamic> autoVerifyRule;
  final String iconName;
  final String color;
  final bool isPublished;
  final int order;

  Experiment({
    required this.id,
    this.instituteId,
    required this.title,
    this.objective = '',
    this.guideHtml = '',
    this.toolType = 'mqtt',
    this.toolConfig = const {},
    this.verificationType = 'manual',
    this.autoVerifyRule = const {},
    this.iconName = 'science',
    this.color = '#00BFA5',
    this.isPublished = false,
    this.order = 0,
  });

  factory Experiment.fromJson(Map<String, dynamic> j) => Experiment(
        id: j['id'] ?? 0,
        instituteId: j['institute_id'],
        title: j['title'] ?? '',
        objective: j['objective'] ?? '',
        guideHtml: j['guide_html'] ?? '',
        toolType: j['tool_type'] ?? 'mqtt',
        toolConfig: Map<String, dynamic>.from(j['tool_config'] ?? {}),
        verificationType: j['verification_type'] ?? 'manual',
        autoVerifyRule: Map<String, dynamic>.from(j['auto_verify_rule'] ?? {}),
        iconName: j['icon_name'] ?? 'science',
        color: j['color'] ?? '#00BFA5',
        isPublished: j['is_published'] ?? false,
        order: j['order_index'] ?? 0,
      );
}

class ExperimentAttempt {
  final int id;
  final Map<String, dynamic> resultData;
  final bool verified;
  final String notes;
  final DateTime? createdAt;

  ExperimentAttempt({
    required this.id,
    this.resultData = const {},
    this.verified = false,
    this.notes = '',
    this.createdAt,
  });

  factory ExperimentAttempt.fromJson(Map<String, dynamic> j) => ExperimentAttempt(
        id: j['id'] ?? 0,
        resultData: Map<String, dynamic>.from(j['result_data'] ?? {}),
        verified: j['verified'] ?? false,
        notes: j['notes'] ?? '',
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      );
}
