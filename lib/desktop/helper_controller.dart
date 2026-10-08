// What the desktop screen shows and does, on top of the helper. The screen draws; this holds the conversation, the
// permissions, the project folder, the serial monitor and the audit trail, all of which live in the helper, so the VS Code
// extension (the same helper) sees exactly the same settings and the same board.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/trainer_model.dart';
import 'helper_client.dart';

const allConnectors = ['system', 'workspace', 'toolchain', 'serial', 'mqtt'];

class ChatBubble {
  final String role; // trainer | learner | system | ui
  final String text;
  final String? interactive; // pin_map | picture | quiz | replies: a card the learner can use right in the chat
  final Map<String, dynamic>? props;
  const ChatBubble(this.role, this.text, {this.interactive, this.props});
}

class Approval {
  final String id;
  final String title;
  final String detail;
  const Approval(this.id, this.title, this.detail);
}

typedef OpenInEditor = Future<void> Function(String path, int line);
typedef PictureOpener = Future<bool> Function(Map<String, dynamic> props);
typedef AskLearner = Future<bool> Function(Approval approval);

/// What to tell the learner for a failure event from the helper.
String describeError(String? kind, String? message) {
  switch (kind) {
    case 'offline':
      return 'No internet right now, so the trainer cannot chat. Your board and files are still yours: nothing was lost.';
    case 'auth':
      return 'Please sign in again.';
    case 'forbidden':
      return 'This account is not allowed to use the trainer yet.';
    case 'quota':
      return (message ?? '').isNotEmpty ? message! : 'The trainer is at its daily limit. Try again later.';
    case 'busy':
      return 'The trainer is still answering. One moment.';
    default:
      return (message ?? '').isNotEmpty ? message! : 'Something went wrong talking to the trainer.';
  }
}

/// A readable version of the audit log: what was asked of this computer, and what was sent out.
List<String> formatAudit(List<dynamic> entries) {
  final lines = <String>[];
  for (final raw in entries) {
    if (raw is! Map) continue;
    final e = Map<String, dynamic>.from(raw);
    final t = '${e['t'] ?? ''}';
    final time = t.length > 11 ? t.substring(11, t.length.clamp(11, 19)) : t;
    final kind = '${e['kind']}';
    if (kind == 'op') {
      final args = (e['args'] is Map && (e['args'] as Map).isNotEmpty) ? ' ${e['args']}' : '';
      final why = (e['reason'] ?? '').toString().isNotEmpty ? '  (${e['reason']})' : '';
      lines.add('$time  ASKED  ${e['op']}$args  ->  ${'${e['outcome']}'.toUpperCase()}$why');
    } else if (kind == 'cloud') {
      final masked = (e['masked'] is num && (e['masked'] as num) > 0) ? ', ${e['masked']} secret(s) hidden' : '';
      lines.add('$time  SENT   ${e['what']}  (${e['bytes'] ?? '?'} bytes$masked)');
    } else if (kind == 'verify') {
      lines.add('$time  CHECK  ${e['milestone']}  ->  ${e['passed'] == true ? 'PASSED' : 'not yet'}');
    } else if (kind == 'grants') {
      final c = (e['connectors'] as List? ?? const []).join(', ');
      lines.add('$time  ALLOWED  ${c.isEmpty ? 'nothing' : c}');
    } else {
      lines.add('$time  $kind');
    }
  }
  return lines;
}

/// The message a quiz card sends. The trainer's instructions name this exact shape, and the engine reads the two values.
String quizAnswerText(String milestone, int choice) => '[quiz answer] milestone=$milestone choice=$choice';

/// The step the learner is on now: the first one not done and not blocked (what the banner above the chat shows).
String? currentStepTitle(TrainerState? st) {
  if (st == null) return null;
  for (final m in st.progress) {
    if (!m.done && m.status != 'blocked') return m.title;
  }
  return null;
}

class HelperController extends ChangeNotifier {
  final HelperClient client;
  final OpenInEditor? openInEditor;
  final PictureOpener? openPicture;
  AskLearner? askLearner;
  final String? Function()? starterFolder;
  final bool Function(String path)? folderExists;
  final Duration pollEvery;

  HelperController(this.client,
      {this.openInEditor, this.openPicture, this.askLearner, this.starterFolder, this.folderExists, this.pollEvery = const Duration(seconds: 2)});

  final List<ChatBubble> chat = [];
  TrainerState? state;
  String activity = '';
  bool busy = false;
  bool started = false;
  bool ready = false;
  bool lost = false; // the helper went away (restarted from another app, or ended)
  String? courseId; // the built-in course being taken, if any
  Map<String, dynamic>? setupReport; // what the helper found on this computer (null until checked)
  bool settingUp = false; // a check or a download is in progress
  final Map<String, Map<String, dynamic>> setupProgress = {}; // item id -> {line, percent}
  Map<String, dynamic> settings = {};

