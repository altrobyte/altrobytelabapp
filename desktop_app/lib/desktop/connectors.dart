// The learner's own computer, as the trainer is allowed to see and use it.
//
// The server-side trainer can only ask for the fixed operations below (see
// trainer/remote.py: OPS). Each one belongs to a connector the learner switches
// on, read-only by default; anything that changes the machine (build, upload)
// asks the learner first, every time. Nothing here runs a command the server
// sends — the commands are all spelled out in this file.
//
// All access to the outside world goes through small interfaces (ProcessRunner,
// SerialSource, MqttProbe) so the logic is testable without hardware.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The connectors a learner can allow. Names match the server's.
const connectorSystem = 'system';
const connectorWorkspace = 'workspace';
const connectorToolchain = 'toolchain';
const connectorSerial = 'serial';
const connectorMqtt = 'mqtt';
const allConnectors = [connectorSystem, connectorWorkspace, connectorToolchain, connectorSerial, connectorMqtt];

const connectorOfOp = {
  'os_info': connectorSystem,
  'software_version': connectorSystem,
  'serial_ports': connectorSystem,
  'list_files': connectorWorkspace,
  'read_file': connectorWorkspace,
  'diagnostics': connectorWorkspace,
  'run_build': connectorToolchain,
  'run_upload': connectorToolchain,
  'serial_tail': connectorSerial,
  'mqtt_messages': connectorMqtt,
};

class UserDeclined implements Exception {
  const UserDeclined();
}

class NotAllowed implements Exception {
  final String message;
  const NotAllowed(this.message);
  @override
  String toString() => message;
}

/// Asks the learner. Returns true if they agree.
typedef Approve = Future<bool> Function(String title, String detail);

// ── process access ──────────────────────────────────────────────────────────

class ProcResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  const ProcResult(this.exitCode, this.stdout, this.stderr);
  String get output => [stdout, stderr].where((s) => s.trim().isNotEmpty).join('\n');
}

abstract class ProcessRunner {
  Future<ProcResult> run(String exe, List<String> args,
      {String? cwd, Duration timeout = const Duration(minutes: 2), bool shell = false});
}

class RealProcessRunner implements ProcessRunner {
  @override
  Future<ProcResult> run(String exe, List<String> args,
      {String? cwd, Duration timeout = const Duration(minutes: 2), bool shell = false}) async {
    final p = await Process.start(exe, args, workingDirectory: cwd, runInShell: shell);
    final out = StringBuffer(), err = StringBuffer();
    // Completion is signalled from onDone. (Attaching asFuture() after the process exits waits forever on a
    // stream that has already finished.)
    final outDone = Completer<void>(), errDone = Completer<void>();
    p.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen(out.write,
        onDone: outDone.complete, onError: (_) => outDone.complete());
    p.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(err.write,
        onDone: errDone.complete, onError: (_) => errDone.complete());
    try {
      final code = await p.exitCode.timeout(timeout);
      await Future.wait([outDone.future, errDone.future]).timeout(const Duration(seconds: 5), onTimeout: () => []);
      return ProcResult(code, out.toString(), err.toString());
    } on TimeoutException {
      p.kill(ProcessSignal.sigkill);
      return ProcResult(-1, out.toString(), '${err.toString()}\n[timed out after ${timeout.inSeconds}s]');
    }
  }
}

// ── locating the tools ──────────────────────────────────────────────────────

String? _env(String name) => Platform.environment[name];

String get _home => _env('USERPROFILE') ?? _env('HOME') ?? '';

/// PlatformIO's own folder: where its CLI and bundled Python live after the VS Code extension installs it.
String get pioHome => '$_home${Platform.pathSeparator}.platformio${Platform.pathSeparator}penv'
    '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}';

List<String> pioCandidates() => [
      '$pioHome${Platform.pathSeparator}${Platform.isWindows ? 'pio.exe' : 'pio'}',
      if (Platform.isWindows) 'pio.exe' else 'pio',
      if (Platform.isWindows) 'platformio.exe' else 'platformio',
    ];

