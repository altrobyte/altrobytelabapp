// The Altrobyte helper: one small local service per computer that does everything that needs this computer (looking at
// the board, the project files, PlatformIO, the serial port, speech) and asks the learner first. The VS Code extension and
// this app are both just windows onto it, so settings, permissions and progress are the same in both.
//
// This file finds the running helper (or starts one from the runtime that ships with the app) and talks to it over
// 127.0.0.1 with its token. Nothing here knows about Flutter widgets.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'sse.dart';

class HelperInfo {
  final int port;
  final String token;
  final String version;
  final int pid;
  const HelperInfo({required this.port, required this.token, this.version = '', this.pid = 0});

  factory HelperInfo.fromJson(Map<String, dynamic> j) => HelperInfo(
        port: (j['port'] as num).toInt(),
        token: '${j['token']}',
        version: '${j['version'] ?? ''}',
        pid: (j['pid'] as num?)?.toInt() ?? 0,
      );
}

class HelperError implements Exception {
  final int status;
  final String message;
  const HelperError(this.status, this.message);
  @override
  String toString() => message;
}

class HelperEvent {
  final String kind;
  final Map<String, dynamic> data;
  const HelperEvent(this.kind, this.data);
}

/// The helper's folder: the same one the helper uses (ALTROBYTE_HOME overrides, for tests).
String helperHome([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  if ((e['ALTROBYTE_HOME'] ?? '').isNotEmpty) return e['ALTROBYTE_HOME']!;
  final local = e['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) return '$local${Platform.pathSeparator}Altrobyte';
  return '${e['HOME'] ?? e['USERPROFILE'] ?? '.'}${Platform.pathSeparator}.altrobyte';
}

/// The helper that is already running, if its record is readable and it really answers with its token.
Future<HelperInfo?> findRunningHelper(String home, {http.Client? client, Duration timeout = const Duration(milliseconds: 1500)}) async {
  HelperInfo info;
  try {
    final raw = jsonDecode(File('$home${Platform.pathSeparator}helper.json').readAsStringSync());
    if (raw is! Map || raw['port'] is! num || raw['token'] is! String) return null;
    info = HelperInfo.fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    return null;
  }
  final c = client ?? http.Client();
  try {
    final res = await c.get(Uri.parse('http://127.0.0.1:${info.port}/health'), headers: {'Authorization': 'Bearer ${info.token}'}).timeout(timeout);
    return res.statusCode == 200 ? info : null;
  } catch (_) {
    return null; // a record of a helper that is gone
  } finally {
    if (client == null) c.close();
  }
}

/// Where the helper's own Python and code are: next to the app (shipped with it), or a development checkout.
class HelperRuntime {
  final String python;
  final String helperDir;
  const HelperRuntime(this.python, this.helperDir);
}

HelperRuntime? locateRuntime({String? exeDir, Map<String, String>? env}) {
  final e = env ?? Platform.environment;
  final sep = Platform.pathSeparator;
  final roots = <String>[
    if ((e['ALTROBYTE_RUNTIME'] ?? '').isNotEmpty) e['ALTROBYTE_RUNTIME']!,
    if (exeDir != null) '$exeDir${sep}runtime',
  ];
  for (final r in roots) {
    final py = '$r${sep}python${sep}python.exe';
    final dir = '$r${sep}helper';
    if (File(py).existsSync() && File('$dir${sep}altrobyte_helper${sep}__main__.py').existsSync()) return HelperRuntime(py, dir);
  }
  // A development checkout next to this project, with the system Python.
  final dev = e['ALTROBYTE_HELPER_DIR'];
  if (dev != null && File('$dev${sep}altrobyte_helper${sep}__main__.py').existsSync()) {
    return HelperRuntime(e['ALTROBYTE_PYTHON'] ?? 'python', dev);
  }
  return null;
}

/// Starts the helper and waits for its "ready" line. If another helper turned out to be running (two apps started at the
/// same moment), the line says so and that one is used; nothing new was started.
Future<HelperInfo> launchHelper(HelperRuntime runtime, {Map<String, String>? env, Duration timeout = const Duration(seconds: 30)}) async {
  final proc = await Process.start(runtime.python, ['-u', '-m', 'altrobyte_helper'],
      workingDirectory: runtime.helperDir,
      environment: env,
      mode: ProcessStartMode.detachedWithStdio, // it is shared with other apps and ends itself when nobody uses it
      runInShell: false);
  final ready = Completer<HelperInfo>();
  final stderrText = StringBuffer();
  final subs = <StreamSubscription>[];
  void fail(String m) {
    if (!ready.isCompleted) ready.completeError(HelperError(0, m));
  }

  subs.add(proc.stderr.transform(utf8.decoder).listen((s) => stderrText.write(s)));
  subs.add(proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    final t = line.trim();
    if (!t.startsWith('{')) return;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(t) as Map);
      if (j['event'] == 'ready' && !ready.isCompleted) ready.complete(HelperInfo.fromJson(j));
    } catch (_) {}
  }, onDone: () => fail('The helper stopped right away.${stderrText.isEmpty ? '' : '\n${stderrText.toString().trim()}'}')));
  try {
    return await ready.future.timeout(timeout, onTimeout: () {
      throw HelperError(0, 'The helper did not start within ${timeout.inSeconds}s.${stderrText.isEmpty ? '' : '\n${stderrText.toString().trim()}'}');
    });
  } finally {
    for (final s in subs) {
      await s.cancel();
    }
  }
}

