import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/screens/connect/download_app_screen.dart';

void main() {
  test('the download page offers only an installer file published next to it', () {
    final r = DesktopRelease.parse('{"version":"1.2.0","file":"AltrobyteTrainerSetup.exe","size":26000000}')!;
    expect((r.version, r.file, r.megabytes), ('1.2.0', 'AltrobyteTrainerSetup.exe', '26'));
    expect(DesktopRelease.parse('{"version":"1","file":"../evil.exe"}'), isNull);
    expect(DesktopRelease.parse('{"version":"1","file":"https://x.com/a.exe"}'), isNull);
    expect(DesktopRelease.parse('{"version":"1","file":"setup.zip"}'), isNull);
    expect(DesktopRelease.parse('not json'), isNull);
    expect(DesktopRelease.parse('{"file":"a.exe"}'), isNull);
  });
}
