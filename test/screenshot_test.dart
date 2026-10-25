import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/screen_shot.dart';

void main() {
  test('a picture of the screen comes back as a JPEG', () async {
    final b64 = await screenshotJpegBase64();
    expect(b64, isNotNull);
    final bytes = base64Decode(b64!);
    expect(bytes.sublist(0, 2), [0xFF, 0xD8]);              // a JPEG starts with FF D8
    expect(bytes.length, lessThan(600 * 1024));              // small enough to send into the talk
  }, skip: !Platform.isWindows);
}