  bool monitorRunning = false;
  String monitorPort = '';
  int monitorBaud = 0;
  String monitorStatus = '';
  List<String> monitorLines = [];
  List<String> auditLines = [];

  final Completer<void> _streamLive = Completer<void>();
  StreamSubscription<HelperEvent>? _events;
  Timer? _poll;
  bool _disposed = false;

  Set<String> get grants => {for (final g in (settings['grants'] as List? ?? const [])) '$g'};
  String? get projectDir => (settings['project_dir'] as String?)?.isNotEmpty == true ? settings['project_dir'] as String : null;
  Map<String, dynamic> get mqtt => Map<String, dynamic>.from((settings['mqtt'] as Map?) ?? const {});

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _add(String role, String text, {String? interactive, Map<String, dynamic>? props}) =>
      chat.add(ChatBubble(role, text, interactive: interactive, props: props));

  // ── life ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    settings = await client.get('/settings');
    // No folder yet, or one that has since been deleted: start the learner in a ready one instead of an error later.
    final missing = projectDir == null || (folderExists != null && !folderExists!(projectDir!));
    if (missing && starterFolder != null) {
      final f = starterFolder!();
      if (f != null) settings = await client.put('/settings', {'project_dir': f});
    }
    _events = client.events().listen(_onEvent, onError: (_) => _gone(), onDone: _gone);
    // Wait until the helper says the stream is live, so nothing it says right after we start is missed.
    await _streamLive.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    _poll = Timer.periodic(pollEvery, (_) => _tick());
    ready = true;
    _notify();
  }

  void _gone() {
    if (!_streamLive.isCompleted) _streamLive.complete(); // never leave init() waiting for a stream that ended
    if (_disposed || lost) return;
    lost = true;
    busy = false;
    activity = '';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _events?.cancel();
    client.close();
    super.dispose();
  }

  /// Gives the helper the learner's Altrobyte sign-in, which it uses to talk to the cloud trainer.
  Future<void> signIn(String token) async {
    await client.post('/session/auth', {'token': token});
  }

  // ── what the helper tells us ───────────────────────────────────────────────

  void _onEvent(HelperEvent e) {
    switch (e.kind) {
      case 'ready':
        if (!_streamLive.isCompleted) _streamLive.complete();
        break;
      case 'message':
        _add('trainer', '${e.data['text'] ?? ''}');
        break;
      case 'ui':
        _onUi(e.data);
        break;
      case 'state':
        try {
          state = TrainerState.fromJson(e.data);
        } catch (_) {}
        break;
      case 'activity':
        activity = '${e.data['text'] ?? ''}';
        break;
      case 'turn_done':
        busy = false;
        activity = '';
        if (e.data['finished'] == true) _add('system', 'Mission complete: every milestone is proven.');
        unawaited(refreshSide());
        break;
      case 'error':
        busy = false;
        activity = '';
        _add('system', describeError(e.data['kind'] as String?, e.data['message'] as String?));
        if (e.data['kind'] == 'gone') started = false;
        break;
      case 'approval_request':
        unawaited(_approve(Approval('${e.data['id']}', '${e.data['title']}', '${e.data['detail']}')));
        break;
      case 'open_file':
        openInEditor?.call('${e.data['path']}', (e.data['line'] as num?)?.toInt() ?? 1);
        break;
      case 'setup':
        _onSetup(e.data);
        break;
    }
    _notify();
  }

  void _onUi(Map<String, dynamic> ui) {
    final type = '${ui['type']}';
    final props = Map<String, dynamic>.from((ui['props'] as Map?) ?? const {});
    if (type == 'pin_map') {
      _add('ui', '', interactive: 'pin_map');
    } else if (type == 'replies') {
      _add('ui', '', interactive: 'replies', props: props);
    } else if (type == 'quiz') {
      _add('ui', '', interactive: 'quiz', props: props);
    } else if (type == 'wiring_diagram' || type == 'visual') {
      _add('ui', '', interactive: 'picture', props: props);
      if (type == 'wiring_diagram') openPicture?.call(props); // the learner asked to see it: show it now
    }
  }

  Future<void> _approve(Approval a) async {
    final ok = await (askLearner?.call(a) ?? Future.value(false));
    try {
      await client.post('/approvals/${a.id}', {'allow': ok});
    } catch (_) {
      // the question had already timed out; the answer was "no"
    }
  }

  // ── the conversation ───────────────────────────────────────────────────────

  Future<void> start({int? labId, String? course}) async {
    if (busy) return;
    busy = true;
    started = true;
    courseId = course;
    chat.clear();
    state = null;
    _notify();
    try {
      await client.post('/session/start', course != null ? {'course': course} : (labId == null ? null : {'lab_id': labId}));
    } on HelperError catch (e) {
      busy = false;
      started = false;
      _add('system', e.status == 401 ? 'Please sign in first.' : e.message);
      _notify();
    }
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || busy || !started) return;
    _add('learner', t);
    busy = true;
    _notify();
    try {
      await client.post('/session/chat', {'text': t});
    } on HelperError catch (e) {
      busy = false;
      _add('system', e.message);
      _notify();
    }
  }

  /// A tap on a quiz card. The learner sees their own choice in the chat; the trainer gets the tagged answer and the engine,
  /// not the model, decides if it is right.
  Future<void> answerQuiz(String milestone, int choice, String optionText) async {
    if (busy || !started) return;
    _add('learner', optionText);
    busy = true;
    _notify();
    try {
      await client.post('/session/chat', {'text': quizAnswerText(milestone, choice)});
    } on HelperError catch (e) {
      busy = false;
      _add('system', e.message);
      _notify();
    }
  }

  // ── getting this computer ready ────────────────────────────────────────────

  Future<void> checkSetup() async {
    if (settingUp && setupProgress.isNotEmpty) return; // a download is running: its own events keep the screen current
    settingUp = true;
    _notify();
    try {
      setupReport = await client.get('/setup/check');
    } on HelperError catch (e) {
      setupReport = {'items': [], 'ready': false, 'error': e.message};
    } finally {
      settingUp = false;
      _notify();
    }
  }

  Future<String?> installSetup(String item) async {
    try {
      await client.post('/setup/install', {'item': item});
      setupProgress[item] = {'line': 'Starting…', 'percent': null};
      settingUp = true;
      _notify();
      return null;
    } on HelperError catch (e) {
      return e.message;
    }
  }

  void _onSetup(Map<String, dynamic> d) {
    final item = '${d['item']}';
    if (d['state'] == 'working') {
      setupProgress[item] = {'line': '${d['line'] ?? ''}', 'percent': d['percent']};
    } else {
      setupProgress.remove(item);
      settingUp = setupProgress.isNotEmpty;
      unawaited(checkSetup()); // a download ended: look again, so the list shows what is true now
    }
  }

  Future<void> newSession() async {
    try {
      await client.post('/session/end');
      await client.post('/monitor/stop');
    } catch (_) {}
    started = false;
    busy = false;
    courseId = null;
    chat.clear();
    state = null;
    _notify();
  }

  // ── what the trainer may see ───────────────────────────────────────────────

  Future<void> setGrant(String connector, bool on) async {
    final next = grants..remove(connector);
    if (on) next.add(connector);
    settings = await client.put('/settings', {'grants': next.toList()..sort()});
    _notify();
  }

  Future<void> setProjectDir(String dir) async {
    settings = await client.put('/settings', {'project_dir': dir});
    _notify();
  }

  /// Saves the MQTT broker. The password is only sent when one was typed: the helper never gives it back.
  Future<void> saveMqtt({required String host, required int port, required bool tls, required String username, String password = ''}) async {
    settings = await client.put('/settings', {
      'mqtt': {'host': host, 'port': port, 'tls': tls, 'username': username, if (password.isNotEmpty) 'password': password},
    });
    _notify();
  }

  // ── the board ──────────────────────────────────────────────────────────────

  Future<void> startMonitor() async {
    try {
      final r = await client.post('/monitor/start');
      monitorStatus = '${r['status'] ?? ''}';
    } on HelperError catch (e) {
      monitorStatus = e.message;
    }
    await refreshSide();
  }

  Future<void> stopMonitor() async {
    try {
      await client.post('/monitor/stop');
    } catch (_) {}
    await refreshSide();
  }

  int _idleTicks = 0;

  /// The side panels refresh often while something is happening, and rarely while the app just sits open: a window left
  /// open all day should cost the computer (and the helper) next to nothing.
  void _tick() {
    if (started || monitorRunning || ++_idleTicks % 5 == 0) {
      unawaited(refreshSide());
    }
  }

  /// The serial monitor and the audit trail, read from the helper.
  Future<void> refreshSide() async {
    if (_disposed || lost) return;
    try {
      if (grants.contains('serial') || monitorRunning) {
        final m = await client.get('/monitor?n=14');
        monitorRunning = m['running'] == true;
        monitorPort = '${m['port'] ?? ''}';
        monitorBaud = (m['baud'] as num?)?.toInt() ?? 0;
        monitorLines = [for (final l in (m['lines'] as List? ?? const [])) '$l'];
      }
      if (started) {
        final a = await client.get('/audit?limit=60');
        auditLines = formatAudit(a['entries'] as List? ?? const []).reversed.toList();
      }
    } on HelperError {
      // a hiccup reading the side panels is not worth interrupting the lesson for
    } catch (_) {}
    _notify();
  }
}
