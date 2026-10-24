import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/live_course.dart';

void main() {
  test('crashes, resets and errors on the serial monitor are noticed; ordinary prints are not', () {
    for (final l in ["Guru Meditation Error: Core 1 panic'ed (LoadProhibited)", 'Brownout detector was triggered',
                     'rst:0xc (SW_CPU_RESET),boot:0x13', 'E (1234) wifi: connect failed', 'Task watchdog got triggered']) {
      expect(serialTrouble.hasMatch(l), isTrue, reason: l);
    }
    for (final l in ['LED on', 'Temperature: 24.5 C', 'Connecting to WiFi...']) {
      expect(serialTrouble.hasMatch(l), isFalse, reason: l);
    }
  });
}
