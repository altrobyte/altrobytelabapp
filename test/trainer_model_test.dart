// Parses JSON captured from the real backend (test/fixtures/trainer_*.json, from
// trainer_api.py driven through its TestClient), so a renamed field on either
// side fails here instead of showing as a blank panel in the console.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/models/trainer_model.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('a started session: id, opening message, milestones and the sandbox machine', () {
    final t = TrainerTurn.fromJson(fixture('trainer_start'));
    expect(t.sessionId, hasLength(32));
    expect(t.messages.single, contains('ESP32'));
    final s = t.state;
    expect(s.scenario, 'baud_mismatch');
    expect(s.stages.map((x) => x['id']), ['read', 'publish']);
    expect(s.progress.length, 12);
    final board = s.progress.firstWhere((m) => m.id == 'board_connected');
    expect(board.done, isTrue);
    expect(board.kind, 'verified');
    expect(board.evidence, contains('COM5'));
    // The trainer verified toolchain + board only: project_setup is now unblocked but unproven,
    // and the build waits on it.
    final project = s.progress.firstWhere((m) => m.id == 'project_setup');
    expect(project.status, 'pending');
    final build = s.progress.firstWhere((m) => m.id == 'code_builds');
    expect(build.status, 'blocked');
    expect(build.waitingFor, ['project_setup']);
    final upload = s.progress.firstWhere((m) => m.id == 'firmware_uploaded');
    expect(upload.status, 'blocked');
    expect(upload.waitingFor, contains('code_builds'));
    expect(s.progress.firstWhere((m) => m.id == 'sensor_wired').physical, isTrue);
    expect(s.hints, {'baud_mismatch': 1});
    expect(s.sim.files.keys, containsAll(['platformio.ini', 'src/main.cpp']));
    expect(s.sim.flashed, isTrue);
    expect(s.sim.boardConnected && s.sim.driverOk, isTrue);
    expect(s.sim.wiring, 'ok');
    expect(s.doneCount, 2);
  });

  test('what the trainer did is readable, with failures and hints distinguishable', () {
    final s = TrainerState.fromJson(Map<String, dynamic>.from(fixture('trainer_start')['state']));
    final kinds = s.activity.map((a) => a.kind).toSet();
    expect(kinds, containsAll(['tool', 'hint', 'milestone_done']));
    expect(s.activity.any((a) => a.label.startsWith('verify_milestone')), isTrue);
    expect(s.activity.any((a) => a.label.contains("hint 'baud_mismatch': level 1")), isTrue);
  });

  test('a follow-up message and a sandbox action both return a full state', () {
    final m = TrainerTurn.fromJson(fixture('trainer_message'));
    expect(m.sessionId, isNull);
    expect(m.messages.single, contains('Serial.begin'));
    expect(m.state.progress.length, 12);

    final sim = fixture('trainer_sim');
    expect(sim['output'], contains('SUCCESS'));
    final st = TrainerState.fromJson(Map<String, dynamic>.from(sim['state']));
    expect(st.sim.flashed, isTrue);
  });

  test('missions list gives each practice machine a label, description and opening line', () {
    final j = fixture('trainer_missions');
    final scenarios = [
      for (final s in (j['missions'] as List).first['scenarios'] as List)
        TrainerScenario.fromJson(Map<String, dynamic>.from(s))
    ];
    expect(scenarios.map((s) => s.name), containsAll(['fresh_start', 'bare_pc', 'baud_mismatch', 'adc2_with_wifi']));
    final baud = scenarios.firstWhere((s) => s.name == 'baud_mismatch');
    expect(baud.label, 'Baud mismatch');
    expect(baud.description, isNotEmpty);
    expect(baud.opening, contains('weird characters'));
  });

  test('empty or partial JSON never throws', () {
    final s = TrainerState.fromJson({'mission': 'x', 'scenario': 'y'});
    expect(s.progress, isEmpty);
    expect(s.sim.boardConnected, isTrue);
  });
}
