import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/models/trainer_model.dart';

void main() {
  test('a real course state from the server is readable by the app', () {
    final j = jsonDecode(File('test/fixtures_course_state.json').readAsStringSync()) as Map<String, dynamic>;
    final st = TrainerState.fromJson(j);
    expect(st.mission, 'course_intro_first_program');
    expect(st.progress.length, 12);
    expect(st.doneCount, 1);
  });
}
