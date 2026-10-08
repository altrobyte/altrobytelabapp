// Bundles the extension (and, with --tests, the tests) with esbuild; type-checks with tsc.
import { build, context } from 'esbuild';
import { execSync } from 'node:child_process';
import { readdirSync } from 'node:fs';

const watch = process.argv.includes('--watch');
const tests = process.argv.includes('--tests');

const common = { bundle: true, platform: 'node', format: 'cjs', sourcemap: true, logLevel: 'info', target: 'node20' };

const jobs = [{ ...common, entryPoints: ['src/extension.ts'], outfile: 'out/extension.js', external: ['vscode'] }];
if (tests) {
  const files = readdirSync('test').filter((f) => f.endsWith('.ts'));
  jobs.push({ ...common, entryPoints: files.map((f) => `test/${f}`), outdir: 'out/test', external: ['vscode', '@vscode/test-electron'] });
}

try {
  execSync('npx tsc --noEmit -p .', { stdio: 'inherit' });
} catch {
  process.exit(1);
}

for (const job of jobs) {
  if (watch) {
    await (await context(job)).watch();
  } else {
    await build(job);
  }
}
