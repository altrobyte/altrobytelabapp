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

/// A lesson page we wrote ourselves: it may run its own small script, but it can reach nothing: no network, no other page,
/// no form. The page is shown as written, so it must be self-contained.
String lessonPage(String html) {
  const csp = '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; script-src \'unsafe-inline\'; img-src data:; form-action \'none\';">';
  final lower = html.toLowerCase();
  final at = lower.indexOf('<head>');
  return at < 0 ? '<!DOCTYPE html><html><head>$csp</head><body>$html</body></html>' : html.replaceRange(at + 6, at + 6, csp);
}

/// What is added to a note shown inside the app: it tells the app which section is in view (its position among the page's
/// headings) and hands links to the app instead of leaving the note. It reads nothing else and sends nothing anywhere else.
const noteBridgeScript = r"""
<script>
(function () {
  function post(m) { try { window.chrome.webview.postMessage(m); } catch (e) {} }
  var heads = [], last = -1;
  function collect() { heads = Array.prototype.slice.call(document.querySelectorAll('h1,h2,h3')); }
  function report(i) { if (i >= 0 && i !== last) { last = i; post({ section: i }); } }
  function inView() {
    var line = window.innerHeight * 0.35, best = -1;
    for (var i = 0; i < heads.length; i++) {
      var r = heads[i].getBoundingClientRect();
      if (r.width === 0 && r.height === 0) continue;
      if (r.top <= line) best = i;
    }
    if (best < 0 && heads.length) best = 0;
    report(best);
  }
  var waiting = false;
  function later() { if (!waiting) { waiting = true; setTimeout(function () { waiting = false; inView(); }, 250); } }
  window.addEventListener('scroll', later, true);
  window.addEventListener('resize', later);
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (a && /^https?:/i.test(a.href)) { e.preventDefault(); post({ open: a.href }); return; }
    // A note built from cards that open: the heading of the card that was clicked is the section being read.
    var el = e.target;
    while (el && el !== document.body) {
      var h = el.matches && el.matches('h1,h2,h3') ? el : (el.querySelector ? el.querySelector(':scope > h1, :scope > h2, :scope > h3, :scope > * > h1, :scope > * > h2, :scope > * > h3') : null);
      if (h) { collect(); report(heads.indexOf(h)); break; }
      el = el.parentElement;
    }
  }, true);
  function start() { collect(); inView(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
</script>
""";

/// A note for the tutor view: the same closed page as [lessonPage], plus the small script that reports where the learner is.
String tutorPage(String html) {
  final page = lessonPage(html);
  final at = page.toLowerCase().lastIndexOf('</body>');
  return at < 0 ? '$page$noteBridgeScript' : page.replaceRange(at, at, noteBridgeScript);
}

/// Opens a lesson page in the default browser. False when there is nothing to show or it could not be opened.
Future<bool> openLessonHtml(String html) async {
  if (html.trim().isEmpty) return false;
  try {
    final dir = await Directory.systemTemp.createTemp('altrobyte_lesson_');
    final file = File('${dir.path}${Platform.pathSeparator}lesson.html');
    await file.writeAsString(lessonPage(html));
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

/// Opens a web address in the default browser. Only http(s) addresses are opened.
Future<bool> openExternal(String url) async {
  final u = Uri.tryParse(url.trim());
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return false;
  try {
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', u.toString()]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [u.toString()]);
    } else {
      await Process.run('xdg-open', [u.toString()]);
    }
    return true;
  } catch (_) {
    return false;
  }
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
