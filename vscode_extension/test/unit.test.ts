import assert from 'node:assert/strict';
import { test } from 'node:test';
import { describeError, editorLine, formatAudit, mapDiagnostics, relativeTo, visualPage } from '../src/logic';
import { panelHtml } from '../src/panelHtml';
import { SseParser } from '../src/sse';

test('SSE: events split across chunks, CRLF, comments and multi-line data', () => {
  const p = new SseParser();
  assert.deepEqual(p.push('event: mess'), []);
  assert.deepEqual(p.push('age\ndata: {"a":1}\n'), []);
  assert.deepEqual(p.push('\n: keepalive\n\nevent: x\r\ndata: l1\r\ndata: l2\r\n\r\n'), [
    { event: 'message', data: '{"a":1}' },
    { event: 'x', data: 'l1\nl2' },
  ]);
});

test('SSE: an event with no data still arrives, and junk fields are ignored', () => {
  const p = new SseParser();
  assert.deepEqual(p.push('event: ready\ndata: {}\n\nid: 7\nretry: 100\n\n'), [{ event: 'ready', data: '{}' }]);
});

test('paths are made relative to the project only when they are inside it', () => {
  assert.equal(relativeTo('C:\\proj', 'C:\\proj\\src\\main.cpp'), 'src/main.cpp');
  assert.equal(relativeTo('/home/me/proj/', '/home/me/proj/platformio.ini'), 'platformio.ini');
  assert.equal(relativeTo('/home/me/proj', '/home/me/proj-other/x.cpp'), null);
  assert.equal(relativeTo('/home/me/proj', '/etc/passwd'), null);
  assert.equal(relativeTo('/home/me/proj', '/home/me/proj'), null);
});

test('only the project errors and warnings reach the trainer, with 1-based lines', () => {
  const out = mapDiagnostics(
    [
      { file: '/p/src/main.cpp', diagnostics: [{ line: 11, severity: 0, message: "'TEMP_PIN' was not declared" }, { line: 3, severity: 1, message: 'unused' }, { line: 0, severity: 3, message: 'a hint' }] },
      { file: '/p/.pio/build/x.cpp', diagnostics: [{ line: 1, severity: 0, message: 'generated' }] },
      { file: '/elsewhere/a.cpp', diagnostics: [{ line: 1, severity: 0, message: 'not ours' }] },
    ],
    '/p',
  );
  assert.deepEqual(out, [
    { path: 'src/main.cpp', line: 12, severity: 'error', message: "'TEMP_PIN' was not declared" },
    { path: 'src/main.cpp', line: 4, severity: 'warning', message: 'unused' },
  ]);
});

test('diagnostics are capped', () => {
  const many = { file: '/p/a.cpp', diagnostics: Array.from({ length: 300 }, (_, i) => ({ line: i, severity: 0, message: 'e' })) };
  assert.equal(mapDiagnostics([many], '/p').length, 80);
  assert.equal(mapDiagnostics([many], '/p', 5).length, 5);
});

test('the audit log reads as plain sentences about what happened', () => {
  const text = formatAudit([
    { t: '2026-10-08T10:00:01', kind: 'op', op: 'read_file', args: { path: 'platformio.ini' }, outcome: 'ok' },
    { t: '2026-10-08T10:00:02', kind: 'op', op: 'run_build', args: {}, outcome: 'declined' },
    { t: '2026-10-08T10:00:03', kind: 'op', op: 'serial_ports', outcome: 'refused', reason: 'system is switched off' },
    { t: '2026-10-08T10:00:04', kind: 'cloud', what: 'read_file result', bytes: 321, masked: 2, preview: '{"result": "WiFi.begin(\\"MyNet\\", \\"<redacted>\\")"}' },
    { t: '2026-10-08T10:00:05', kind: 'verify', milestone: 'board_connected', passed: true },
    { t: '2026-10-08T10:00:06', kind: 'grants', connectors: ['system', 'workspace'] },
  ]);
  assert.match(text, /10:00:01  ASKED  read_file {"path":"platformio.ini"}  ->  OK/);
  assert.match(text, /ASKED  run_build  ->  DECLINED/);
  assert.match(text, /REFUSED  \(system is switched off\)|REFUSED  {2}\(system is switched off\)/);
  assert.match(text, /SENT   read_file result  \(321 bytes, 2 secret\(s\) hidden\)/);
  assert.match(text, /CHECK  board_connected  ->  PASSED  \[no internet needed\]/);
  assert.match(text, /ALLOWED  system, workspace/);
  assert.match(formatAudit([]), /Nothing yet/);
});

test('failures are explained in terms the learner can act on', () => {
  assert.match(describeError({ kind: 'offline' }), /No internet.*Check my progress/);
  assert.match(describeError({ kind: 'auth' }), /sign in again/i);
  assert.equal(describeError({ kind: 'quota', message: 'Daily limit reached' }), 'Daily limit reached');
  assert.equal(describeError({ kind: 'server', message: 'boom' }), 'boom');
  assert.match(describeError({}), /went wrong/);
});


test('the assistant talks in 1-based lines, the editor counts from 0', () => {
  assert.equal(editorLine(1), 0);
  assert.equal(editorLine(12), 11);
  assert.equal(editorLine(0), 0);
  assert.equal(editorLine('7'), 6);
  assert.equal(editorLine(undefined), 0);
});

test('a picture page allows no script and no network and escapes its title', () => {
  const page = visualPage('<b>x</b>', '<svg></svg>');
  assert.match(page, /default-src 'none'/);
  assert.doesNotMatch(page, /script-src/);
  assert.ok(page.includes('&lt;b>x&lt;/b>') && page.includes('<svg></svg>'));
});

test('the panel script is valid JavaScript and renders markdown without innerHTML on trainer text', () => {
  const html = panelHtml('nonce123', 'vscode-resource:');
  const script = html.slice(html.indexOf('<script nonce="nonce123">') + 25, html.lastIndexOf('</script>'));
  assert.doesNotThrow(() => new Function('acquireVsCodeApi', 'document', 'window', script.replace(/vscode\.postMessage\(\{ type: 'ready' \}\);/, '')));
  assert.match(script, /renderMd\(d, text\)/);
  assert.ok(script.includes("split('\\n')"), 'lines must be split on a newline character, not on a literal line break');
});
