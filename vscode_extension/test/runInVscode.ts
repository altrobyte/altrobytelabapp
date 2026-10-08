// Launches the real, installed VS Code with this extension loaded and runs suite.ts inside it.
//   npm run test:vscode
// A VS Code window opens for a few seconds. It uses its own empty user-data folder and no other
// extensions, so it does not touch your editor settings or your open windows.
import { runTests } from '@vscode/test-electron';
import { existsSync, mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

async function main() {
  // When this is started from a terminal or tool that lives inside VS Code, the environment carries
  // ELECTRON_RUN_AS_NODE (which makes Code.exe behave like plain Node and treat the project folder as a
  // script) and VSCODE_* variables (which would make it join the already-open window instead of starting a
  // clean one). Neither belongs in a test instance.
  for (const key of Object.keys(process.env)) {
    if (key === 'ELECTRON_RUN_AS_NODE' || key.startsWith('VSCODE_')) {
      delete process.env[key];
    }
  }
  const exe =
    process.env.VSCODE_EXE ??
    [join(process.env.LOCALAPPDATA ?? '', 'Programs', 'Microsoft VS Code', 'Code.exe'), 'C:\\Program Files\\Microsoft VS Code\\Code.exe'].find(existsSync);
  if (!exe) {
    throw new Error('Could not find Code.exe. Set VSCODE_EXE to its full path.');
  }
  const project = mkdtempSync(join(tmpdir(), 'altrobyte-vscode-proj-'));
  mkdirSync(join(project, 'src'));
  writeFileSync(join(project, 'platformio.ini'), '[env:esp32dev]\nplatform = espressif32\nboard = esp32dev\nframework = arduino\nmonitor_speed = 115200\n');
  writeFileSync(join(project, 'src', 'main.cpp'), '#include <Arduino.h>\nvoid setup() {}\nvoid loop() {}\n'.repeat(1) + '\n'.repeat(20));
  const userData = mkdtempSync(join(tmpdir(), 'altrobyte-vscode-data-'));

  await runTests({
    vscodeExecutablePath: exe,
    extensionDevelopmentPath: resolve(__dirname, '..', '..'),
    extensionTestsPath: resolve(__dirname, 'suite.js'),
    launchArgs: [project, '--disable-extensions', '--user-data-dir', userData, '--disable-workspace-trust', '--skip-welcome', '--skip-release-notes'],
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
