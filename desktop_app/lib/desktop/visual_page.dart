// A picture the lab assistant drew, as a page the learner can open in their browser.
//
// The server already cleaned the picture (no script, no links, no external resources). The page also forbids
// scripts and network access, so a picture can only ever look like something.

import 'dart:io';

/// The HTML page for a picture. [title] is escaped; [body] is trusted to be cleaned already.
String visualPage(String title, String body) {
  final safe = title.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
  return '''<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:;">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: Segoe UI, Arial, sans-serif; background: #f4f6fb; color: #212121; padding: 24px; line-height: 1.5; }
  .card { background: #fff; border-radius: 12px; padding: 18px; max-width: 980px; margin: auto; box-shadow: 0 1px 4px rgba(0,0,0,.12); }
  h2 { color: #1a237e; max-width: 980px; margin: 0 auto 12px; }
  svg { max-width: 100%; height: auto; } table { border-collapse: collapse; } td, th { border: 1px solid #ccc; padding: 4px 8px; }
</style></head><body><h2>$safe</h2><div class="card">$body</div></body></html>''';
}

/// The picture of a `wiring_diagram` or `visual` interactive: its HTML body.
String pictureBody(Map<String, dynamic> props) => '${props['svg'] ?? props['html'] ?? ''}';

/// Writes the page to a temporary file and opens it in the default browser. Returns false if there is nothing to show
/// or it could not be opened.
Future<bool> openPicture(Map<String, dynamic> props) async {
  final body = pictureBody(props);
  if (body.isEmpty) return false;
  try {
    final dir = await Directory.systemTemp.createTemp('altrobyte_picture_');
    final file = File('${dir.path}${Platform.pathSeparator}picture.html');
    await file.writeAsString(visualPage('${props['title'] ?? 'Picture'}', body));
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else {
      await Process.run('xdg-open', [file.path]);
    }
    return true;
  } catch (_) {
    return false;
  }
}
