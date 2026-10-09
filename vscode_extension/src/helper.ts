// Starting the helper and talking to it. No VS Code imports here, so the real helper can be
// started and exercised from plain Node tests.

import { ChildProcess, spawn } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { SseParser } from './sse';

export interface HelperInfo {
  port: number;
  token: string;
  version: string;
  pid: number;
}

export interface LaunchOptions {
  python: string;
  helperDir: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
  onLog?: (line: string) => void;
}

export interface RunningHelper {
  info: HelperInfo;
  /** The process this window started, or null when it joined a helper another app had already started. */
  proc: ChildProcess | null;
  /** True when this joined a helper that was already running (the desktop app's, or another window's). */
  attached: boolean;
  /** Ends the helper this started. A helper that was only joined is left alone: someone else is using it. */
  stop(): Promise<void>;
  /** Lets go without ending anything: the helper ends itself when nobody is connected any more. */
  detach(): void;
}

export class HelperError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

/** Starts `python -m altrobyte_helper` and waits for its one-line "ready" announcement. */
export function launchHelper(opts: LaunchOptions): Promise<RunningHelper> {
  return new Promise((resolve, reject) => {
    let proc: ChildProcess;
    try {
      proc = spawn(opts.python, ['-u', '-m', 'altrobyte_helper'], {
        cwd: opts.helperDir,
        windowsHide: true,
        detached: true, // outlives this window: it is shared with other apps and ends itself when nobody uses it
        env: { ...process.env, ...opts.env },
      });
    } catch (e) {
      reject(new Error(`Could not start Python (${opts.python}): ${(e as Error).message}`));
      return;
    }
    let stderr = '';
    let buffer = '';
    let settled = false;
    const fail = (message: string) => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        proc.kill();
        reject(new Error(message));
      }
    };
    const timer = setTimeout(
      () => fail(`The helper did not start within ${(opts.timeoutMs ?? 20000) / 1000}s.${stderr ? '\n' + stderr.trim().slice(-600) : ''}`),
      opts.timeoutMs ?? 20000,
    );
    proc.on('error', (e) => fail(`Could not start Python (${opts.python}): ${e.message}`));
    proc.on('exit', (code) => fail(`The helper stopped right away (exit ${code}).${stderr ? '\n' + stderr.trim().slice(-600) : ''}`));
    proc.stderr?.on('data', (d: Buffer) => {
      stderr += d.toString();
      opts.onLog?.(d.toString().trimEnd());
    });
    proc.stdout?.on('data', (d: Buffer) => {
      buffer += d.toString();
      let nl: number;
      while ((nl = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, nl).trim();
        buffer = buffer.slice(nl + 1);
        if (!line) {
          continue;
        }
        try {
          const msg = JSON.parse(line);
          if (msg.event === 'ready' && !settled) {
            settled = true;
            clearTimeout(timer);
            proc.removeAllListeners('exit');
            const info = { port: msg.port, token: msg.token, version: msg.version, pid: msg.pid };
            if (msg.reused) {
              // Another helper was already running; the process we started has nothing to do and ends by itself.
              resolve({ info, proc: null, attached: true, stop: async () => undefined, detach: () => undefined });
              return;
            }
            resolve({
              info,
              proc,
              attached: false,
              stop: () => stopProcess(proc),
              detach: () => {
                proc.unref();
                proc.stdout?.destroy();
                proc.stderr?.destroy();
              },
            });
          }
        } catch {
          opts.onLog?.(line);
        }
      }
    });
  });
}

/** Where the shared helper records itself: the same folder the helper itself uses. */
export function helperHome(env: NodeJS.ProcessEnv = process.env): string {
  if (env.ALTROBYTE_HOME) {
    return env.ALTROBYTE_HOME;
  }
  return env.LOCALAPPDATA ? path.join(env.LOCALAPPDATA, 'Altrobyte') : path.join(os.homedir(), '.altrobyte');
}

/** The helper that is already running, if its record is readable and it really answers with its token. */
export async function findRunningHelper(home: string, timeoutMs = 1500): Promise<HelperInfo | null> {
  let info: HelperInfo;
  try {
    const raw = JSON.parse(fs.readFileSync(path.join(home, 'helper.json'), 'utf-8'));
    if (typeof raw.port !== 'number' || typeof raw.token !== 'string') {
      return null;
    }
    info = { port: raw.port, token: raw.token, version: String(raw.version ?? ''), pid: Number(raw.pid ?? 0) };
  } catch {
    return null;
  }
  try {
    const res = await fetch(`http://127.0.0.1:${info.port}/health`, {
      headers: { Authorization: `Bearer ${info.token}` },
      signal: AbortSignal.timeout(timeoutMs),
    });
    return res.ok ? info : null;
  } catch {
    return null; // a record of a helper that is gone
  }
}

