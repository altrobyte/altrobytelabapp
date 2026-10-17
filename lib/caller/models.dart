// What the caller app holds about a lead and a call. The CRM (crm_calls.py) is the only store: these are its answers,
// kept on the phone so the queue still opens with no signal.

const outcomes = {
  'connected': 'Connected',
  'no_answer': 'No answer',
  'busy': 'Busy',
  'switched_off': 'Switched off',
  'wrong_number': 'Wrong number',
  'call_back': 'Call back later',
};

const interests = {'hot': 'Hot', 'warm': 'Warm', 'cold': 'Cold', 'not_interested': 'Not interested'};

const stages = {
  'new': 'New',
  'contacted': 'Contacted',
  'interested': 'Interested',
  'demo_booked': 'Demo booked',
  'demo_done': 'Demo done',
  'token_paid': 'Token paid',
  'enrolled': 'Enrolled',
  'lost': 'Lost',
};

const lostReasons = ['Price too high', 'Joined elsewhere', 'Not the right time', 'Not reachable', 'Wants something else'];

const unanswered = {'no_answer', 'busy', 'switched_off'};

DateTime? _time(dynamic v) => v == null || '$v'.isEmpty ? null : DateTime.tryParse('$v')?.toUtc();

class Heat {
  final String temperature;
  final int score;
  final int pct;
  final List<String> reasons;

  const Heat({this.temperature = 'cold', this.score = 0, this.pct = 0, this.reasons = const []});

