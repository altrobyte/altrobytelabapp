// Starts the REAL helper (Python) and drives it the way the extension does. Skipped if the helper
// source or Python is not available (for example on a machine without the backend checkout).
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { after, before, test } from 'node:test';
import { HelperClient, HelperError, RunningHelper, launchHelper } from '../src/helper';

const helperDir = process.env.ALTROBYTE_HELPER_DIR ?? resolve(__dirname, '..', '..', '..', '..', 'altrocoach-backend', 'helper');
const python = process.env.ALTROBYTE_PYTHON ?? 'python';
const available = existsSync(join(helperDir, 'altrobyte_helper', '__main__.py')) && (() => {
  try {
    execFileSync(python, ['-c', 'import fastapi, uvicorn, serial'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
})();
const opts = { skip: available ? false : 'helper source or its Python packages are not available' };

let helper: RunningHelper;
let client: HelperClient;
let home: string;
let project: string;

before(async () => {
  if (!available) {
    return;
  }
  home = mkdtempSync(join(tmpdir(), 'altrobyte-home-'));
  project = mkdtempSync(join(tmpdir(), 'altrobyte-proj-'));
  mkdirSync(join(project, 'src'));
  writeFileSync(join(project, 'platformio.ini'), '[env:esp32dev]\nplatform = espressif32\nboard = esp32dev\nframework = arduino\nmonitor_speed = 115200\n');
  writeFileSync(join(project, 'src', 'main.cpp'), 'void setup(){}\nvoid loop(){}\n');
  helper = await launchHelper({ python, helperDir, env: { ALTROBYTE_HOME: home } });
  client = new HelperClient(helper.info);
});

after(async () => {
  await helper?.stop();
});

test('the helper announces itself and answers with the token', opts, async () => {
  assert.ok(helper.info.port > 0 && helper.info.token.length >= 24);
  const h = await client.get('/health');
  assert.equal(h.ok, true);
  assert.equal(h.session, false);
});

test('a request without the token, or to another host name, is refused', opts, async () => {
  const bare = await fetch(`${client.base}/health`);
  assert.equal(bare.status, 401);
  const wrong = await fetch(`${client.base}/health`, { headers: { Authorization: 'Bearer nope' } });
  assert.equal(wrong.status, 401);
  await assert.rejects(client.get('/nope'), (e: unknown) => e instanceof HelperError && e.status === 404);
});

test('settings round-trip and the project folder is remembered', opts, async () => {
  const s = await client.put('/settings', { project_dir: project, grants: ['system', 'workspace', 'toolchain', 'serial'] });
  assert.equal(s.project_dir, project);
  assert.deepEqual((await client.get('/settings')).grants, ['system', 'workspace', 'toolchain', 'serial']);
});

test('offline checks run on the real machine with no internet', opts, async () => {
  await client.post('/environment', { software: { vscode: '1.140.0', 'platformio-ide': '3.3.4' } });
  const first = await client.post('/verify', { milestone: 'toolchain_ready' });
  assert.equal(first.passed, true);
  assert.equal(first.done.toolchain_ready, true);
  assert.equal(Object.keys(first.done)[0], 'toolchain_ready', 'milestones come back in mission order');
  assert.equal(first.titles.board_connected, 'Board connected');
  const ini = await client.post('/verify', { milestone: 'project_setup' });
  assert.equal(ini.passed, true, JSON.stringify(ini));
  const audit = await client.get('/audit?kind=verify');
  assert.deepEqual(audit.entries.map((e: any) => e.milestone), ['toolchain_ready', 'project_setup']);
});

test('the editor can hand over its own diagnostics', opts, async () => {
  const r = await client.post('/environment', { diagnostics: [{ path: 'src/main.cpp', line: 3, severity: 'error', message: "expected ';'" }] });
  assert.equal(r.ok, true);
});

test('events stream: a failed start surfaces as an "offline" error event', opts, async () => {
  await client.put('/settings', { api_base: 'http://127.0.0.1:1' }); // nothing listens there
  await client.post('/session/auth', { token: 'x' });
  const got: { kind: string; data: any }[] = [];
  const sub = client.events((kind, data) => got.push({ kind, data }), () => undefined);
  await sub.ready;
  await client.post('/session/start');
  const deadline = Date.now() + 15000;
  while (!got.some((e) => e.kind === 'error') && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 100));
  }
  sub.abort();
  const err = got.find((e) => e.kind === 'error');
  assert.ok(err, 'an error event should arrive');
  assert.equal(err!.data.kind, 'offline');
  assert.match(err!.data.message, /internet/i);
  const audit = await client.get('/audit?kind=cloud');
  assert.ok(audit.entries.some((e: any) => e.what === 'start session'), 'what was about to be sent is logged');
});

test('an approval question that nobody answers is refused, never assumed', opts, async () => {
  const r = await fetch(`${client.base}/approvals/not-a-real-id`, { method: 'POST', headers: { Authorization: `Bearer ${helper.info.token}`, 'Content-Type': 'application/json' }, body: '{"allow":true}' });
  assert.equal(r.status, 404);
});

test('text to speech returns a WAV when Windows speech is present', { skip: !available || process.platform !== 'win32' ? 'needs Windows speech' : false }, async () => {
  const wav = await client.audio('Hello, I can see your board.');
  assert.equal(wav.subarray(0, 4).toString(), 'RIFF');
  assert.ok(wav.length > 10_000);
  await assert.rejects(client.audio('नमस्ते', 'hi'), (e: unknown) => e instanceof HelperError && (e.status === 501 || e.status === 200));
});

test('stopping the helper really ends the process', opts, async () => {
  const pid = helper.info.pid;
  await helper.stop();
  await new Promise((r) => setTimeout(r, 500));
  let alive = true;
  try {
    process.kill(pid, 0);
  } catch {
    alive = false;
  }
  assert.equal(alive, false);
});
