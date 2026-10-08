// Starting the helper and talking to it. No VS Code imports here, so the real helper can be
// started and exercised from plain Node tests.

import { ChildProcess, spawn } from 'node:child_process';
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
  proc: ChildProcess;
  stop(): Promise<void>;
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
            resolve({
              info: { port: msg.port, token: msg.token, version: msg.version, pid: msg.pid },
              proc,
              stop: () => stopProcess(proc),
            });
          }
        } catch {
          opts.onLog?.(line);
        }
      }
    });
  });
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