List<String> pioPythonCandidates() => [
      '$pioHome${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
      if (Platform.isWindows) 'python.exe' else 'python3',
    ];

List<String> codeCandidates() => [
      if (Platform.isWindows && _env('LOCALAPPDATA') != null)
        '${_env('LOCALAPPDATA')}\\Programs\\Microsoft VS Code\\bin\\code.cmd',
      if (Platform.isWindows) 'code.cmd' else 'code',
    ];

// ── parsing (pure, tested) ──────────────────────────────────────────────────

/// `monitor_speed` from a platformio.ini; PlatformIO's monitor defaults to 9600 when it is not set.
int monitorSpeedFromIni(String ini) {
  final m = RegExp(r'^\s*monitor_speed\s*=\s*(\d+)', multiLine: true).firstMatch(ini);
  return m == null ? 9600 : int.parse(m.group(1)!);
}

class UsbPort {
  final String port;
  final String description;
  final String vidPid;
  final bool driverOk;
  const UsbPort(this.port, this.description, this.vidPid, this.driverOk);

  Map<String, dynamic> toJson() =>
      {'port': port, 'description': description, 'vid_pid': vidPid, 'driver_ok': driverOk};
}

/// "10C4:EA60" from either hardware-id style Windows reports: `USB VID:PID=10C4:EA60 ...` or `USB\VID_10C4&PID_EA60\...`.
String vidPidOf(String hwid) {
  final m = RegExp(r'VID:PID=([0-9A-Fa-f]{4}):([0-9A-Fa-f]{4})').firstMatch(hwid) ??
      RegExp(r'VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})').firstMatch(hwid);
  return m == null ? '' : '${m.group(1)}:${m.group(2)}'.toUpperCase();
}

/// USB serial devices from `pio device list --json-output`. Built-in ports (Bluetooth, Intel SOL, ...) are
/// ignored: they would make "a board is plugged in" true on every laptop.
List<UsbPort> parsePioDeviceList(String stdout) {
  final start = stdout.indexOf('[');
  if (start < 0) return [];
  List<dynamic> raw;
  try {
    raw = jsonDecode(stdout.substring(start)) as List<dynamic>;
  } catch (_) {
    return [];
  }
  final out = <UsbPort>[];
  for (final d in raw) {
    if (d is! Map) continue;
    final hwid = '${d['hwid'] ?? ''}';
    if (!hwid.toUpperCase().contains('VID')) continue;
    out.add(UsbPort('${d['port'] ?? ''}', '${d['description'] ?? ''}', vidPidOf(hwid), true));
  }
  return out;
}

/// USB-serial chips (CP210x, CH340, FTDI, ESP32-S3/C3 native USB) that Windows sees but has no working driver for.
/// Input: the JSON from the PnP query in [LocalMachine._portsWithoutDriver].
List<UsbPort> parseDriverlessDevices(String json) {
  if (json.trim().isEmpty) return [];
  dynamic doc;
  try {
    doc = jsonDecode(json);
  } catch (_) {
    return [];
  }
  final list = doc is List ? doc : [doc];
  final out = <UsbPort>[];
  for (final d in list) {
    if (d is! Map) continue;
    out.add(UsbPort('', '${d['FriendlyName'] ?? 'USB serial device'} (no driver)', vidPidOf('${d['InstanceId'] ?? ''}'), false));
  }
  return out;
}

class Diag {
  final String path;
  final int line;
  final String severity;
  final String message;
  const Diag(this.path, this.line, this.severity, this.message);
  Map<String, dynamic> toJson() => {'path': path, 'line': line, 'severity': severity, 'message': message};
}

