import 'package:altrobytelab/screens/tools/ble_tester_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard UUIDs read as names, the rest stay as they are', () {
    expect(bleLabel('00002A19-0000-1000-8000-00805F9B34FB'), 'Battery Level');
    expect(bleLabel('0000180f-0000-1000-8000-00805f9b34fb'), 'Battery');
    expect(bleLabel('00002bff-0000-1000-8000-00805f9b34fb'), '0x2BFF');
    expect(bleLabel('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'), 'UART TX (notifies)');
    expect(bleLabel('12345678-1234-1234-1234-123456789abc'), '12345678-1234-1234-1234-123456789abc');
  });

  test('bytes show as text when printable, always with the hex', () {
    expect(bleShow([]), '(empty)');
    expect(bleShow('ON'.codeUnits), '"ON"  ·  4F 4E');
    expect(bleShow([0x00, 0xFF, 0x10]), '00 FF 10');
    expect(bleShow([0x32, 0x35, 0x2E, 0x34, 0x0A]), '"25.4"  ·  32 35 2E 34 0A');
  });

  test('typed values become bytes; bad hex is refused', () {
    expect(bleBytes('ON', hex: false), [0x4F, 0x4E]);
    expect(bleBytes('0A ff 01', hex: true), [0x0A, 0xFF, 0x01]);
    expect(bleBytes('0x0A,0xFF', hex: true), [0x0A, 0xFF]);
    expect(bleBytes('0A:FF-01', hex: true), [0x0A, 0xFF, 0x01]);
    expect(bleBytes('ABC', hex: true), isNull);
    expect(bleBytes('zz', hex: true), isNull);
    expect(bleBytes('', hex: true), isNull);
  });
}
