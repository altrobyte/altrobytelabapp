// The learner-side connectors: parsing, permissions, path safety, approvals,
// the port hand-off around an upload, and the request/result loop.
// No hardware needed: processes, serial and MQTT are faked behind interfaces.

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/connectors.dart';
import 'package:altrobytelab/desktop/live_client.dart';

// ── fakes ────────────────────────────────────────────────────────────────────

class FakeRunner implements ProcessRunner {
  final List<List<String>> calls = [];
  final ProcResult Function(String exe, List<String> args) answer;
  FakeRunner(this.answer);
  @override
  Future<ProcResult> run(String exe, List<String> args,
      {String? cwd, Duration timeout = const Duration(minutes: 2), bool shell = false}) async {
    calls.add([exe, ...args]);
    return answer(exe, args);
  }
}

class FakeSerial implements SerialSource {
  // Broadcast: the same fake is re-opened after an upload, as a real source would be.
  final StreamController<String> ctl = StreamController.broadcast();
  String? openedPort;
  int? openedBaud;
  bool closed = false;
  @override
  Stream<String> open(String port, int baud) {
    openedPort = port;
    openedBaud = baud;
    return ctl.stream;
  }

  @override
  Future<void> close() async => closed = true;
}

const piolist = '[{"port":"COM3","description":"Intel SOL (COM3)","hwid":"PCI\\\\VEN_8086&DEV_9D3D"},'
    '{"port":"COM5","description":"Silicon Labs CP210x (COM5)","hwid":"USB VID:PID=10C4:EA60 SER=0001"}]';

ProcResult pioOk(String exe, List<String> args) {
  if (args.contains('--version')) return const ProcResult(0, 'PlatformIO Core, version 6.1.16\n', '');
  if (args.contains('device')) return const ProcResult(0, 'warning noise\n$piolist', '');
  if (args.contains('upload')) return const ProcResult(0, 'Writing at 0x10000... SUCCESS', '');
  if (args.first == 'run') return const ProcResult(0, 'Linking... [SUCCESS]', '');
  return const ProcResult(1, '', 'unknown');
}

Directory project() {
  final d = Directory.systemTemp.createTempSync('trainer_proj_');
  File('${d.path}/platformio.ini').writeAsStringSync('[env:esp32dev]\nboard = esp32dev\nmonitor_speed = 115200\n');
  Directory('${d.path}/src').createSync();
  File('${d.path}/src/main.cpp').writeAsStringSync('void setup(){}\nvoid loop(){}\n');
  Directory('${d.path}/.pio/build').createSync(recursive: true);
  File('${d.path}/.pio/build/firmware.elf').writeAsStringSync('binary');
  File('${d.path}/notes.exe').writeAsStringSync('not text');
  return d;
}

LocalMachine machine({FakeRunner? runner, FakeSerial? serial, Directory? dir, Set<String>? grants, Approve? approve,
    MqttSettings? mqtt, MqttProbe? probe}) {
  final fs = serial ?? FakeSerial();
  return LocalMachine(
    runner: runner ?? FakeRunner(pioOk),
    monitor: SerialMonitor(() => fs),
    mqttProbe: probe ?? (s, t, d) async => ['{"temp_c": 27.4}'],
    approve: approve ?? (t, d) async => true,
    projectDir: dir?.path,
    grants: grants ?? {...allConnectors},
    mqtt: mqtt,
  );
}

