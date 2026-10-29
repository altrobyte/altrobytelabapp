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
    // The page follows Altron, gently (29 Oct 2026, founder: it jumped down suddenly; it must follow the trainer slowly).
    // If the learner scrolled on their own in the last 20 s, nothing moves: a small button offers to go there.
    if (bring) { last = i; if (learnerBusy()) offerGo(h); else { glide(h, 90); } }
  };
  // ── following Altron's words ──
  var userAt = 0, anim = null;
  function learnerBusy() { return Date.now() - userAt < 20000; }
  ['wheel', 'touchstart', 'keydown', 'mousedown'].forEach(function (ev) {
    window.addEventListener(ev, function () { userAt = Date.now(); if (anim) { cancelAnimationFrame(anim); anim = null; } }, { passive: true });
  });
  // A slow eased scroll so the element sits `offset` px from the top: about 500 px a second, never a jump.
  function glide(el, offset) {
    var from = window.scrollY, to = Math.max(0, from + el.getBoundingClientRect().top - offset), d = to - from;
    if (Math.abs(d) < 8) return;
    var ms = Math.min(2600, Math.max(700, Math.abs(d) / 0.5)), t0 = null;
    if (anim) cancelAnimationFrame(anim);
    function step(ts) {
      if (t0 === null) t0 = ts;
      var p = Math.min(1, (ts - t0) / ms), e = p < .5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2;
      window.scrollTo(0, from + d * e);
      anim = p < 1 ? requestAnimationFrame(step) : null;
    }
    anim = requestAnimationFrame(step);
  }
  function wordsOf(s) {
    return (s || '').toLowerCase().replace(/[^a-z0-9ऀ-ॿ]+/g, ' ').split(' ').filter(function (w) { return w.length > 2; });
  }
  var STOP = {the:1,and:1,aur:1,hai:1,hain:1,hum:1,isko:1,iska:1,yeh:1,kya:1,koi:1,jab:1,tab:1,par:1,for:1,you:1,are:1,this:1,that:1,with:1,
              karte:1,kaise:1,dekhenge:1,hota:1,hoti:1,raha:1,rahe:1,abhi:1,bhi:1,toh:1,agar:1,samajh:1,aaya:1,ek:1,mein:1,liye:1};
  var saidAt = 0;
  // Altron's latest words: the line of the lit section they are about is brought into comfortable view, slowly.
  window.__altroSaid = function (text) {
    if (!lit.length || learnerBusy() || anim || Date.now() - saidAt < 2500) return;
    var said = wordsOf(text).slice(-24).filter(function (w) { return !STOP[w]; });
    if (said.length < 2) return;
    var bag = {}; said.forEach(function (w) { bag[w] = 1; });
    var best = null, score = 0;
    lit.forEach(function (b) {
      var parts = b.querySelectorAll('p, li, tr, h2, h3, h4, pre, figure, blockquote, img, canvas, svg, button, input');
      var list = parts.length ? Array.prototype.slice.call(parts) : [b];
      list.forEach(function (el) {
        var n = 0, seen = {};
        wordsOf(el.innerText || el.getAttribute('alt') || '').forEach(function (w) { if (bag[w] && !seen[w]) { seen[w] = 1; n++; } });
        if (n > score) { score = n; best = el; }
      });
    });
    if (!best || score < 2) return;
    var r = best.getBoundingClientRect();
    if (r.top > 70 && r.bottom < window.innerHeight - 70) return;   // already in view: the page stays still
    saidAt = Date.now();
    glide(best, Math.round(window.innerHeight * 0.3));
  };
  var goBtn = null;
  function offerGo(h) {
    if (goBtn) { goBtn.remove(); goBtn = null; }
    var r = h.getBoundingClientRect();
    if (r.top >= 0 && r.top < window.innerHeight - 60) return;
    goBtn = document.createElement('button');
    var t = (h.innerText || '').trim();
    goBtn.textContent = 'Altron is on: ' + (t.length > 40 ? t.slice(0, 40) + '…' : t) + (r.top > 0 ? '  ↓' : '  ↑');
    goBtn.style.cssText = 'position:fixed;right:18px;bottom:18px;z-index:9999;padding:10px 16px;border:0;border-radius:22px;' +
      'background:#0D1726;color:#fff;font:600 14px system-ui,sans-serif;box-shadow:0 4px 14px rgba(0,0,0,.25);cursor:pointer';
    goBtn.onclick = function () { h.scrollIntoView({ behavior: 'smooth', block: 'start' }); goBtn.remove(); goBtn = null; };
    document.body.appendChild(goBtn);
  }
  window.addEventListener('scroll', function () {
    if (!goBtn || last < 0) return;
    var h = heads[last], r = h && h.getBoundingClientRect();
    if (r && r.top >= 0 && r.top < window.innerHeight - 60) { goBtn.remove(); goBtn = null; }
  }, { passive: true });
  // While Altron talks about a section, the page drifts slowly through it at about reading speed, so the learner never
  // has to scroll. Any scroll of their own (wheel, touch, keys) stops the drift until the next section.
  var drift = null;
  function stopDrift() { if (drift) { clearInterval(drift); drift = null; } }
  ['wheel', 'touchstart', 'keydown', 'mousedown'].forEach(function (ev) { window.addEventListener(ev, stopDrift, { passive: true }); });
  function follow(blocks) {
    stopDrift();
    if (!blocks || !blocks.length) return;
    var endEl = blocks[blocks.length - 1];
    // Paced to Altron's talk, not a fixed speed: explaining a section in depth takes about 2.5 times as long as reading
    // it aloud (2.2 words a second), and never under a minute and a half; the page reaches its end as Altron does.
    var words = 0;
    for (var w = 0; w < blocks.length; w++) words += (blocks[w].innerText || '').split(/\s+/).length;
    var seconds = Math.max(90, words / 2.2 * 2.5);
    setTimeout(function () {                    // after the smooth jump to the heading has settled
      var distance = endEl.getBoundingClientRect().bottom - (window.innerHeight - 40);
      if (distance <= 0) return;
      var perTick = distance / (seconds * 10), owed = 0;
      drift = setInterval(function () {
        var bottom = endEl.getBoundingClientRect().bottom;
        if (bottom <= window.innerHeight - 40) { stopDrift(); return; }
        owed += perTick;
        if (owed >= 1) { window.scrollBy(0, Math.floor(owed)); owed -= Math.floor(owed); }
      }, 100);
    }, 8000);                                   // Altron first says what the section is about
  }
  function tapSelects() {
    var sels = document.querySelectorAll('select:not([multiple])');
    for (var s = 0; s < sels.length; s++) (function (sel) {
      if (sel.__altroTap) return; sel.__altroTap = true;
      var row = document.createElement('div');
      row.style.cssText = 'display:inline-flex;flex-wrap:wrap;gap:6px;margin:4px 6px 4px 0;vertical-align:middle';
      function paint() { for (var b = 0; b < row.children.length; b++) { var on = row.children[b].__v === sel.value;
        row.children[b].style.background = on ? '#14343F' : '#fff'; row.children[b].style.color = on ? '#fff' : '#14343F'; } }
      for (var o = 0; o < sel.options.length; o++) (function (opt) {
        var btn = document.createElement('button'); btn.type = 'button'; btn.textContent = opt.text; btn.__v = opt.value;
        btn.style.cssText = 'font:inherit;font-size:14px;padding:6px 12px;border:1px solid #14343F;border-radius:8px;cursor:pointer';
        btn.onclick = function () { sel.value = opt.value; sel.dispatchEvent(new Event('input', { bubbles: true }));
          sel.dispatchEvent(new Event('change', { bubbles: true })); paint(); };
        row.appendChild(btn);
      })(sel.options[o]);
      sel.style.display = 'none'; sel.parentNode.insertBefore(row, sel.nextSibling); paint();
    })(sels[s]);
  }
  function start() { collect(); inView(); try { tapSelects(); } catch (e) {} }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
</script>
""";

/// The script that makes one section of the note glow ([bring] also scrolls it into view).
String showSectionScript(int index, {bool bring = false}) => 'window.__altroShow && window.__altroShow($index, $bring)';

/// A note for the tutor view: the same closed page as [lessonPage], plus the small script that reports where the learner is.
String tutorPage(String html) {
  final page = lessonPage(html);
  // Right after the security line in the head: a note's own script may hold the text "</body>" (a template it builds),
  // and putting the bridge there once broke the note's buttons and showed the bridge as text.
  final at = page.indexOf('<meta http-equiv="Content-Security-Policy"');
  if (at < 0) return '$noteBridgeScript$page';
  final end = page.indexOf('>', at) + 1;
  return page.replaceRange(end, end, noteBridgeScript);
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
