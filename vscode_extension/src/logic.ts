// Pure helpers: no VS Code, no network. Tested on their own.

export interface RawDiagnostic {
  path: string;
  line: number;
  severity: 'error' | 'warning';
  message: string;
}

export interface EditorDiagnostics {
  file: string; // absolute path
  diagnostics: { line: number; severity: number; message: string }[]; // line is 0-based; severity is vscode's (0 error, 1 warning, ...)
}

const norm = (p: string) => p.replace(/\\/g, '/');

/** `file` relative to `root` with forward slashes, or null if it is not inside the root. */
export function relativeTo(root: string, file: string): string | null {
  const r = norm(root).replace(/\/+$/, '');
  const f = norm(file);
  const same = (a: string, b: string) => (process.platform === 'win32' ? a.toLowerCase() === b.toLowerCase() : a === b);
  if (f.length > r.length + 1 && same(f.slice(0, r.length), r) && f[r.length] === '/') {
    return f.slice(r.length + 1);
  }
  return null;
}

/** The editor's errors and warnings for files inside the project, in the helper's format. Hints and infos are dropped. */
export function mapDiagnostics(all: EditorDiagnostics[], root: string, limit = 80): RawDiagnostic[] {
  const out: RawDiagnostic[] = [];
  for (const entry of all) {
    const rel = relativeTo(root, entry.file);
    if (rel === null || /(^|\/)(\.pio|node_modules|\.git)\//.test(rel)) {
      continue;
    }
    for (const d of entry.diagnostics) {
      if (d.severity > 1) {
        continue;
      }
      out.push({ path: rel, line: d.line + 1, severity: d.severity === 0 ? 'error' : 'warning', message: d.message.slice(0, 500) });
      if (out.length >= limit) {
        return out;
      }
    }
  }
  return out;
}

export interface AuditEntry {
  t: string;
  kind: string;
  [k: string]: unknown;
}

/** A readable version of the audit log: what was asked of this computer, and what was sent out. */
export function formatAudit(entries: AuditEntry[]): string {
  if (!entries.length) {
    return 'Nothing yet. Every request the trainer makes of this computer, and everything sent to the cloud, will be listed here.\n';
  }
  const lines = ['Altrobyte Trainer: what happened on this computer', '(newest last; nothing is sent that is not listed here)', ''];
  for (const e of entries) {
    const time = String(e.t).slice(11);
    if (e.kind === 'op') {
      const args = e.args && Object.keys(e.args as object).length ? ' ' + JSON.stringify(e.args) : '';
      const why = e.reason ? `  (${e.reason})` : '';
      lines.push(`${time}  ASKED  ${e.op}${args}  ->  ${String(e.outcome).toUpperCase()}${why}`);
    } else if (e.kind === 'cloud') {
      const masked = Number(e.masked) > 0 ? `, ${e.masked} secret(s) hidden` : '';
      lines.push(`${time}  SENT   ${e.what}  (${e.bytes ?? '?'} bytes${masked})`);
      if (e.preview) {
        lines.push(`           ${String(e.preview).replace(/\s+/g, ' ').slice(0, 160)}`);
      }
    } else if (e.kind === 'verify') {
      lines.push(`${time}  CHECK  ${e.milestone}  ->  ${e.passed ? 'PASSED' : 'not yet'}${e.error ? '  (' + e.error + ')' : ''}  [no internet needed]`);
    } else if (e.kind === 'grants') {
      lines.push(`${time}  ALLOWED  ${(e.connectors as string[]).join(', ') || 'nothing'}`);
    } else {
      lines.push(`${time}  ${e.kind}`);
    }
  }
  return lines.join('\n') + '\n';
}

/** What to tell the learner for a failure event from the helper. */
export function describeError(e: { kind?: string; message?: string }): string {
  switch (e.kind) {
    case 'offline':
      return 'No internet right now, so the trainer cannot chat. You can still use "Check my progress" for the checks that run on this computer.';
    case 'auth':
      return 'Please sign in again (Altrobyte: Sign in).';
    case 'forbidden':
      return 'This account is not allowed to use the trainer yet.';
    case 'quota':
      return e.message || 'The trainer is at its daily limit. Try again later.';
    case 'busy':
      return 'The trainer is still answering. One moment.';
    default:
      return e.message || 'Something went wrong talking to the trainer.';
  }
}

/** The page shown beside the editor for a picture the assistant drew. The picture is already cleaned by the server; the
 * page still allows no script and no network, so the worst a picture can do is look wrong. */
export function visualPage(title: string, body: string): string {
  const esc = (t: string) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  return `<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:;">
<style>
  body { font-family: var(--vscode-font-family); color: var(--vscode-foreground); padding: 16px; line-height: 1.5; }
  .card { background: #fff; color: #212121; border-radius: 10px; padding: 14px; max-width: 900px; }
  svg { max-width: 100%; height: auto; } table { border-collapse: collapse; } td, th { border: 1px solid #ccc; padding: 4px 8px; }
</style></head><body><h2>${esc(title)}</h2><div class="card">${body}</div></body></html>`;
}

/** A 0-based line for the editor from the 1-based line the assistant talks about. */
export function editorLine(line: unknown): number {
  const n = Number(line);
  return Number.isFinite(n) && n >= 1 ? Math.floor(n) - 1 : 0;
}

/** The module id in a link like vscode://altrobyte.altrobyte-trainer/lab?module=9, or null if it is not one. */
export function labLink(pathname: string, query: string): number | null {
  if (pathname !== '/lab') {
    return null;
  }
  const m = /(?:^|&)module=(\d{1,9})(?:&|$)/.exec(query);
  return m ? Number(m[1]) : null;
}

export const CONNECTORS: { id: string; label: string; help: string }[] = [
  { id: 'system', label: 'Installed tools and USB', help: 'Whether VS Code / PlatformIO are installed, and which USB board is plugged in.' },
  { id: 'workspace', label: 'Your project files', help: 'Reads files inside your project folder. With your OK each time, it can add a starter file there.' },
  { id: 'toolchain', label: 'Build and upload', help: 'Compile and flash. It asks you every single time.' },
  { id: 'serial', label: 'Serial monitor', help: 'What your board prints. The helper owns the port while this is on.' },
  { id: 'mqtt', label: 'MQTT check', help: 'Listens on your topic to confirm your data arrives. Needs a broker set up.' },
];
