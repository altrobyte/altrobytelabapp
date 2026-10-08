// One helper per computer: a second app joins the running helper instead of starting another, and letting go of a joined
// helper never ends it. These run the real helper as a separate process.
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { HelperClient, connectHelper, findRunningHelper, shutdownHelper } from '../src/helper';

const helperDir = process.env.ALTROBYTE_HELPER_DIR ?? resolve(__dirname, '..', '..', '..', '..', 'altrocoach-backend', 'helper');
const python = process.env.ALTROBYTE_PYTHON ?? 'python';
const available =
  existsSync(join(helperDir, 'altrobyte_helper', '__main__.py')) &&
  (() => {
    try {
      execFileSync(python, ['-c', 'import fastapi, uvicorn, serial'], { stdio: 'ignore' });
      return true;
    } catch {
      return false;
    }
  })();
const opts = { skip: available ? false : 'the helper and its Python packages are not available here' };

test('a record of a helper that is gone, or garbage, is not a running helper', opts, async () => {
  const home = mkdtempSync(join(tmpdir(), 'altrobyte-shared-'));
  assert.equal(await findRunningHelper(home), null); // no record at all
  writeFileSync(join(home, 'helper.json'), 'not json');
  assert.equal(await findRunningHelper(home), null);
  writeFileSync(join(home, 'helper.json'), JSON.stringify({ port: 9, token: 'old', version: '0', pid: 1 }));
  assert.equal(await findRunningHelper(home, 500), null);
});

test('the second app joins the running helper; letting go of it ends nothing; restart ends it', opts, async () => {
  const home = mkdtempSync(join(tmpdir(), 'altrobyte-shared-'));
  const env = { ALTROBYTE_HOME: home, ALTROBYTE_IDLE_SECONDS: '300' };
  const first = await connectHelper({ python, helperDir, env, home });
  try {
    assert.equal(first.attached, false); // nothing was running: this started one
    assert.ok(first.proc);

    const second = await connectHelper({ python, helperDir, env, home });
    assert.equal(second.attached, true);
    assert.equal(second.proc, null);
    assert.equal(second.info.port, first.info.port);
    assert.equal(second.info.token, first.info.token);

    // Settings changed through one app are what the other sees: it is the same helper.
    await new HelperClient(first.info).put('/settings', { project_dir: home });
    assert.equal((await new HelperClient(second.info).get('/settings')).project_dir, home);

    await second.stop();
    second.detach(); // the joined app closes...
    first.detach();
    assert.ok(await findRunningHelper(home), 'the helper must still be running for the others');

    await shutdownHelper(first.info, home); // ...and "restart the helper" ends it on purpose
    assert.equal(await findRunningHelper(home, 500), null);
  } finally {
    await first.stop();
  }
});

test('two apps starting at the same moment still end up on one helper', opts, async () => {
  const home = mkdtempSync(join(tmpdir(), 'altrobyte-shared-'));
  const env = { ALTROBYTE_HOME: home, ALTROBYTE_IDLE_SECONDS: '300' };
  const [a, b] = await Promise.all([connectHelper({ python, helperDir, env, home }), connectHelper({ python, helperDir, env, home })]);
  try {
    assert.equal(a.info.port, b.info.port, 'both must be talking to the same helper');
    assert.equal(a.info.token, b.info.token);
  } finally {
    await shutdownHelper(a.info, home);
    await a.stop();
    await b.stop();
  }
});
