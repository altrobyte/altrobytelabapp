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
  // The part the tutor is talking about glows, so the learner's eyes land where the voice is: the whole section, not just
  // its heading. When the note puts a section in a box of its own (a card, a <section>), that box glows. When the note is
  // flat (a heading, then paragraphs, then the next heading), every block from the heading to the next one is marked.
  var style = document.createElement('style');
  style.textContent =
    '.altro-now{position:relative;border-radius:12px;outline:2px solid rgba(255,193,7,.9);outline-offset:6px;' +
    'box-shadow:0 0 0 0 rgba(255,193,7,.55);animation:altroGlow 1.6s ease-out 4;transition:outline-color .4s}' +
    '.altro-run{background:rgba(255,193,7,.08);box-shadow:inset 4px 0 0 rgba(255,193,7,.95);transition:background .4s}' +
    '.altro-run.altro-first{animation:altroRun 1.6s ease-out 3}' +
    '@keyframes altroGlow{0%{box-shadow:0 0 0 0 rgba(255,193,7,.55)}70%{box-shadow:0 0 0 18px rgba(255,193,7,0)}100%{box-shadow:0 0 0 0 rgba(255,193,7,0)}}' +
    '@keyframes altroRun{0%{background:rgba(255,193,7,.28)}100%{background:rgba(255,193,7,.08)}}';
  (document.head || document.documentElement).appendChild(style);
  function isHead(n) { return !!(n && n.matches && n.matches('h1,h2,h3')); }
  function holdsHead(n) { return isHead(n) || !!(n && n.querySelector && n.querySelector('h1,h2,h3')); }
  function textOf(n) { return ((n && (n.innerText || n.textContent)) || '').length; }
  function regionOf(h) {
    // The largest box around the heading that holds no other section and is clearly more than the heading itself.
    var box = null, el = h.parentElement;
    for (var up = 0; el && el !== document.body && up < 6; up++, el = el.parentElement) {
      if (el.querySelectorAll('h1,h2,h3').length > 1) break;
      if (textOf(el) > textOf(h) + 40) box = el;
    }
    if (box) return { block: box };
    // Flat: start at the heading (or the small box that holds only it) and take what follows, up to the next section.
    var first = h;
    while (first.parentElement && first.parentElement !== document.body &&
           first.parentElement.querySelectorAll('h1,h2,h3').length === 1 && !first.nextElementSibling) first = first.parentElement;
    var run = [first], n = first.nextElementSibling;
    while (n && !holdsHead(n) && run.length < 60) { run.push(n); n = n.nextElementSibling; }
    return run.length > 1 ? { run: run } : { block: h };
  }
  var lit = [];
  function unlight() {
    for (var k = 0; k < lit.length; k++) lit[k].classList.remove('altro-now', 'altro-run', 'altro-first');
    lit = [];
  }
  window.__altroShow = function (i, bring) {
    collect();
    var h = heads[i];
    if (!h) return;
    unlight();
    var r = regionOf(h);
    if (r.block) {
      void r.block.offsetWidth;                   // restart the pulse when the same block is pointed at again
      r.block.classList.add('altro-now');
      lit = [r.block];
    } else {
      for (var k = 0; k < r.run.length; k++) r.run[k].classList.add('altro-run');
      r.run[0].classList.add('altro-first');
      lit = r.run.slice();
    }
    if (bring) { last = i; h.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
  };
  function start() { collect(); inView(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
</script>
""";

/// The script that makes one section of the note glow ([bring] also scrolls it into view).
String showSectionScript(int index, {bool bring = false}) => 'window.__altroShow && window.__altroShow($index, $bring)';

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