/// Compiler errors and warnings from build output: `src/main.cpp:12:5: error: 'X' was not declared`.
List<Diag> parseDiagnostics(String buildOutput) {
  final rx = RegExp(r'^(.+?):(\d+):(?:\d+:)?\s*(fatal error|error|warning):\s*(.*)$', multiLine: true);
  final out = <Diag>[];
  for (final m in rx.allMatches(buildOutput)) {
    var path = m.group(1)!.trim().replaceAll('\\', '/');
    if (path.length > 2 && path[1] == ':') continue; // a system header path, not the learner's code
    out.add(Diag(path, int.parse(m.group(2)!), m.group(3)!.contains('error') ? 'error' : 'warning', m.group(4)!.trim()));
    if (out.length >= 40) break;
  }
  return out;
}

// ── serial monitor ──────────────────────────────────────────────────────────

abstract class SerialSource {
  Stream<String> open(String port, int baud);
  Future<void> close();
}

/// Reads the port with PlatformIO's own Python (it ships with pyserial), so no native plugin is needed and the
/// monitor needs no terminal. The learner uses *this* monitor, which makes us the single owner of the port.
class PioSerialSource implements SerialSource {
  static const script = '''
import sys, time, serial
port, baud = sys.argv[1], int(sys.argv[2])
last = None
while True:
    try:
        s = serial.Serial(port, baud, timeout=1)
        print("[monitor] opened %s at %d baud" % (port, baud), flush=True)
        last = None
        while True:
            line = s.readline()
            if line:
                print(line.decode("utf-8", "replace").rstrip("\\r\\n"), flush=True)
    except serial.SerialException as e:
        msg = "[monitor] %s" % e
        if msg != last:
            print(msg, flush=True)
            last = msg
        time.sleep(1.5)
''';

  final String python;
  Process? _p;
  PioSerialSource(this.python);

  @override
  Stream<String> open(String port, int baud) {
    final ctl = StreamController<String>();
    Process.start(python, ['-u', '-c', script, port, '$baud']).then((p) {
      _p = p;
      p.stdout.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen(ctl.add,
          onDone: ctl.close);
      p.stderr.drain<void>();
    }).catchError((Object e) {
      ctl.add('[monitor] could not start: $e');
      ctl.close();
    });
    return ctl.stream;
  }

  @override
  Future<void> close() async {
    _p?.kill();
    _p = null;
  }
}

class SerialMonitor {
  static const maxLines = 600;
  final SerialSource Function() sourceFactory;
  SerialSource? _source;
  StreamSubscription<String>? _sub;
  final List<String> lines = [];
  final StreamController<void> _changes = StreamController.broadcast();
  String? port;
  int baud = 9600;

  SerialMonitor(this.sourceFactory);

  Stream<void> get changes => _changes.stream;
  bool get running => _sub != null;

  void start(String port, int baud) {
    stop();
    this.port = port;
    this.baud = baud;
    _source = sourceFactory();
    _sub = _source!.open(port, baud).listen((l) {
      lines.add(l);
      if (lines.length > maxLines) lines.removeRange(0, lines.length - maxLines);
      _changes.add(null);
    }, onDone: () {
      _sub = null;
      _changes.add(null);
    });
    _changes.add(null);
  }

  /// Release the port (before an upload, or when the learner switches the connector off).
  ///
  /// The state is reset *before* anything is awaited: [start] calls this without waiting, and a late
  /// continuation that cleared fields afterwards used to wipe out the monitor it had just started.
  Future<void> stop() async {
    final sub = _sub, source = _source;
    _sub = null;
    _source = null;
    _changes.add(null);
    await sub?.cancel();
    await source?.close();
  }

  List<String> tail(int n) => lines.length <= n ? List.of(lines) : lines.sublist(lines.length - n);
}

// ── MQTT ────────────────────────────────────────────────────────────────────

class MqttSettings {
  String host;
  int port;
  bool tls;
  String username;
  String password;
  MqttSettings({this.host = '', this.port = 8883, this.tls = true, this.username = '', this.password = ''});
  bool get configured => host.trim().isNotEmpty;
}

