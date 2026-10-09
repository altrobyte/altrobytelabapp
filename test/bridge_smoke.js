// Runs the script that is added to a note shown in the app against a stand-in page: the section in view is reported, a link
// is handed to the app, and the section the tutor talks about glows (one at a time).  node test/bridge_smoke.js
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const dart = fs.readFileSync(path.join(__dirname, '..', 'lib', 'desktop', 'visual_page.dart'), 'utf8');
const from = dart.indexOf('const noteBridgeScript = r"""');
const block = dart.slice(from, dart.indexOf('""";', from));
const js = block.slice(block.indexOf('<script>') + 8, block.lastIndexOf('</script>'));

function el(tag, parent, cls) {
  const classes = new Set(cls ? [cls] : []);
  const e = {
    tag, parentElement: parent || null, children: [], top: 0, scrolled: 0, offsetWidth: 10,
    classList: { add: (c) => classes.add(c), remove: (c) => classes.delete(c), contains: (c) => classes.has(c) },
    matches(sel) { return sel.split(',').some((s) => s.trim() === tag || (s.trim().startsWith('.') && classes.has(s.trim().slice(1))) || (/card/.test(s) && [...classes].some((c) => c.includes('card')))); },
    querySelectorAll(sel) { const out = []; (function walk(n) { for (const c of n.children) { if (['h1', 'h2', 'h3'].includes(c.tag)) out.push(c); walk(c); } })(e); return out; },
    querySelector() { return null; },
    getBoundingClientRect() { return { top: e.top, width: 100, height: 20 }; },
    scrollIntoView() { e.scrolled++; },
    closest() { return null; },
    appendChild(c) { e.children.push(c); c.parentElement = e; return c; },
  };
  if (parent) parent.children.push(e);
  return e;
}

const body = el('body');
const cardA = el('section', body, 'card');
const h1 = el('h2', cardA);
const cardB = el('div', body, 'topic-card');
const h2 = el('h2', cardB);
const loose = el('h3', body); // a heading with no box of its own
h1.top = -500; h2.top = 100; loose.top = 900;

const posted = [];
const listeners = {};
const head = el('head');
const document = {
  body, head, documentElement: body, readyState: 'complete',
  createElement: (t) => el(t),
  querySelectorAll: () => body.querySelectorAll('h1,h2,h3'),
  addEventListener: (name, fn) => { listeners[name] = fn; },
};
const window = { innerHeight: 800, chrome: { webview: { postMessage: (m) => posted.push(m) } }, addEventListener() {} };
new Function('window', 'document', 'setTimeout', js)(window, document, (f) => f());

// the section whose heading has passed the reading line is the one reported
assert.deepStrictEqual(posted, [{ section: 1 }]);

// the tutor points at a section: its box glows, and only that one
window.__altroShow(0, false);
assert.ok(cardA.classList.contains('altro-now'));
window.__altroShow(1, true);
assert.ok(cardB.classList.contains('altro-now') && !cardA.classList.contains('altro-now'));
assert.strictEqual(h2.scrolled, 1); // picked from the list: the note goes there
window.__altroShow(2, false);
assert.ok(loose.classList.contains('altro-now') && !cardB.classList.contains('altro-now')); // no box: the heading itself
window.__altroShow(9, false); // not a section: nothing happens, nothing breaks
assert.ok(loose.classList.contains('altro-now'));
assert.strictEqual(head.children.length, 1); // one style block, added once

// a link is handed to the app instead of leaving the note
let prevented = false;
listeners.click({ target: { closest: () => ({ href: 'https://example.com/x' }) }, preventDefault: () => { prevented = true; } });
assert.ok(prevented);
assert.deepStrictEqual(posted[posted.length - 1], { open: 'https://example.com/x' });
console.log('bridge ok');
