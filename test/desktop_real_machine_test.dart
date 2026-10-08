// Runs the real connectors against THIS computer. Opt-in: it starts real
// processes (VS Code, PlatformIO) and, if a board is plugged in, reads its port.
//
//   $env:DESKTOP_REAL = "1"; flutter test test/desktop_real_machine_test.dart
//   $env:DESKTOP_PROJECT = "C:\path\to\a\platformio\project"   # optional: also builds it

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/connectors.dart';

void main() {
  final enabled = Platform.environment['DESKTOP_REAL'] == '1';
  final project = Platform.environment['DESKTOP_PROJECT'];

  LocalMachine machine() => LocalMachine(
        runner: RealProcessRunner(),
        monitor: SerialMonitor(() => PioSerialSource(pioPythonCandidates().first)),
        mqttProbe: (s, t, d) async => [],
        approve: (t, d) async => true,
        projectDir: project,
        grants: {...allConnectors},
      );

  test('this computer: installed tools are detected', () async {
    final m = machine();
    final vscode = await m.softwareVersion('vscode');
    final ide = await m.softwareVersion('platformio-ide');
    final cli = await m.softwareVersion('platformio-cli');
    // ignore: avoid_print
    print('vscode=$vscode  platformio-ide=$ide  platformio-cli=$cli');
    expect(vscode, isNotNull);
    expect(cli, isNotNull);
    expect(vscode, matches(RegExp(r'^\d+\.\d+')));
    expect(cli, matches(RegExp(r'^\d+\.\d+')));
  }, skip: enabled ? false : 'set DESKTOP_REAL=1');

  test('this computer: only USB serial devices are reported (built-in COM ports are not a board)', () async {
    final ports = await machine().serialPorts();
    // ignore: avoid_print
    print('usb ports: ${ports.map((p) => p.toJson())}');
    for (final p in ports) {
      expect(p.vidPid, isNotEmpty, reason: '${p.description} is not a USB device');
    }
  }, skip: enabled ? false : 'set DESKTOP_REAL=1');

  test('this computer: the whole handle() path answers instead of throwing', () async {
    final m = machine();
    for (final op in ['os_info', 'serial_ports']) {
      final r = await m.handle(op, {});
      expect(r.containsKey('result') || r.containsKey('error'), isTrue, reason: op);
    }
    expect((await m.handle('list_files', {}))['error'], contains('project folder'));
  }, skip: enabled ? false : 'set DESKTOP_REAL=1');

  test('this computer: a real PlatformIO project builds and its files are listed', () async {
    final m = machine();
    final files = m.listFiles();
    // ignore: avoid_print
    print('files: $files');
    expect(files, contains('platformio.ini'));
    final r = (await m.handle('run_build', {}))['result'] as Map;
    // ignore: avoid_print
    print('build ok=${r['ok']}\n${(r['output'] as String).split('\n').take(6).join('\n')}');
    expect(r.containsKey('ok'), isTrue);
  }, skip: enabled && project != null ? false : 'set DESKTOP_REAL=1 and DESKTOP_PROJECT', timeout: const Timeout(Duration(minutes: 12)));
}
