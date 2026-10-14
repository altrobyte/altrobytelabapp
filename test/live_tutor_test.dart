import 'package:altrobytelab/desktop/live_tutor_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_windows/webview_windows.dart';

void main() {
  test('the sign-in rides in the #fragment, which no server receives, and the topic in the query', () {
    final url = liveTutorUrl(noteId: 31, token: 'abc.def/ghi');
    final uri = Uri.parse(url);
    expect(uri.origin, 'https://altrobytelab.com');
    expect(uri.path, '/live/');
    expect(uri.queryParameters, {'embed': '1', 'note': '31'});
    expect(Uri.decodeComponent(uri.fragment.substring(2)), 'abc.def/ghi');
    expect(liveTutorUrl(labId: 4).contains('#'), isFalse);
    expect(Uri.parse(liveTutorUrl(moduleId: 9)).queryParameters['module'], '9');
  });

  test('only our own site may use the camera and the microphone', () {
    expect(livePermission('https://altrobytelab.com/live/?embed=1', WebviewPermissionKind.camera), WebviewPermissionDecision.allow);
    expect(livePermission('https://altrobytelab.com/live/', WebviewPermissionKind.microphone), WebviewPermissionDecision.allow);
    expect(livePermission('https://altrobytelab.com/live/', WebviewPermissionKind.geoLocation), WebviewPermissionDecision.deny);
    expect(livePermission('https://evil.example/live/', WebviewPermissionKind.camera), WebviewPermissionDecision.deny);
    expect(livePermission('https://altrobytelab.com.evil.example/', WebviewPermissionKind.camera), WebviewPermissionDecision.deny);
  });
}