void main() {
  group('parsing', () {
    test('monitor speed defaults to 9600 like PlatformIO, and reads the ini otherwise', () {
      expect(monitorSpeedFromIni('[env:a]\nboard = x\n'), 9600);
      expect(monitorSpeedFromIni('[env:a]\n monitor_speed = 115200\n'), 115200);
    });

    test('only USB serial devices count as a board; built-in ports are ignored', () {
      final ports = parsePioDeviceList('some warning\n$piolist');
      expect(ports.length, 1);
      expect(ports.single.port, 'COM5');
      expect(ports.single.vidPid, '10C4:EA60');
      expect(parsePioDeviceList('[]'), isEmpty);
      expect(parsePioDeviceList('garbage'), isEmpty);
      expect(parsePioDeviceList('[1, "x", null]'), isEmpty);
    });

    test('a board plugged in without a driver is reported as such', () {
      final one = parseDriverlessDevices('{"FriendlyName":"CP2102 USB to UART","InstanceId":"USB\\\\VID_10C4&PID_EA60\\\\0001"}');
      expect(one.single.driverOk, isFalse);
      expect(one.single.vidPid, '10C4:EA60');
      expect(parseDriverlessDevices(''), isEmpty);
      expect(parseDriverlessDevices('[]'), isEmpty);
      expect(parseDriverlessDevices('not json'), isEmpty);
    });

    test('compiler diagnostics keep the learner\'s files and drop system headers', () {
      final d = parseDiagnostics(
          "src/main.cpp:12:5: error: 'TEMP_PIN' was not declared in this scope\n"
          'src\\other.cpp:3: warning: unused variable\n'
          'C:/Users/x/.platformio/packages/framework/Arduino.h:9:1: error: noisy\n'
          'Linking...\n');
      expect(d.length, 2);
      expect(d.first.path, 'src/main.cpp');
      expect(d.first.line, 12);
      expect(d.first.severity, 'error');
      expect(d.first.message, contains('TEMP_PIN'));
      expect(d.last.path, 'src/other.cpp');
      expect(d.last.severity, 'warning');
    });
  });

  group('permissions', () {
    test('a connector the learner has not allowed is refused and logged', () async {
      final m = machine(grants: {connectorSystem});
      final r = await m.handle('read_file', {'path': 'platformio.ini'});
      expect(r['error'], contains('workspace'));
      expect(m.log.last, contains('REFUSED  read_file'));
      expect((await m.handle('os_info', {}))['result'], isA<Map>());
    });

    test('operations outside the closed list are refused', () async {
      final m = machine();
      expect((await m.handle('run_shell', {'cmd': 'del *'}))['error'], contains('unknown operation'));
      expect((await m.handle('write_file', {}))['error'], contains('unknown operation'));
    });

    test('only known tools are ever probed by name', () async {
      final runner = FakeRunner(pioOk);
      final m = machine(runner: runner);
      expect(await m.softwareVersion('rm -rf'), isNull);
      expect(await m.softwareVersion('python'), isNull);
      expect(runner.calls, isEmpty);
    });

    test('every operation the server can ask for belongs to a connector', () {
      expect(connectorOfOp.keys.toSet(), {
        'os_info', 'software_version', 'serial_ports', 'list_files', 'read_file', 'diagnostics', 'run_build',
        'run_upload', 'serial_tail', 'mqtt_messages'
      });
      expect(connectorOfOp.values.toSet().difference(allConnectors.toSet()), isEmpty);
    });
  });

  group('the project folder', () {
    test('lists project text files, skipping build output and other file types', () {
      final m = machine(dir: project());
      expect(m.listFiles(), ['platformio.ini', 'src/main.cpp']);
    });

    test('reads files inside the folder, and nothing outside it', () {
      final dir = project();
      final m = machine(dir: dir);
      expect(m.readFile('platformio.ini'), contains('esp32dev'));
      expect(m.readFile('src/main.cpp'), contains('setup'));
      expect(m.readFile('nope.txt'), isNull);
      for (final bad in ['../secret.txt', '/etc/passwd', r'C:\Windows\win.ini', r'src\..\..\x', '', 'a/../../b']) {
        expect(() => m.readFile(bad), throwsA(isA<NotAllowed>()), reason: bad);
      }
    });

    test('a file that is a link out of the folder cannot be used to escape', () {
      final dir = project();
      final outside = File('${Directory.systemTemp.path}/trainer_outside_secret.txt')..writeAsStringSync('secret');
      try {
        Link('${dir.path}/escape.txt').createSync(outside.path);
      } catch (_) {
        return; // creating links needs a privilege on some Windows setups; the check is covered where possible
      }
      expect(() => machine(dir: dir).readFile('escape.txt'), throwsA(isA<NotAllowed>()));
    });

    test('nothing can be read before a folder is chosen', () async {
      final r = await machine().handle('list_files', {});
      expect(r['error'], contains('project folder'));
    });

    test('large files are not dumped', () {
      final dir = project();
      File('${dir.path}/big.txt').writeAsStringSync('x' * (LocalMachine.maxFileBytes + 10));
      expect(machine(dir: dir).readFile('big.txt'), contains('too large'));
    });
  });

  group('build, upload and the serial port', () {
    test('a build asks first, and a "no" is final', () async {
      final runner = FakeRunner(pioOk);
      var asked = '';
      final m = machine(runner: runner, dir: project(), approve: (t, d) async {
        asked = '$t | $d';
        return false;
      });
      final r = await m.handle('run_build', {});
      expect(r['error'], 'user_declined');
      expect(asked, contains('pio run'));
      expect(runner.calls.where((c) => c.contains('run')), isEmpty);
      expect(m.log.any((l) => l.contains('DECLINED  run_build')), isTrue);
    });

    test('an approved build runs in the project folder and its errors become diagnostics', () async {
      final runner = FakeRunner((exe, args) => args.first == 'run'
          ? const ProcResult(1, "src/main.cpp:4:5: error: 'TEMP_PIN' was not declared in this scope\n", '')
          : pioOk(exe, args));
      final dir = project();
      final m = machine(runner: runner, dir: dir);
      final r = (await m.handle('run_build', {}))['result'] as Map;
      expect(r['ok'], isFalse);
      expect(r['output'], contains('TEMP_PIN'));
      expect(runner.calls.last, containsAll(['run', '-d', dir.path]));
      final d = (await m.handle('diagnostics', {}))['result'] as List;
      expect(d.single['line'], 4);
    });

    test('an upload names the port in its approval and frees the port while it runs, then takes it back', () async {
      final serial = FakeSerial();
      var detail = '';
      final runner = FakeRunner(pioOk);
      final m = machine(runner: runner, serial: serial, dir: project(), approve: (t, d) async {
        detail = d;
        return true;
      });
      m.monitor.start('COM5', 115200);
      expect(m.monitor.running, isTrue);
      serial.closed = false;
      final r = (await m.handle('run_upload', {}))['result'] as Map;
      expect(r['ok'], isTrue);
      expect(r['port'], 'COM5');
      expect(detail, contains('COM5'));
      expect(runner.calls.last, containsAll(['-t', 'upload', '--upload-port', 'COM5']));
      expect(serial.closed, isTrue, reason: 'the monitor must release the port for the upload');
      expect(m.monitor.running, isTrue, reason: 'and take it back afterwards');
      expect(serial.openedBaud, 115200);
    });

    test('serial output is read with the speed from platformio.ini (so a mismatch shows as garbage, as for the learner)', () async {
      final serial = FakeSerial();
      final m = machine(serial: serial, dir: project());
      final fut = m.handle('serial_tail', {'n': 5});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      serial.ctl.add('Temperature: 27.1 C');
      serial.ctl.add('Temperature: 27.2 C');
      final r = (await fut)['result'] as List;
      expect(serial.openedPort, 'COM5');
      expect(serial.openedBaud, 115200);
      expect(r, ['Temperature: 27.1 C', 'Temperature: 27.2 C']);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('no board plugged in is said plainly', () async {
      final m = machine(runner: FakeRunner((e, a) => a.contains('device') ? const ProcResult(0, '[]', '') : pioOk(e, a)));
      final r = (await m.handle('serial_tail', {}))['result'] as List;
      expect(r.single, contains('no USB serial device'));
    });

    test('the monitor keeps a bounded history', () async {
      final s = FakeSerial();
      final mon = SerialMonitor(() => s)..start('COM5', 9600);
      for (var i = 0; i < SerialMonitor.maxLines + 50; i++) {
        s.ctl.add('line $i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(mon.lines.length, SerialMonitor.maxLines);
      expect(mon.tail(2), ['line ${SerialMonitor.maxLines + 48}', 'line ${SerialMonitor.maxLines + 49}']);
      await mon.stop();
      expect(mon.running, isFalse);
    });
  });

  group('system and mqtt', () {
    test('software versions are read from the right commands', () async {
      final runner = FakeRunner((exe, args) {
        if (exe.contains('code')) {
          return args.contains('--version')
              ? const ProcResult(0, '1.95.0\nabc123\nx64\n', '')
              : const ProcResult(0, 'ms-python.python@2024.1\nplatformio.platformio-ide@3.3.4\n', '');
        }
        return pioOk(exe, args);
      });
      final m = machine(runner: runner);
      expect(await m.softwareVersion('vscode'), '1.95.0');
      expect(await m.softwareVersion('platformio-ide'), '3.3.4');
      expect(await m.softwareVersion('platformio-cli'), '6.1.16');
    });

    test('a missing tool is reported as not installed, not as an error', () async {
      final m = machine(runner: FakeRunner((e, a) => throw const ProcessException('x', [], 'not found')));
      expect(await m.softwareVersion('vscode'), isNull);
      expect(await m.softwareVersion('platformio-cli'), isNull);
    });

    test('mqtt needs a broker to be set up, then listens on the topic', () async {
      expect((await machine().handle('mqtt_messages', {'topic': 't'}))['error'], contains('MQTT'));
      String? seenTopic;
      Duration? seenFor;
      final m = machine(mqtt: MqttSettings(host: 'broker.example.com'), probe: (s, t, d) async {
        seenTopic = t;
        seenFor = d;
        return ['{"temp_c": 27.4}'];
      });
      final r = (await m.handle('mqtt_messages', {'topic': 'org/me/dev1/temp', 'seconds': 99}))['result'] as List;
      expect(r, ['{"temp_c": 27.4}']);
      expect(seenTopic, 'org/me/dev1/temp');
      expect(seenFor, const Duration(seconds: 15), reason: 'the listen time is capped');
    });

    test('a failing connector answers with an error and never throws', () async {
      final m = machine(probe: (s, t, d) async => throw const SocketException('network down'),
          mqtt: MqttSettings(host: 'h'));
      final r = await m.handle('mqtt_messages', {'topic': 't'});
      expect(r['error'], contains('Could not do that'));
    });
  });

  group('the request/result loop', () {
    test('the app runs what the server asks, posts each answer, and returns the finished turn', () async {
      final api = _FakeApi([
        {
          'status': 'env_request',
          'requests': [
            {'id': 'r1', 'op': 'read_file', 'args': {'path': 'platformio.ini'}}
          ],
          'state': _state(),
        },
        {
          'status': 'env_request',
          'requests': [
            {'id': 'r2', 'op': 'serial_ports', 'args': {}}
          ],
        },
        {'status': 'working'},
        {'status': 'done', 'messages': ['I can see your board on COM5.'], 'ui': [], 'waiting': false, 'finished': false, 'state': _state()},
      ]);
      final m = machine(dir: project());
      final c = LiveTrainerClient(api, m);
      final seen = <String>[];
      c.onActivity = seen.add;
      final turn = await c.start();
      expect(turn.messages, ['I can see your board on COM5.']);
      expect(api.posted.length, 2);
      expect(api.posted[0]['id'], 'r1');
      expect((api.posted[0]['result'] as String), contains('esp32dev'));
      expect(api.posted[1]['id'], 'r2');
      expect((api.posted[1]['result'] as List).single['port'], 'COM5');
      expect(api.polls, 1);
      expect(seen, containsAll(['reading platformio.ini', 'looking for your board on USB']));
      expect(c.sessionId, 'sid');
    });

    test('a refusal is posted as an error the trainer can act on, not swallowed', () async {
      final api = _FakeApi([
        {'status': 'env_request', 'requests': [{'id': 'r1', 'op': 'run_build', 'args': {}}]},
        {'status': 'done', 'messages': ['No problem.'], 'ui': [], 'state': _state()},
      ]);
      final m = machine(dir: project(), approve: (t, d) async => false);
      await LiveTrainerClient(api, m).start();
      expect(api.posted.single, {'id': 'r1', 'error': 'user_declined'});
    });

    test('changing what the trainer may see is sent to the server', () async {
      final api = _FakeApi([{'status': 'done', 'messages': ['hi'], 'ui': [], 'state': _state()}]);
      final m = machine(grants: {connectorSystem});
      final c = LiveTrainerClient(api, m);
      await c.start();
      m.grants.add(connectorWorkspace);
      await c.setGrants();
      expect(api.grants.last.toSet(), {connectorSystem, connectorWorkspace});
    });
  });
}

Map<String, dynamic> _state() => {
      'mission': 'm',
      'scenario': 'live',
      'stages': [],
      'progress': [],
      'sim': null,
      'live': true,
      'grants': [],
    };

class _FakeApi implements TrainerApi {
  final List<Map<String, dynamic>> script;
  final List<Map<String, dynamic>> posted = [];
  final List<List<String>> grants = [];
  int polls = 0;
  _FakeApi(this.script);

  Map<String, dynamic> _next() => script.removeAt(0);

  @override
  Future<Map<String, dynamic>> start(List<String> g) async {
    grants.add(g);
    return {'id': 'sid', ..._next()};
  }

  @override
  Future<Map<String, dynamic>> send(String id, String text) async => _next();
  @override
  Future<Map<String, dynamic>> envResult(String id, Map<String, dynamic> body) async {
    posted.add(body);
    return _next();
  }

  @override
  Future<Map<String, dynamic>> poll(String id) async {
    polls++;
    return _next();
  }

  @override
  Future<void> setGrants(String id, List<String> c) async => grants.add(c);
  @override
  Future<void> end(String id) async {}
}