/// The oldest helper this app works with: before it, the tutor's voice and the app's own build folder do not exist.
const minHelperVersion = '0.3.0';

/// True when [have] ("0.1.0") is the same as or newer than [need]. An unreadable version counts as too old.
bool versionAtLeast(String have, String need) {
  final a = have.split('.').map(int.tryParse).toList();
  final b = need.split('.').map(int.tryParse).toList();
  if (a.any((n) => n == null)) return false;
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final x = i < a.length ? a[i]! : 0;
    final y = i < b.length ? (b[i] ?? 0) : 0;
    if (x != y) return x > y;
  }
  return true;
}

/// Asks a running helper to end, and waits until it has.
Future<void> retireHelper(HelperInfo info, String home, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    await c.post(Uri.parse('http://127.0.0.1:${info.port}/shutdown'), headers: {'Authorization': 'Bearer ${info.token}'}).timeout(const Duration(seconds: 3));
  } catch (_) {
    return;
  } finally {
    if (client == null) c.close();
  }
  for (var i = 0; i < 40; i++) {
    if (await findRunningHelper(home, timeout: const Duration(milliseconds: 500)) == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

/// Joins the helper that is running on this computer, or starts one. There is only ever one.
/// A helper left running by an older app or extension is replaced by this app's own, so every window has the same abilities.
Future<HelperInfo> connectHelper({HelperRuntime? runtime, String? home, Map<String, String>? env}) async {
  final where = home ?? helperHome(env);
  final found = await findRunningHelper(where);
  if (found != null) {
    if (versionAtLeast(found.version, minHelperVersion) || runtime == null) return found;
    await retireHelper(found, where);
  }
  if (runtime == null) {
    throw const HelperError(0, 'The Altrobyte helper was not found. Reinstall the app, or install the Altrobyte extension in VS Code.');
  }
  return launchHelper(runtime, env: env);
}

/// Talks to the helper. [http] is replaceable so the conversation can be tested without a real helper.
class HelperClient {
  final HelperInfo info;
  final http.Client? _injected;
  final http.Client _http;
  HelperClient(this.info, {http.Client? client})
      : _injected = client,
        _http = client ?? http.Client();

  String get base => 'http://127.0.0.1:${info.port}';
  Map<String, String> _headers({bool json = true}) => {'Authorization': 'Bearer ${info.token}', if (json) 'Content-Type': 'application/json'};

  dynamic _decode(http.Response r) {
    if (r.statusCode >= 400) {
      var detail = r.reasonPhrase ?? 'Error';
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map && j['detail'] is String) detail = j['detail'] as String;
      } catch (_) {}
      throw HelperError(r.statusCode, detail);
    }
    if (r.bodyBytes.isEmpty) return {};
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<Map<String, dynamic>> get(String path) async => Map<String, dynamic>.from(_decode(await _http.get(Uri.parse('$base$path'), headers: _headers(json: false))) as Map);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(_decode(await _http.put(Uri.parse('$base$path'), headers: _headers(), body: jsonEncode(body))) as Map);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async =>
      Map<String, dynamic>.from(_decode(await _http.post(Uri.parse('$base$path'), headers: _headers(), body: jsonEncode(body ?? {}))) as Map);

  /// The helper's event stream, until it ends or the subscription is cancelled. The connection belongs to this stream:
  /// cancelling it closes it cleanly, so shutting the app down never leaves an error behind. An error on the connection
  /// simply ends the stream, which is how the caller learns the helper is gone.
  Stream<HelperEvent> events() {
    final own = _injected == null ? http.Client() : null; // a stand-in is shared, the real client is this stream's own
    final c = _injected ?? own!;
    StreamSubscription<String>? sub;
    late final StreamController<HelperEvent> out;
    out = StreamController<HelperEvent>(
      onListen: () async {
        try {
          final req = http.Request('GET', Uri.parse('$base/events'))..headers.addAll(_headers(json: false));
          final res = await c.send(req);
          if (res.statusCode != 200) {
            out.addError(HelperError(res.statusCode, 'The helper refused the event stream.'));
            await out.close();
            return;
          }
          final parser = SseParser();
          sub = res.stream.transform(utf8.decoder).listen((chunk) {
            for (final ev in parser.push(chunk)) {
              Map<String, dynamic> data = {};
              try {
                if (ev.data.isNotEmpty) data = Map<String, dynamic>.from(jsonDecode(ev.data) as Map);
              } catch (_) {}
              if (!out.isClosed) out.add(HelperEvent(ev.event, data));
            }
          }, onError: (_) {
            if (!out.isClosed) out.close();
          }, onDone: () {
            if (!out.isClosed) out.close();
          }, cancelOnError: true);
        } catch (_) {
          if (!out.isClosed) await out.close(); // could not connect at all: the same as the helper being gone
        }
      },
      onCancel: () async {
        await sub?.cancel();
        own?.close();
      },
    );
    return out.stream;
  }

  void close() => _http.close();
}
