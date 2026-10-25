import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/local_tools.dart';

void main() {
  test("a lesson project is written once, inside its folder only, and the learner's work is kept", () {
    final home = Directory.systemTemp.createTempSync('altro-proj');
    addTearDown(() => home.deleteSync(recursive: true));
    final env = {'USERPROFILE': home.path};
    final files = [
      {'path': 'platformio.ini', 'content': '[env:esp32dev]'},
      {'path': 'src/main.cpp', 'content': 'void setup(){}'},
      {'path': '../outside.txt', 'content': 'no'},
      {'path': 'C:/Windows/x', 'content': 'no'},
    ];
    final dir = writeLessonProject('led blink/pio', files, env: env);
    expect(dir.endsWith('led_blink_pio'), isTrue);
    expect(File('$dir/src/main.cpp').readAsStringSync(), 'void setup(){}');
    expect(File('${home.path}/Documents/Altrobyte/projects/outside.txt').existsSync(), isFalse);
    File('$dir/src/main.cpp').writeAsStringSync('my own code');
    writeLessonProject('led blink/pio', files, env: env);
    expect(File('$dir/src/main.cpp').readAsStringSync(), 'my own code');
  });
}
