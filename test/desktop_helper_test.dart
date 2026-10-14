// The desktop app is a window onto the shared helper. Everything here runs without a board: a stand-in helper answers over
// the same HTTP and event stream, and one test starts the real helper that ships with the app.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:altrobytelab/desktop/app_version.dart';
import 'package:altrobytelab/desktop/helper_client.dart';
import 'package:altrobytelab/desktop/helper_controller.dart';
import 'package:altrobytelab/desktop/modules_panel.dart' show modulesProblem;
import 'package:altrobytelab/models/trainer_model.dart';
import 'package:altrobytelab/desktop/local_tools.dart';
import 'package:altrobytelab/desktop/sse.dart';
import 'package:altrobytelab/desktop/visual_page.dart';

// ── a stand-in helper ────────────────────────────────────────────────────────

class FakeHelper {
  final List<String> calls = []; // "METHOD /path"
  final List<Map<String, dynamic>> bodies = [];
  final sse = StreamController<List<int>>();
  Map<String, dynamic> settings = {
    'grants': ['system', 'workspace'],
    'project_dir': null,
    'mqtt': {'host': '', 'port': 8883, 'tls': true, 'username': '', 'password': ''},
  };
  Map<String, dynamic> monitor = {'running': false, 'port': '', 'baud': 0, 'lines': []};
  List<dynamic> audit = [];
  Map<String, dynamic> setupReport = {'items': [], 'ready': false, 'busy': false};
  int installStatus = 202;
  int startStatus = 202;
  String startDetail = '';

