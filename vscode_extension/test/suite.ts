// Runs INSIDE a real VS Code (see runInVscode.ts). Checks what only the real editor can show:
// the extension activates, its panel's script runs, the helper starts, and the editor's facts reach it.
import assert from 'node:assert/strict';
import { existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import * as vscode from 'vscode';

async function until<T>(what: string, fn: () => T | undefined | Promise<T | undefined>, ms = 30000): Promise<T> {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const v = await fn();
    if (v) {
      return v;
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error(`Timed out waiting for ${what}`);
}

export async function run(): Promise<void> {
  const failures: string[] = [];
  const t = async (name: string, fn: () => Promise<void>) => {
    try {
      await fn();
      console.log(`  ok   ${name}`);
    } catch (e) {
      console.log(`  FAIL ${name}\n       ${(e as Error).message}`);
      failures.push(`${name}: ${(e as Error).message}`);
    }
  };

  const ext = vscode.extensions.getExtension('altrobyte.altrobyte-trainer');
  let controller: any;
  const project = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';

  await t('the extension is found and activates', async () => {
    assert.ok(ext, 'extension altrobyte.altrobyte-trainer not found');
    const api = await ext.activate();
    controller = api.controller;
    assert.ok(controller, 'activate() should hand back its controller');
  });

  await t('every command is registered', async () => {
    const all = await vscode.commands.getCommands(true);
    for (const c of ['signIn', 'signOut', 'startSession', 'chooseProject', 'showAudit', 'restartHelper']) {
      assert.ok(all.includes(`altrobyte.${c}`), `missing command altrobyte.${c}`);
    }
  });

  await t('opening the panel runs its script, which starts the helper', async () => {
    assert.equal(controller.running, null, 'the helper should not be running before the panel is opened');
    await vscode.commands.executeCommand('altrobyte.trainer.focus');
    await until('the helper to start (the panel posts "ready" only if its script ran)', () => controller.running);
    const health = await controller.client.get('/health');
    assert.equal(health.ok, true);
  });

  await t('the open folder becomes the project folder the trainer may read', async () => {
    assert.ok(project, 'the test must be started with a project folder');
    const s = await controller.client.get('/settings');
    assert.equal(String(s.project_dir).toLowerCase(), project.toLowerCase());
  });

  await t("the editor's own version and errors reach the helper", async () => {
    const file = join(project, 'src', 'main.cpp');
    assert.ok(existsSync(file));
    const collection = vscode.languages.createDiagnosticCollection('altrobyte-test');
    collection.set(vscode.Uri.file(file), [
      new vscode.Diagnostic(new vscode.Range(11, 0, 11, 5), "'TEMP_PIN' was not declared in this scope", vscode.DiagnosticSeverity.Error),
    ]);
    const env = await until('the diagnostic to reach the helper', async () => {
      const e = await controller.client.get('/environment');
      return e.diagnostics && e.diagnostics.length ? e : undefined;
    });
    assert.equal(env.software.vscode, vscode.version);
    assert.deepEqual(env.diagnostics[0], { path: 'src/main.cpp', line: 12, severity: 'error', message: "'TEMP_PIN' was not declared in this scope" });
    collection.dispose();
  });

  await t('the offline check works from inside the editor, with no internet', async () => {
    const r = await controller.client.post('/verify', { milestone: 'toolchain_ready' });
    assert.ok(r.done && 'toolchain_ready' in r.done, JSON.stringify(r));
    assert.match(String(r.untrusted?.evidence ?? r.error), new RegExp(`vscode ${vscode.version.replace(/\./g, '\\.')}|platformio`));
  });

  await t('"show what the trainer did" opens a readable log', async () => {
    await vscode.commands.executeCommand('altrobyte.showAudit');
    const doc = await until('the audit document', () => vscode.window.activeTextEditor?.document);
    assert.match(doc.getText(), /what happened on this computer/);
    assert.match(doc.getText(), /CHECK {2}toolchain_ready/);
  });

  await t('restarting the helper gives a fresh one, and disposing really stops it', async () => {
    const oldPid = controller.running.info.pid;
    await controller.startHelper();
    assert.ok(controller.running, 'a helper should be running again');
    assert.notEqual(controller.running.info.pid, oldPid);
    const pid = controller.running.info.pid;
    await controller.dispose();
    await new Promise((r) => setTimeout(r, 600));
    let alive = true;
    try {
      process.kill(pid, 0);
    } catch {
      alive = false;
    }
    assert.equal(alive, false, 'the helper process should be gone');
  });

  writeFileSync(join(project, '.suite-done'), failures.length ? 'failed' : 'passed');
  if (failures.length) {
    throw new Error(`${failures.length} check(s) failed:\n${failures.join('\n')}`);
  }
}
