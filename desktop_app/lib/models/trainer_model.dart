// What the AI Trainer test console shows. Parsed from the backend's
// trainer_api.py; test/trainer_model_test.dart pins the shape against real output.

class TrainerScenario {
  final String name;
  final String label;
  final String description;
  final String opening;
  const TrainerScenario({required this.name, required this.label, this.description = '', this.opening = ''});

  factory TrainerScenario.fromJson(Map<String, dynamic> j) => TrainerScenario(
        name: j['name'] ?? '',
        label: j['label'] ?? j['name'] ?? '',
        description: j['description'] ?? '',
        opening: j['opening'] ?? '',
      );
}

class TrainerMilestone {
  final String id;
  final String title;
  final String stage;
  final bool physical;
  final String status; // done | blocked | pending
  final String? kind; // verified | learner_confirmed
  final String evidence;
  final List<String> waitingFor;
  final int failedChecks;
  const TrainerMilestone({
    required this.id,
    required this.title,
    required this.stage,
    this.physical = false,
    this.status = 'pending',
    this.kind,
    this.evidence = '',
    this.waitingFor = const [],
    this.failedChecks = 0,
  });

  factory TrainerMilestone.fromJson(Map<String, dynamic> j) => TrainerMilestone(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        stage: j['stage'] ?? '',
        physical: j['physical'] == true,
        status: j['status'] ?? 'pending',
        kind: j['kind'],
        evidence: j['evidence'] ?? '',
        waitingFor: [for (final w in (j['waiting_for'] as List? ?? [])) '$w'],
        failedChecks: (j['failed_checks'] as num?)?.toInt() ?? 0,
      );

  bool get done => status == 'done';
}

class TrainerActivity {
  final double t;
  final String kind;
  final String label;
  final bool ok;
  final String detail;
  const TrainerActivity({required this.t, required this.kind, required this.label, this.ok = true, this.detail = ''});

  factory TrainerActivity.fromJson(Map<String, dynamic> j) => TrainerActivity(
        t: (j['t'] as num?)?.toDouble() ?? 0,
        kind: j['kind'] ?? '',
        label: j['label'] ?? '',
        ok: j['ok'] != false,
        detail: j['detail'] ?? '',
      );
}

class TrainerSim {
  final Map<String, String> files;
  final bool boardConnected;
  final bool driverOk;
  final String wiring;
  final bool flashed;
  final bool touching;
  final List<String> serial;
  const TrainerSim({
    this.files = const {},
    this.boardConnected = true,
    this.driverOk = true,
    this.wiring = 'ok',
    this.flashed = false,
    this.touching = false,
    this.serial = const [],
  });

  factory TrainerSim.fromJson(Map<String, dynamic> j) => TrainerSim(
        files: {for (final e in (j['files'] as Map? ?? {}).entries) '${e.key}': '${e.value}'},
        boardConnected: j['board_connected'] != false,
        driverOk: j['driver_ok'] != false,
        wiring: j['wiring'] ?? 'ok',
        flashed: j['flashed'] == true,
        touching: j['touching'] == true,
        serial: [for (final l in (j['serial'] as List? ?? [])) '$l'],
      );
}

class TrainerState {
  final String mission;
  final String scenario;
  final List<Map<String, String>> stages;
  final List<TrainerMilestone> progress;
  final bool finished;
  final String level;
  final Map<String, int> hints;
  final List<TrainerActivity> activity;
  final TrainerSim sim;
  const TrainerState({
    required this.mission,
    required this.scenario,
    this.stages = const [],
    this.progress = const [],
    this.finished = false,
    this.level = 'unknown',
    this.hints = const {},
    this.activity = const [],
    this.sim = const TrainerSim(),
  });

  factory TrainerState.fromJson(Map<String, dynamic> j) => TrainerState(
        mission: j['mission'] ?? '',
        scenario: j['scenario'] ?? '',
        stages: [
          for (final s in (j['stages'] as List? ?? [])) {'id': '${s['id']}', 'title': '${s['title']}'}
        ],
        progress: [
          for (final p in (j['progress'] as List? ?? [])) TrainerMilestone.fromJson(Map<String, dynamic>.from(p))
        ],
        finished: j['finished'] == true,
        level: j['level'] ?? 'unknown',
        hints: {for (final e in (j['hints'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toInt()},
        activity: [
          for (final a in (j['activity'] as List? ?? [])) TrainerActivity.fromJson(Map<String, dynamic>.from(a))
        ],
        sim: TrainerSim.fromJson(Map<String, dynamic>.from(j['sim'] as Map? ?? {})),
      );

  int get doneCount => progress.where((m) => m.done).length;
}

/// One trainer reply: what it said, interactives to show, and the new state.
class TrainerTurn {
  final String? sessionId;
  final List<String> messages;
  final List<Map<String, dynamic>> ui;
  final bool waiting;
  final bool finished;
  final TrainerState state;
  const TrainerTurn({
    this.sessionId,
    required this.messages,
    this.ui = const [],
    this.waiting = false,
    this.finished = false,
    required this.state,
  });

  factory TrainerTurn.fromJson(Map<String, dynamic> j) => TrainerTurn(
        sessionId: j['id'] as String?,
        messages: [for (final m in (j['messages'] as List? ?? [])) '$m'],
        ui: [for (final u in (j['ui'] as List? ?? [])) Map<String, dynamic>.from(u)],
        waiting: j['waiting'] == true,
        finished: j['finished'] == true,
        state: TrainerState.fromJson(Map<String, dynamic>.from(j['state'])),
      );
}