  factory Heat.fromJson(Map<String, dynamic>? j) => Heat(
        temperature: '${j?['temperature'] ?? 'cold'}',
        score: (j?['score'] as num?)?.toInt() ?? 0,
        pct: (j?['pct'] as num?)?.toInt() ?? 0,
        reasons: ((j?['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  Map<String, dynamic> toJson() => {'temperature': temperature, 'score': score, 'pct': pct, 'reasons': reasons};
}

class Lead {
  final String phone;
  final String name;
  final String stage;
  final String owner;
  final List<String> labels;
  final Heat heat;
  final String lastNote;
  final DateTime? nextFollowupAt;
  final DateTime? lastCalledAt;
  final String lastCalledBy;
  final bool converted;
  final String creditedTo;

  const Lead({
    required this.phone,
    this.name = '',
    this.stage = 'new',
    this.owner = '',
    this.labels = const [],
    this.heat = const Heat(),
    this.lastNote = '',
    this.nextFollowupAt,
    this.lastCalledAt,
    this.lastCalledBy = '',
    this.converted = false,
    this.creditedTo = '',
  });

  String get displayName => name.trim().isEmpty ? phone : name.trim();

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        phone: '${j['phone'] ?? ''}',
        name: '${j['name'] ?? ''}',
        stage: '${j['stage'] ?? 'new'}',
        owner: '${j['owner'] ?? ''}',
        labels: ((j['labels'] as List?) ?? const []).map((e) => '$e').toList(),
        heat: Heat.fromJson((j['heat'] as Map?)?.cast<String, dynamic>()),
        lastNote: '${j['last_note'] ?? ''}',
        nextFollowupAt: _time(j['next_followup_at']),
        lastCalledAt: _time(j['last_called_at']),
        lastCalledBy: '${j['last_called_by'] ?? ''}',
        converted: j['converted'] == true,
        creditedTo: '${j['credited_to'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'stage': stage,
        'owner': owner,
        'labels': labels,
        'heat': heat.toJson(),
        'last_note': lastNote,
        'next_followup_at': nextFollowupAt?.toIso8601String(),
        'last_called_at': lastCalledAt?.toIso8601String(),
        'last_called_by': lastCalledBy,
        'converted': converted,
        'credited_to': creditedTo,
      };

  Lead copyWith({
    String? name,
    String? stage,
    List<String>? labels,
    Heat? heat,
    String? lastNote,
    DateTime? nextFollowupAt,
    bool clearFollowup = false,
    DateTime? lastCalledAt,
    String? lastCalledBy,
    String? owner,
  }) =>
      Lead(
        phone: phone,
        name: name ?? this.name,
        stage: stage ?? this.stage,
        owner: owner ?? this.owner,
        labels: labels ?? this.labels,
        heat: heat ?? this.heat,
        lastNote: lastNote ?? this.lastNote,
        nextFollowupAt: clearFollowup ? null : (nextFollowupAt ?? this.nextFollowupAt),
        lastCalledAt: lastCalledAt ?? this.lastCalledAt,
        lastCalledBy: lastCalledBy ?? this.lastCalledBy,
        converted: converted,
        creditedTo: creditedTo,
      );
}

/// One call as the caller logged it. [clientId] is made here, before it is ever sent, so the server knows a retry of
/// the same log when a flaky connection sends it twice.
class CallLog {
  final String clientId;
  final String phone;
  final DateTime startedAt;
  final int durationS;
  final String direction;
  final String outcome;
  final String interest;
  final String stage;
  final String lostReason;
  final List<String>? labels;
  final DateTime? nextFollowupAt;
  final String note;
  final String name;

  const CallLog({
    required this.clientId,
    required this.phone,
    required this.startedAt,
    required this.outcome,
    this.durationS = 0,
    this.direction = 'out',
    this.interest = '',
    this.stage = '',
    this.lostReason = '',
    this.labels,
    this.nextFollowupAt,
    this.note = '',
    this.name = '',
  });

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'phone': phone,
        'started_at': startedAt.toUtc().toIso8601String(),
        'duration_s': durationS,
        'direction': direction,
        'outcome': outcome,
        'interest': interest,
        'stage': stage,
        'lost_reason': lostReason,
        if (labels != null) 'labels': labels,
        'next_followup_at': nextFollowupAt?.toUtc().toIso8601String(),
        'note': note,
        'name': name,
      };

  factory CallLog.fromJson(Map<String, dynamic> j) => CallLog(
        clientId: '${j['client_id']}',
        phone: '${j['phone']}',
        startedAt: _time(j['started_at']) ?? DateTime.now().toUtc(),
        durationS: (j['duration_s'] as num?)?.toInt() ?? 0,
        direction: '${j['direction'] ?? 'out'}',
        outcome: '${j['outcome']}',
        interest: '${j['interest'] ?? ''}',
        stage: '${j['stage'] ?? ''}',
        lostReason: '${j['lost_reason'] ?? ''}',
        labels: (j['labels'] as List?)?.map((e) => '$e').toList(),
        nextFollowupAt: _time(j['next_followup_at']),
        note: '${j['note'] ?? ''}',
        name: '${j['name'] ?? ''}',
      );

  /// The lead as it will be once the server has this log: shown at once, before (or without) a connection. The server's
  /// answer replaces it, with the score worked out properly, when the log is sent.
  Lead applyTo(Lead l, {String me = ''}) {
    final toStage = stage.isNotEmpty ? stage : (outcome == 'connected' && l.stage == 'new' ? 'contacted' : l.stage);
    final text = stage == 'lost' ? 'Lost: $lostReason${note.isEmpty ? '' : '. $note'}' : note;
    final out = outcome == 'wrong_number' || toStage == 'lost';
    return l.copyWith(
      name: l.name.isEmpty && name.isNotEmpty ? name : null,
      stage: toStage,
      labels: labels,
      lastNote: text.isEmpty ? null : text,
      nextFollowupAt: nextFollowupAt?.toUtc(),
      clearFollowup: nextFollowupAt == null,
      lastCalledAt: startedAt.toUtc(),
      lastCalledBy: me.isEmpty ? null : me,
      heat: out ? Heat(temperature: 'out', score: l.heat.score, reasons: l.heat.reasons) : null,
    );
  }
}

/// The id a call from the phone's call log has everywhere (crm_calls.device_call_id): the automatic sync and the
/// caller's own log of the same call are one row in the CRM, not two.
String deviceCallId(String phone, DateTime startedAt) => 'dev-${last10(phone)}-${startedAt.millisecondsSinceEpoch}';

/// Ten digits, the way the CRM keys a lead.
String last10(String phone) {
  final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return d.length >= 10 ? d.substring(d.length - 10) : d;
}