  late final http.Client client = MockClient.streaming((req, body) async {
    final path = req.url.path;
    if (req.method == 'GET' && path == '/events') {
      emit('ready', {}); // the helper greets every listener first
      return http.StreamedResponse(sse.stream, 200, headers: {'content-type': 'text/event-stream'});
    }
    final text = await utf8.decodeStream(body);
    final json = text.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(text) as Map);
    calls.add('${req.method} $path');
    bodies.add(json);
    if (req.headers['Authorization'] != 'Bearer tok') return _reply({'detail': 'no'}, 401);
    Map<String, dynamic> out = {'ok': true};
    var status = 200;
    if (path == '/settings') {
      if (req.method == 'PUT') settings = {...settings, ...json, if (json['mqtt'] != null) 'mqtt': {...(settings['mqtt'] as Map), ...(json['mqtt'] as Map)}};
      out = settings;
    } else if (path == '/monitor') {
      out = monitor;
    } else if (path == '/audit') {
      out = {'entries': audit};
    } else if (path == '/monitor/start') {
      out = {'status': 'Monitoring COM6 at 115200 baud'};
    } else if (path == '/setup/check') {
      out = setupReport;
    } else if (path == '/setup/install') {
      status = installStatus;
      if (installStatus != 202) out = {'detail': 'Another download is still running. Wait for it to finish.'};
    } else if (path == '/session/start') {
      status = startStatus;
      if (startDetail.isNotEmpty) out = {'detail': startDetail};
    }
    return _reply(out, status);
  });

  http.StreamedResponse _reply(Map<String, dynamic> j, int status) =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(j))), status, headers: {'content-type': 'application/json'});

  void emit(String kind, Map<String, dynamic> data) => sse.add(utf8.encode('event: $kind\ndata: ${jsonEncode(data)}\n\n'));

  HelperController controller({AskLearner? ask, OpenInEditor? open, PictureOpener? picture, String? Function()? starter}) => HelperController(
        HelperClient(const HelperInfo(port: 1, token: 'tok'), client: client),
        askLearner: ask,
        openInEditor: open,
        openPicture: picture,
        starterFolder: starter,
        pollEvery: const Duration(hours: 1),
      );
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  group('server-sent events', () {
    test('events split across chunks, CRLF, comments and multi-line data', () {
      final p = SseParser();
      expect(p.push('event: message\r\ndata: {"a":'), isEmpty);
      final out = p.push('1}\r\n\r\n: keepalive\n\nevent: x\ndata: l1\ndata: l2\n\n');
      expect(out.map((e) => '${e.event}|${e.data}'), ['message|{"a":1}', 'x|l1\nl2']);
    });

    test('an event with no data still arrives, and junk fields are ignored', () {
      final out = SseParser().push('event: ready\ndata: {}\n\nfoo: bar\nretry: 5\n\n');
      expect(out.map((e) => e.event), ['ready']);
    });
  });

  group('finding and joining the helper', () {
    late Directory home;
    setUp(() => home = Directory.systemTemp.createTempSync('helper_home_'));

    test('a missing, garbled or stale record is not a running helper', () async {
      expect(await findRunningHelper(home.path), isNull);
      File('${home.path}/helper.json').writeAsStringSync('not json');
      expect(await findRunningHelper(home.path), isNull);
      File('${home.path}/helper.json').writeAsStringSync(jsonEncode({'port': 9, 'token': 'old', 'pid': 1}));
      expect(await findRunningHelper(home.path, client: MockClient((r) async => throw const SocketException('refused'))), isNull);
      expect(await findRunningHelper(home.path, client: MockClient((r) async => http.Response('no', 401))), isNull);
    });

    test('a record whose helper answers with its token is joined', () async {
      File('${home.path}/helper.json').writeAsStringSync(jsonEncode({'port': 4321, 'token': 'tok', 'version': '0.1.0', 'pid': 7}));
      final seen = <String>[];
      final info = await findRunningHelper(home.path, client: MockClient((r) async {
        seen.add('${r.url} ${r.headers['Authorization']}');
        return http.Response('{"ok":true}', 200);
      }));
      expect(info!.port, 4321);
      expect(info.token, 'tok');
      expect(seen.single, 'http://127.0.0.1:4321/health Bearer tok');
    });

    test('the helper that ships with the app is found next to it, and nowhere else by accident', () {
      final app = Directory.systemTemp.createTempSync('app_');
      expect(locateRuntime(exeDir: app.path, env: const {}), isNull);
      Directory('${app.path}/runtime/python').createSync(recursive: true);
      File('${app.path}/runtime/python/python.exe').writeAsStringSync('');
      Directory('${app.path}/runtime/helper/altrobyte_helper').createSync(recursive: true);
      File('${app.path}/runtime/helper/altrobyte_helper/__main__.py').writeAsStringSync('');
      final r = locateRuntime(exeDir: app.path, env: const {})!;
      expect(r.python, endsWith('python.exe'));
      expect(r.helperDir, endsWith('helper'));
    });

    test('with no running helper and no runtime the learner is told what to do', () async {
      await expectLater(connectHelper(runtime: null, home: home.path), throwsA(isA<HelperError>().having((e) => e.message, 'message', contains('not found'))));
    });

    test('the helper folder follows the same rules as the helper itself', () {
      expect(helperHome({'ALTROBYTE_HOME': 'X:/h'}), 'X:/h');
      expect(helperHome({'LOCALAPPDATA': 'C:/L'}), 'C:/L${Platform.pathSeparator}Altrobyte');
    });
  });

  group('the conversation', () {
    test('settings are read, a starter folder is made once, and events start flowing', () async {
      final h = FakeHelper();
      final c = h.controller(starter: () => 'C:/Users/me/Documents/Altrobyte/esp32-temperature');
      await c.init();
      expect(c.ready, isTrue);
      expect(c.projectDir, 'C:/Users/me/Documents/Altrobyte/esp32-temperature');
      expect(c.grants, {'system', 'workspace'});
      expect(h.calls, containsAllInOrder(['GET /settings', 'PUT /settings']));
      c.dispose();
    });

    test('a folder that no longer exists is replaced by the starter folder', () async {
      final h = FakeHelper()..settings['project_dir'] = 'C:/gone/temp-project';
      final c = HelperController(HelperClient(const HelperInfo(port: 1, token: 'tok'), client: h.client),
          starterFolder: () => 'C:/Users/me/Documents/Altrobyte/esp32-temperature', folderExists: (p) => false, pollEvery: const Duration(hours: 1));
      await c.init();
      expect(c.projectDir, 'C:/Users/me/Documents/Altrobyte/esp32-temperature');
      c.dispose();
    });

    test('a folder the learner already chose is left alone', () async {
      final h = FakeHelper()..settings['project_dir'] = 'D:/mine';
      final c = HelperController(HelperClient(const HelperInfo(port: 1, token: 'tok'), client: h.client),
          starterFolder: () => fail('must not replace the learner\'s folder'), folderExists: (p) => true, pollEvery: const Duration(hours: 1));
      await c.init();
      expect(c.projectDir, 'D:/mine');
      c.dispose();
    });

    test('starting asks for the experiment; the trainer\'s messages, progress and finish arrive as events', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.signIn('tok-cloud');
      await c.start(labId: 4);
      expect(h.calls.last, 'POST /session/start');
      expect(h.bodies.last, {'lab_id': 4});
      expect(c.busy, isTrue);
      h.emit('activity', {'text': 'reading platformio.ini'});
      h.emit('message', {'text': 'Hi! Is your board plugged in?'});
      h.emit('state', {
        'mission': 'm',
        'progress': [
          {'id': 'a', 'title': 'Board connected', 'status': 'done'},
          {'id': 'b', 'title': 'Sensor wired', 'status': 'pending'},
        ],
      });
      await settle();
      expect(c.activity, 'reading platformio.ini');
      expect(c.chat.first.interactive, 'lesson'); // the experiment's note is offered before the trainer speaks
      expect(c.chat.first.props!['lab'], 4);
      expect(c.chat.where((b) => b.role == 'trainer').single.text, 'Hi! Is your board plugged in?');
      expect(c.state!.doneCount, 1);
      h.emit('turn_done', {'waiting': true, 'finished': false});
      await settle();
      expect(c.busy, isFalse);
      expect(c.activity, '');
      h.emit('turn_done', {'finished': true});
      await settle();
      expect(c.chat.last.text, contains('Mission complete'));
      c.dispose();
    });

    test('a plain session sends no module, and a helper that refuses explains why', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start();
      expect(h.bodies.last, isEmpty);
      c.dispose();

      final h2 = FakeHelper()
        ..startStatus = 409
        ..startDetail = 'The trainer is busy.';
      final c2 = h2.controller();
      await c2.init();
      await c2.start();
      expect(c2.started, isFalse);
      expect(c2.busy, isFalse);
      expect(c2.chat.single.text, 'The trainer is busy.');
      c2.dispose();
    });

    test('what the learner types is sent once, and not while the trainer is still answering', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start();
      h.emit('turn_done', {});
      await settle();
      await c.send('  my board is on COM6  ');
      expect(h.calls.last, 'POST /session/chat');
      expect(h.bodies.last, {'text': 'my board is on COM6'});
      await c.send('again');
      expect(h.bodies.where((b) => b['text'] != null).length, 1);
      expect(c.chat.where((b) => b.role == 'learner').length, 1);
      c.dispose();
    });

    test('an approval question is shown to the learner and their answer goes back; no handler means no', () async {
      final h = FakeHelper();
      Approval? asked;
      final c = h.controller(ask: (a) async {
        asked = a;
        return true;
      });
      await c.init();
      h.emit('approval_request', {'id': 'r1', 'title': 'Build your project?', 'detail': 'pio run'});
      await settle();
      expect(asked!.title, 'Build your project?');
      expect(h.calls.last, 'POST /approvals/r1');
      expect(h.bodies.last, {'allow': true});
      c.dispose();

      final h2 = FakeHelper();
      final c2 = h2.controller();
      await c2.init();
      h2.emit('approval_request', {'id': 'r2', 'title': 't', 'detail': 'd'});
      await settle();
      expect(h2.bodies.last, {'allow': false});
      c2.dispose();
    });

    test('pictures and the pin form appear in the chat; only the wiring opens by itself', () async {
      final h = FakeHelper();
      final opened = <String>[];
      final c = h.controller(picture: (p) async {
        opened.add('${p['title']}');
        return true;
      });
      await c.init();
      h.emit('ui', {'type': 'pin_map', 'props': {}});
      h.emit('ui', {'type': 'wiring_diagram', 'props': {'title': 'How to connect it', 'svg': '<svg/>'}});
      h.emit('ui', {'type': 'visual', 'props': {'title': 'Divider', 'html': '<p/>'}});
      await settle();
      expect(c.chat.map((b) => b.interactive), ['pin_map', 'picture', 'picture']);
      expect(opened, ['How to connect it']);
      c.dispose();
    });

    test('the trainer pointing at a file opens it in the editor', () async {
      final h = FakeHelper();
      final opened = <String>[];
      final c = h.controller(open: (path, line) async => opened.add('$path:$line'));
      await c.init();
      h.emit('open_file', {'path': 'C:/proj/src/main.cpp', 'line': 12});
      await settle();
      expect(opened, ['C:/proj/src/main.cpp:12']);
      c.dispose();
    });

    test('failures are explained in words the learner can act on, and "gone" ends the session', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start();
      h.emit('error', {'kind': 'offline', 'message': 'x'});
      await settle();
      expect(c.busy, isFalse);
      expect(c.chat.last.text, contains('No internet'));
      h.emit('error', {'kind': 'quota', 'message': 'Today\'s quota is used up.'});
      h.emit('error', {'kind': 'gone', 'message': 'No session.'});
      await settle();
      expect(c.chat.map((b) => b.text), contains('Today\'s quota is used up.'));
      expect(c.started, isFalse);
      c.dispose();
    });

    test('the end of the event stream means the helper is gone, and says so once', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      expect(c.lost, isFalse);
      var notified = 0;
      c.addListener(() => notified++);
      await h.sse.close();
      await settle();
      expect(c.lost, isTrue);
      expect(notified, 1);
      c.dispose();
    });
  });

  group('permissions, folder, board and the audit trail all live in the helper', () {
    test('switching a connector sends the whole allowed list; the MQTT password is only sent when typed', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.setGrant('serial', true);
      expect(h.bodies.last, {'grants': ['serial', 'system', 'workspace']});
      await c.setGrant('system', false);
      expect(h.bodies.last, {'grants': ['serial', 'workspace']});
      await c.saveMqtt(host: 'b.example.com', port: 8883, tls: true, username: 'u');
      expect((h.bodies.last['mqtt'] as Map).containsKey('password'), isFalse);
      await c.saveMqtt(host: 'b.example.com', port: 8883, tls: true, username: 'u', password: 'secret');
      expect((h.bodies.last['mqtt'] as Map)['password'], 'secret');
      await c.setProjectDir('D:/new');
      expect(c.projectDir, 'D:/new');
      c.dispose();
    });

    test('the serial monitor and the audit trail are read from the helper', () async {
      final h = FakeHelper()
        ..settings['grants'] = ['serial']
        ..monitor = {'running': true, 'port': 'COM6', 'baud': 115200, 'lines': ['temp 24.5 C', 'temp 24.6 C']}
        ..audit = [
          {'t': '2026-10-08T12:30:15', 'kind': 'op', 'op': 'read_file', 'args': {'path': 'platformio.ini'}, 'outcome': 'ok'},
          {'t': '2026-10-08T12:30:16', 'kind': 'cloud', 'what': 'learner message', 'bytes': 31, 'masked': 1},
          {'t': '2026-10-08T12:30:17', 'kind': 'grants', 'connectors': ['serial']},
        ];
      final c = h.controller();
      await c.init();
      await c.start();
      await c.refreshSide();
      expect(c.monitorRunning, isTrue);
      expect(c.monitorPort, 'COM6');
      expect(c.monitorLines.last, 'temp 24.6 C');
      expect(c.auditLines.length, 3);
      expect(c.auditLines.last, contains('ASKED  read_file'));
      expect(c.auditLines.any((l) => l.contains('1 secret(s) hidden')), isTrue);
      await c.startMonitor();
      expect(h.calls, contains('POST /monitor/start'));
      c.dispose();
    });

    test('a new session ends the old one and stops the board monitor', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start();
      h.emit('turn_done', {});
      await settle();
      await c.newSession();
      expect(h.calls, containsAll(['POST /session/end', 'POST /monitor/stop']));
      expect(c.started, isFalse);
      expect(c.chat, isEmpty);
      c.dispose();
    });
  });

  group('courses, quizzes and getting the computer ready', () {
    test('a built-in course is started by name, and a module experiment still by number', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_welcome');
      expect(h.bodies.last, {'course': 'intro_welcome'});
      expect(c.courseId, 'intro_welcome');
      await c.newSession();
      expect(c.courseId, isNull);
      await c.start(labId: 4);
      expect(h.bodies.last, {'lab_id': 4});
      c.dispose();
    });

    test('a quiz card appears in the chat, and a tap sends the exact tagged answer the trainer expects', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_welcome');
      h.emit('ui', {'type': 'quiz', 'props': {'milestone': 'what_is_current', 'question': 'Which part is a thin pipe?', 'options': ['A resistor', 'A battery']}});
      h.emit('turn_done', {'finished': false});
      await settle();
      expect(c.chat.last.interactive, 'quiz');
      expect(c.chat.last.props!['options'], ['A resistor', 'A battery']);
      expect(c.chat.last.props!.containsKey('answer'), isFalse);
      await c.answerQuiz('what_is_current', 0, 'A resistor');
      expect(h.bodies.last, {'text': '[quiz answer] milestone=what_is_current choice=0'});
      expect(c.chat.where((b) => b.role == 'learner').last.text, 'A resistor'); // the learner sees their own words, not the tag
      expect(quizAnswerText('x', 2), '[quiz answer] milestone=x choice=2');
      c.dispose();
    });

    test('suggested replies arrive as a chip row after the question, and a tap is an ordinary message', () async {
      final h = FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_welcome');
      h.emit('message', {'text': 'Have you used electronics before?'});
      h.emit('ui', {'type': 'replies', 'props': {'options': ['Yes, I have', 'No, never']}});
      h.emit('turn_done', {'finished': false});
      await settle();
      expect(c.chat.last.interactive, 'replies');
      expect(c.chat.last.props!['options'], ['Yes, I have', 'No, never']);
      await c.send('No, never');
      expect(h.bodies.last, {'text': 'No, never'});
      expect(identical(c.chat.where((b) => b.interactive == 'replies').last, c.chat.last), isFalse); // no longer the live question
      c.dispose();
    });

    test('the banner names the first step that is neither done nor locked', () {
      TrainerState st(List<Map<String, dynamic>> p) => TrainerState.fromJson({'mission': 'm', 'scenario': '', 'progress': p});
      Map<String, dynamic> m(String id, String status) => {'id': id, 'title': 'Step $id', 'stage': 's', 'status': status};
      expect(currentStepTitle(st([m('a', 'done'), m('b', 'blocked'), m('c', 'pending')])), 'Step c');
      expect(currentStepTitle(st([m('a', 'done')])), isNull);
      expect(currentStepTitle(null), isNull);
    });

    test('the computer check is read from the helper, and a download shows progress then looks again', () async {
      final h = FakeHelper()
        ..setupReport = {
          'items': [
            {'id': 'esp32_support', 'label': 'ESP32 support', 'state': 'missing', 'can_install': true, 'how': [], 'why': 'x', 'detail': ''},
          ],
          'ready': false,
        };
      final c = h.controller();
      await c.init();
      await c.checkSetup();
      expect((c.setupReport!['items'] as List).length, 1);
      expect(await c.installSetup('esp32_support'), isNull);
      expect(h.bodies.last, {'item': 'esp32_support'});
      h.emit('setup', {'item': 'esp32_support', 'state': 'working', 'line': 'Downloading 40%', 'percent': 40});
      await settle();
      expect(c.setupProgress['esp32_support']!['percent'], 40);
      h.setupReport = {'items': [], 'ready': true};
      h.emit('setup', {'item': 'esp32_support', 'state': 'done', 'line': 'ESP32 support is ready.', 'percent': 100});
      await settle();
      expect(c.setupProgress, isEmpty);
      expect(c.setupReport!['ready'], isTrue); // it looked again by itself
      c.dispose();
    });

    test('a second download while one runs is refused with the helper own words', () async {
      final h = FakeHelper()..installStatus = 409;
      final c = h.controller();
      await c.init();
      expect(await c.installSetup('editor'), contains('still running'));
      expect(c.setupProgress, isEmpty);
      c.dispose();
    });
  });

  group('small things', () {
    test('a helper from an older app is recognised so it can be replaced', () {
      expect(versionAtLeast('0.2.0', '0.2.0'), isTrue);
      expect(versionAtLeast('0.10.1', '0.2.0'), isTrue);
      expect(versionAtLeast('1.0', '0.2.0'), isTrue);
      expect(versionAtLeast('0.1.0', '0.2.0'), isFalse);
      expect(versionAtLeast('', '0.2.0'), isFalse);
    });

    test('a problem loading the modules is said in plain words', () {
      expect(modulesProblem('HelperError 401 Unauthorized'), contains('sign in'));
      expect(modulesProblem('SocketException: Failed host lookup'), contains('internet'));
      expect(modulesProblem('FormatException'), contains('Try again'));
    });

    test('the version in the code is the version the installer is stamped with', () {
      final pubspec = File('desktop_app/pubspec.yaml').readAsStringSync();
      expect(RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1), appVersion);
      expect(versionAtLeast(appVersion, appVersion), isTrue);
      expect(versionAtLeast('1.0.0', '1.0.1'), isFalse); // a published 1.0.1 means a 1.0.0 app is out of date
      expect(versionAtLeast(appVersion, '1.1.0'), isTrue); // V1 of the trainer
    });

    test('the project a file belongs to is the folder above it that has a platformio.ini', () {
      bool has(String p) => p == r'C:\Users\me\Documents\Altrobyte\blink\platformio.ini' || p == '/home/me/blink/platformio.ini';
      expect(projectRootOf(r'C:\Users\me\Documents\Altrobyte\blink\src\main.cpp', exists: has), r'C:\Users\me\Documents\Altrobyte\blink');
      expect(projectRootOf('/home/me/blink/src/deep/a.cpp', exists: has), '/home/me/blink');
      expect(projectRootOf(r'C:\other\src\main.cpp', exists: has), isNull);
      expect(projectRootOf('main.cpp', exists: has), isNull);
    });

    test('a lesson page may run its own script but can reach nothing', () {
      final page = lessonPage('<!DOCTYPE html><html><head><title>t</title></head><body><script>1</script></body></html>');
      expect(page, contains("default-src 'none'"));
      expect(page, contains("script-src 'unsafe-inline'"));
      expect(page, isNot(contains('connect-src')));
      expect(page.indexOf('Content-Security-Policy') < page.indexOf('<script>'), isTrue); // the rule comes before any script
      expect(lessonPage('<p>bare</p>'), contains('Content-Security-Policy'));
    });

    test('the picture page allows no script and no network and escapes its title', () {
      final page = visualPage('<b>x</b>', '<svg></svg>');
      expect(page, contains("default-src 'none'"));
      expect(page, isNot(contains('script-src')));
      expect(page, contains('&lt;b>x&lt;/b>'));
      expect(pictureBody({'svg': '<svg/>'}), '<svg/>');
      expect(pictureBody({}), '');
    });

    test('the starter folder is made under Documents/Altrobyte', () {
      final fake = Directory.systemTemp.createTempSync('home_');
      final made = starterFolder(env: {'USERPROFILE': fake.path})!;
      expect(Directory(made).existsSync(), isTrue);
      expect(made.replaceAll('\\', '/'), endsWith('Documents/Altrobyte/esp32-temperature'));
    });
  });

  // The real helper, started from the runtime that ships with the extension and the app.
  final runtimeDir = Directory('vscode_extension/runtime');
  final haveRuntime = File('${runtimeDir.path}/python/python.exe').existsSync();
  group('the real helper', () {
    test('two apps end up on one helper and share its settings', () async {
      final home = Directory.systemTemp.createTempSync('real_helper_');
      final env = {'ALTROBYTE_HOME': home.path, 'ALTROBYTE_IDLE_SECONDS': '300'};
      final runtime = locateRuntime(env: {'ALTROBYTE_RUNTIME': runtimeDir.absolute.path})!;
      HelperClient? a;
      try {
        final first = await connectHelper(runtime: runtime, home: home.path, env: env);
        final second = await connectHelper(runtime: runtime, home: home.path, env: env);
        expect(second.port, first.port);
        expect(second.token, first.token);

        a = HelperClient(first);
        final b = HelperClient(second);
        await a.put('/settings', {'project_dir': home.path});
        expect((await b.get('/settings'))['project_dir'], home.path);
        expect((await b.get('/health'))['ok'], isTrue);

        final ctl = HelperController(a, pollEvery: const Duration(hours: 1));
        await ctl.init();
        expect(ctl.ready, isTrue);
        expect(ctl.projectDir, home.path);
        expect((await b.get('/health'))['listeners'], 1); // the app is listening: the helper stays up for it
        ctl.dispose();
      } finally {
        if (a != null) {
          try {
            await a.post('/shutdown');
          } catch (_) {}
        }
      }
    }, skip: haveRuntime ? false : 'the runtime has not been built (python vscode_extension/tools/build_runtime.py)');
  });
}