/// Listens on a topic for a few seconds; the real one uses mqtt_client (see mqtt_probe.dart).
typedef MqttProbe = Future<List<String>> Function(MqttSettings settings, String topic, Duration listenFor);

// ── the machine ─────────────────────────────────────────────────────────────

class LocalMachine {
  final ProcessRunner runner;
  final SerialMonitor monitor;
  final MqttProbe mqttProbe;
  final MqttSettings mqtt;
  Approve approve;

  /// The folder the learner chose. Nothing outside it is ever read.
  String? projectDir;
  final Set<String> grants;
  String _lastBuildOutput = '';

  /// What the trainer asked of this machine, newest last — shown to the learner and kept as their audit trail.
  final List<String> log = [];
  final StreamController<void> logChanges = StreamController.broadcast();

  LocalMachine({
    required this.runner,
    required this.monitor,
    required this.mqttProbe,
    required this.approve,
    MqttSettings? mqtt,
    this.projectDir,
    Set<String>? grants,
  })  : mqtt = mqtt ?? MqttSettings(),
        grants = grants ?? {};

  void _note(String s) {
    log.add('${DateTime.now().toIso8601String().substring(11, 19)}  $s');
    if (log.length > 200) log.removeRange(0, log.length - 200);
    logChanges.add(null);
  }

  /// Executes one operation from the server and returns its result, or throws.
  /// Errors become `{error: ...}` answers in [handle] — they never crash the app.
  Future<dynamic> run(String op, Map<String, dynamic> args) async {
    final connector = connectorOfOp[op];
    if (connector == null) throw NotAllowed('unknown operation "$op"');
    if (!grants.contains(connector)) {
      _note('REFUSED  $op  ($connector is switched off)');
      throw NotAllowed('The learner has not allowed the "$connector" connector.');
    }
    _note('$op${args.isEmpty ? '' : '  ${jsonEncode(args)}'}');
    switch (op) {
      case 'os_info':
        return {'os': Platform.operatingSystem, 'version': Platform.operatingSystemVersion};
      case 'software_version':
        return softwareVersion('${args['name']}');
      case 'serial_ports':
        return (await serialPorts()).map((p) => p.toJson()).toList();
      case 'list_files':
        return listFiles();
      case 'read_file':
        return readFile('${args['path']}');
      case 'diagnostics':
        return parseDiagnostics(_lastBuildOutput).map((d) => d.toJson()).toList();
      case 'run_build':
        return build();
      case 'run_upload':
        return upload();
      case 'serial_tail':
        return serialTail((args['n'] as num?)?.toInt() ?? 40);
      case 'mqtt_messages':
        return mqttMessages('${args['topic']}', (args['seconds'] as num?)?.toDouble() ?? 5);
    }
    throw NotAllowed('unknown operation "$op"');
  }

  /// The answer the app posts back for a request.
  Future<Map<String, dynamic>> handle(String op, Map<String, dynamic> args) async {
    try {
      return {'result': await run(op, args)};
    } on UserDeclined {
      _note('DECLINED  $op');
      return {'error': 'user_declined'};
    } on NotAllowed catch (e) {
      return {'error': e.message};
    } catch (e) {
      return {'error': 'Could not do that on this computer: ${e.toString().split('\n').first}'};
    }
  }

  // ── system ──
  Future<String?> _firstWorking(List<String> candidates, List<String> args, {bool shell = false}) async {
    for (final exe in candidates) {
      try {
        final r = await runner.run(exe, args, shell: shell, timeout: const Duration(seconds: 25));
        if (r.exitCode == 0) return r.stdout;
      } catch (_) {
        // not there, try the next
      }
    }
    return null;
  }

