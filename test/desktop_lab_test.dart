// The lab assistant's hands on the learner's computer: a starter file and the editor, plus the picture page.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/connectors.dart';
import 'package:altrobytelab/desktop/visual_page.dart';

class _Runner implements ProcessRunner {
  final List<List<String>> calls = [];
  @override
  Future<ProcResult> run(String exe, List<String> args,
      {String? cwd, Duration timeout = const Duration(minutes: 2), bool shell = false}) async {
    calls.add([exe, ...args]);
    return const ProcResult(0, 'ok', '');
  }
}

class _NoSerial implements SerialSource {
  @override
  Stream<String> open(String port, int baud) => const Stream.empty();
  @override
  Future<void> close() async {}
}

const starter = '#include <Arduino.h>\nvoid setup() {\n  // TODO 1: start serial\n}\nvoid loop() {\n  // TODO 2: read\n}\n';

LocalMachine machine(Directory dir, {Approve? approve, _Runner? runner, Set<String>? grants}) => LocalMachine(
      runner: runner ?? _Runner(),
      monitor: SerialMonitor(() => _NoSerial()),
      mqttProbe: (s, t, d) async => [],
      approve: approve ?? (t, d) async => true,
      projectDir: dir.path,
      grants: grants ?? {...allConnectors},
    );

Directory project() {
  final d = Directory.systemTemp.createTempSync('lab_proj_');
  Directory('${d.path}/src').createSync();
  File('${d.path}/src/main.cpp').writeAsStringSync('void setup(){}\nvoid loop(){}\n');
  return d;
}

void main() {
  test('a starter file is written only after the learner agrees', () async {
    final asked = <String>[];
    final dir = project();
    final m = machine(dir, approve: (t, d) async {
      asked.add('$t|$d');
      return true;
    });
    final r = await m.run('create_file', {'path': 'src/new.cpp', 'content': starter}) as Map;
    expect(r['ok'], true);
    expect(File('${dir.path}/src/new.cpp').readAsStringSync(), starter);
    expect(asked.single, contains('Add a starter file'));
    expect(asked.single, contains('TODO 1'));

    final declined = machine(project(), approve: (t, d) async => false);
    await expectLater(declined.run('create_file', {'path': 'src/other.cpp', 'content': starter}), throwsA(isA<UserDeclined>()));
  });

  test('an existing file is kept as a backup and never lost', () async {
    final dir = project();
    final m = machine(dir);
    final original = File('${dir.path}/src/main.cpp').readAsStringSync();
    final refused = await m.run('create_file', {'path': 'src/main.cpp', 'content': starter}) as Map;
    expect(refused['ok'], false);
    expect(File('${dir.path}/src/main.cpp').readAsStringSync(), original);
    final r = await m.run('create_file', {'path': 'src/main.cpp', 'content': starter, 'overwrite': true}) as Map;
    expect(r['backup'], 'src/main.cpp.bak');
    expect(File('${dir.path}/src/main.cpp').readAsStringSync(), starter);
    expect(File('${dir.path}/src/main.cpp.bak').readAsStringSync(), original);
    final r2 = await m.run('create_file', {'path': 'src/main.cpp', 'content': '$starter// again\n', 'overwrite': true}) as Map;
    expect(r2['backup'], 'src/main.cpp.bak2');
  });

  test('a starter file can only be a source file inside src', () async {
    final m = machine(project());
    for (final p in ['main.cpp', '../escape.cpp', 'src/../../escape.cpp', '/etc/x.cpp', 'C:/x.cpp', 'src/run.exe', 'lib/x.cpp', 'platformio.ini']) {
      await expectLater(m.run('create_file', {'path': p, 'content': starter}), throwsA(isA<NotAllowed>()), reason: p);
    }
  });

  test('file creation needs the project files connector', () async {
    final m = machine(project(), grants: {connectorSystem});
    await expectLater(m.run('create_file', {'path': 'src/a.cpp', 'content': starter}), throwsA(isA<NotAllowed>()));
  });

  test('opening a file asks VS Code itself, with the line, and never leaves the project', () async {
    final runner = _Runner();
    final dir = project();
    final m = machine(dir, runner: runner);
    final r = await m.run('open_in_editor', {'path': 'src/main.cpp', 'line': 3}) as Map;
    expect(r['ok'], true);
    expect(runner.calls.last.contains('-g'), true);
    expect(runner.calls.last.last, endsWith('main.cpp:3'));
    expect(((await m.run('open_in_editor', {'path': 'src/missing.cpp'})) as Map)['ok'], false);
    for (final bad in ['../x.cpp', '/etc/passwd', 'C:/Windows/win.ini']) {
      await expectLater(m.run('open_in_editor', {'path': bad}), throwsA(isA<NotAllowed>()), reason: bad);
    }
  });

  test('the picture page allows no script and no network and escapes its title', () {
    final page = visualPage('<b>x</b>', '<svg></svg>');
    expect(page, contains("default-src 'none'"));
    expect(page, isNot(contains('script-src')));
    expect(page, contains('&lt;b>x&lt;/b>'));
    expect(page, contains('<svg></svg>'));
    expect(pictureBody({'svg': '<svg/>'}), '<svg/>');
    expect(pictureBody({'html': '<p>hi</p>'}), '<p>hi</p>');
    expect(pictureBody({}), '');
  });
}