/** Joins the helper that is running on this computer, or starts one. There is only ever one. */
/** The oldest helper this extension works with: before it, courses and the setup check do not exist. */
export const MIN_HELPER_VERSION = '0.2.0';

/** True when `have` ("0.1.0") is the same as or newer than `need`. An unreadable version counts as too old. */
export function versionAtLeast(have: string, need: string): boolean {
  const a = String(have).split('.').map((n) => parseInt(n, 10));
  const b = String(need).split('.').map((n) => parseInt(n, 10));
  if (a.some(Number.isNaN)) {
    return false;
  }
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] ?? 0;
    const y = b[i] ?? 0;
    if (x !== y) {
      return x > y;
    }
  }
  return true;
}

export async function connectHelper(opts: LaunchOptions & { home?: string }): Promise<RunningHelper> {
  const home = opts.home ?? helperHome({ ...process.env, ...opts.env });
  const found = await findRunningHelper(home);
  if (found) {
    if (versionAtLeast(found.version, MIN_HELPER_VERSION)) {
      return { info: found, proc: null, attached: true, stop: async () => undefined, detach: () => undefined };
    }
    await shutdownHelper(found, home); // an older helper left running by an older app: replace it with this one's own
  }
  return launchHelper(opts); // if another app starts one at the same moment, the helper itself sees it and reuses it
}

/** Asks a running helper to end, and waits until it has. Used by "restart the helper". */
export async function shutdownHelper(info: HelperInfo, home: string): Promise<void> {
  try {
    await fetch(`http://127.0.0.1:${info.port}/shutdown`, { method: 'POST', headers: { Authorization: `Bearer ${info.token}` } });
  } catch {
    return;
  }
  for (let i = 0; i < 40; i++) {
    if (!(await findRunningHelper(home, 500))) {
      return;
    }
    await new Promise((r) => setTimeout(r, 150));
  }
}

function stopProcess(proc: ChildProcess): Promise<void> {
  return new Promise((resolve) => {
    if (proc.exitCode !== null || proc.killed) {
      resolve();
      return;
    }
    proc.once('exit', () => resolve());
    proc.kill();
    setTimeout(resolve, 3000);
  });
}

export type HelperEventHandler = (event: string, data: any) => void;

export class HelperClient {
  constructor(private info: HelperInfo) {}

  get base(): string {
    return `http://127.0.0.1:${this.info.port}`;
  }

  private headers(json = true): Record<string, string> {
    return { Authorization: `Bearer ${this.info.token}`, ...(json ? { 'Content-Type': 'application/json' } : {}) };
  }

  private async request(method: string, path: string, body?: unknown): Promise<Response> {
    const res = await fetch(this.base + path, {
      method,
      headers: this.headers(body !== undefined),
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!res.ok) {
      let detail = res.statusText;
      try {
        const j = (await res.json()) as { detail?: string };
        if (typeof j.detail === 'string') {
          detail = j.detail;
        }
      } catch {
        /* keep statusText */
      }
      throw new HelperError(res.status, detail);
    }
    return res;
  }

  async get<T = any>(path: string): Promise<T> {
    return (await this.request('GET', path)).json() as Promise<T>;
  }
  async put<T = any>(path: string, body: unknown): Promise<T> {
    return (await this.request('PUT', path, body)).json() as Promise<T>;
  }
  async post<T = any>(path: string, body: unknown = {}): Promise<T> {
    return (await this.request('POST', path, body)).json() as Promise<T>;
  }
  async audio(text: string, lang?: string): Promise<Buffer> {
    const res = await this.request('POST', '/tts', { text, lang });
    return Buffer.from(await res.arrayBuffer());
  }

  /** Listens to the helper's event stream until `abort()` is called or the stream ends. */
  events(onEvent: HelperEventHandler, onClose: (reason: string) => void): { abort: () => void; ready: Promise<void> } {
    const controller = new AbortController();
    let markReady: () => void = () => undefined;
    const ready = new Promise<void>((r) => (markReady = r));
    (async () => {
      try {
        const res = await fetch(this.base + '/events', { headers: this.headers(false), signal: controller.signal });
        if (!res.ok || !res.body) {
          onClose(`events failed (${res.status})`);
          return;
        }
        const parser = new SseParser();
        const decoder = new TextDecoder();
        const reader = res.body.getReader();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) {
            break;
          }
          for (const ev of parser.push(decoder.decode(value, { stream: true }))) {
            if (ev.event === 'ready') {
              markReady();
              continue;
            }
            let data: any = {};
            try {
              data = ev.data ? JSON.parse(ev.data) : {};
            } catch {
              /* ignore a malformed payload */
            }
            onEvent(ev.event, data);
          }
        }
        onClose('closed');
      } catch (e) {
        onClose(controller.signal.aborted ? 'aborted' : (e as Error).message);
      } finally {
        markReady();
      }
    })();
    return { abort: () => controller.abort(), ready };
  }
}