  Future<String?> softwareVersion(String name) async {
    switch (name) {
      case 'vscode':
        final out = await _firstWorking(codeCandidates(), ['--version'], shell: true);
        return out?.trim().split('\n').first;
      case 'platformio-ide':
        final out = await _firstWorking(codeCandidates(), ['--list-extensions', '--show-versions'], shell: true);
        final m = RegExp(r'^platformio\.platformio-ide@(\S+)', multiLine: true, caseSensitive: false).firstMatch(out ?? '');
        return m?.group(1);
      case 'platformio-cli':
        final out = await _firstWorking(pioCandidates(), ['--version']);
        final m = RegExp(r'version\s+(\S+?),?\s*$', multiLine: true, caseSensitive: false).firstMatch(out ?? '');
        return m?.group(1) ?? out?.trim().split('\n').first;
      default:
        return null; // only tools on this list are ever probed
    }
  }

  Future<List<UsbPort>> serialPorts() async {
    final listed = await _firstWorking(pioCandidates(), ['device', 'list', '--json-output']);
    final ports = parsePioDeviceList(listed ?? '');
    return [...ports, ...await _portsWithoutDriver()];
  }

  Future<List<UsbPort>> _portsWithoutDriver() async {
    if (!Platform.isWindows) return [];
    const q = r"Get-PnpDevice -PresentOnly | Where-Object { $_.Status -ne 'OK' -and $_.InstanceId -match 'VID_(10C4|1A86|0403|303A)' } "
        r'| Select-Object FriendlyName,InstanceId | ConvertTo-Json -Compress';
    try {
      final r = await runner.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', q],
          timeout: const Duration(seconds: 20));
      return r.exitCode == 0 ? parseDriverlessDevices(r.stdout) : [];
    } catch (_) {
      return [];
    }
  }

  // ── workspace ──
  static const _skipDirs = {'.pio', '.git', '.vscode', 'node_modules', '.dart_tool', 'build', '__pycache__'};
  static const _textExt = {'ini', 'cpp', 'c', 'h', 'hpp', 'ino', 'txt', 'md', 'json', 'py', 'csv', 'yaml', 'yml'};
  static const maxFileBytes = 200 * 1024;

  Directory _root() {
    final d = projectDir;
    if (d == null || d.isEmpty) throw const NotAllowed('The learner has not chosen a project folder yet.');
    final dir = Directory(d);
    if (!dir.existsSync()) throw const NotAllowed('The chosen project folder no longer exists.');
    return dir;
  }

  List<String> listFiles() {
    final root = _root();
    final base = root.resolveSymbolicLinksSync();
    final out = <String>[];
    void walk(Directory d, int depth) {
      if (depth > 4 || out.length >= 200) return;
      for (final e in d.listSync(followLinks: false)) {
        final name = e.path.split(RegExp(r'[\\/]')).last;
        if (e is Directory) {
          if (!_skipDirs.contains(name) && !name.startsWith('.')) walk(e, depth + 1);
        } else if (e is File) {
          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
          if (_textExt.contains(ext)) out.add(e.path.substring(base.length + 1).replaceAll('\\', '/'));
        }
      }
    }

    walk(Directory(base), 0);
    out.sort();
    return out;
  }

  /// Reads one file, only if it really is inside the project folder (symlinks and `..` cannot escape it).
  String? readFile(String relPath) {
    if (relPath.isEmpty || relPath.startsWith('/') || relPath.startsWith('\\') || RegExp(r'^[A-Za-z]:').hasMatch(relPath)) {
      throw const NotAllowed('Only paths inside the project folder can be read.');
    }
    if (relPath.replaceAll('\\', '/').split('/').contains('..')) {
      throw const NotAllowed('Only paths inside the project folder can be read.');
    }
    final base = _root().resolveSymbolicLinksSync();
    final f = File('$base${Platform.pathSeparator}$relPath');
    if (!f.existsSync()) return null;
    final real = f.resolveSymbolicLinksSync();
    final sep = Platform.pathSeparator;
    if (real != base && !real.startsWith('$base$sep')) {
      throw const NotAllowed('That file is outside the project folder.');
    }
    if (f.lengthSync() > maxFileBytes) return '[file too large to read: ${f.lengthSync()} bytes]';
    return utf8.decode(f.readAsBytesSync(), allowMalformed: true);
  }

  // ── toolchain ──
  Future<String> _pio() async {
    for (final exe in pioCandidates()) {
      try {
        final r = await runner.run(exe, ['--version'], timeout: const Duration(seconds: 25));
        if (r.exitCode == 0) return exe;
      } catch (_) {}
    }
    throw const NotAllowed('PlatformIO is not installed on this computer.');
  }

  Future<Map<String, dynamic>> build() async {
    final dir = _root().path;
    if (!await approve('Build your project?', 'The trainer wants to run:\n  pio run\nin\n  $dir\n\nThis compiles your code. It does not change your source files.')) {
      throw const UserDeclined();
    }
    final pio = await _pio();
    final r = await runner.run(pio, ['run', '-d', dir], timeout: const Duration(minutes: 10));
    _lastBuildOutput = r.output;
    return {'ok': r.exitCode == 0, 'output': r.output};
  }

  Future<Map<String, dynamic>> upload() async {
    final dir = _root().path;
    final ports = (await serialPorts()).where((p) => p.driverOk && p.port.isNotEmpty).toList();
    final port = ports.isEmpty ? null : ports.first.port;
    if (!await approve('Upload to your board?',
        'The trainer wants to run:\n  pio run -t upload${port == null ? '' : ' --upload-port $port'}\nin\n  $dir\n\n'
        'This writes new firmware to the board plugged into ${port ?? 'your computer'}.')) {
      throw const UserDeclined();
    }
    final pio = await _pio();
    final wasMonitoring = monitor.running;
    final monitored = monitor.port;
    await monitor.stop(); // the upload needs the port to itself
    try {
      final r = await runner.run(pio, ['run', '-d', dir, '-t', 'upload', if (port != null) ...['--upload-port', port]],
          timeout: const Duration(minutes: 5));
      _lastBuildOutput = r.output;
      return {'ok': r.exitCode == 0, 'output': r.output, 'port': port ?? ''};
    } finally {
      if (wasMonitoring && monitored != null) {
        monitor.start(monitored, monitorSpeedFromIni(_iniText()));
      }
    }
  }

  String _iniText() {
    try {
      return readFile('platformio.ini') ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── serial ──
  Future<List<String>> serialTail(int n) async {
    if (!monitor.running) {
      final ports = (await serialPorts()).where((p) => p.driverOk && p.port.isNotEmpty).toList();
      if (ports.isEmpty) return ['[monitor] no USB serial device is connected'];
      monitor.start(ports.first.port, monitorSpeedFromIni(_iniText()));
      await Future<void>.delayed(const Duration(seconds: 3)); // let the board's output arrive
    }
    return monitor.tail(n.clamp(1, 100));
  }

  /// The learner presses "start" on the app's own serial monitor. Returns a one-line status for the UI.
  Future<String> startMonitor() async {
    final ports = (await serialPorts()).where((p) => p.driverOk && p.port.isNotEmpty).toList();
    if (ports.isEmpty) return 'No USB board found. Plug it in (and check the cable and driver).';
    final baud = monitorSpeedFromIni(_iniText());
    monitor.start(ports.first.port, baud);
    _note('serial monitor started on ${ports.first.port} at $baud baud');
    return 'Monitoring ${ports.first.port} at $baud baud';
  }

  // ── mqtt ──
  Future<List<String>> mqttMessages(String topic, double seconds) async {
    if (!mqtt.configured) {
      throw const NotAllowed('No MQTT broker is set up in this app yet (Settings > MQTT).');
    }
    final s = seconds.clamp(1.0, 15.0);
    return mqttProbe(mqtt, topic, Duration(milliseconds: (s * 1000).round()));
  }
}
