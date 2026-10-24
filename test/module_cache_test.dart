import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/module_cache.dart';

void main() {
  test('what is kept comes back for the same account and never for another', () {
    final tmp = Directory.systemTemp.createTempSync('altro-cache');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final a = ModuleCache('student-1', env: {'APPDATA': tmp.path});
    expect(a.read('modules'), isNull);
    a.write('modules', [
      {'id': 3, 'title': 'ESP32'}
    ]);
    expect(ModuleCache('student-1', env: {'APPDATA': tmp.path}).read('modules'), [
      {'id': 3, 'title': 'ESP32'}
    ]);
    expect(ModuleCache('student-2', env: {'APPDATA': tmp.path}).read('modules'), isNull);
  });
}
