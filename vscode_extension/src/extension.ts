import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { HelperClient, HelperError, RunningHelper, connectHelper, helperHome, shutdownHelper } from './helper';
import * as os from 'node:os';
import { choosePython, describeError, editorLine, formatAudit, labLink, mapDiagnostics, needsPlatformIO, quizAnswerText, starterFolderPath, visualPage } from './logic';
import { panelHtml } from './panelHtml';

const TOKEN_KEY = 'altrobyte.cloudToken';
const EMAIL_KEY = 'altrobyte.email';

/** Everything the extension does, in one place so it can be started, stopped and tested. */
export class Controller implements vscode.WebviewViewProvider {
  running: RunningHelper | null = null;
  client: HelperClient | null = null;
  helperError: string | null = null;
  starting = false;
  private view: vscode.WebviewView | undefined;
  private events: { abort: () => void } | null = null;
  private settings: any = null;
  private monitorTimer: NodeJS.Timeout | undefined;
  private diagTimer: NodeJS.Timeout | undefined;
  private voiceWarned = false;
  private visualPanel: vscode.WebviewPanel | undefined;

  constructor(private ctx: vscode.ExtensionContext, private output: vscode.OutputChannel) {}

  // ── the webview ──────────────────────────────────────────────────────────

  resolveWebviewView(view: vscode.WebviewView): void {
    this.view = view;
    view.webview.options = { enableScripts: true };
    const nonce = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
    view.webview.html = panelHtml(nonce, view.webview.cspSource);
    view.webview.onDidReceiveMessage((m) => this.onWebviewMessage(m).catch((e) => this.fail(e)));
    view.onDidDispose(() => {
      this.view = undefined;
      this.stopMonitorPolling();
    });
  }

  private post(message: unknown) {
    void this.view?.webview.postMessage(message);
  }

  private fail(e: unknown) {
    const msg = e instanceof HelperError ? e.message : (e as Error).message ?? String(e);
    this.output.appendLine(`error: ${msg}`);
    this.post({ type: 'error', text: msg });
  }

  async publishStatus() {
    const email = this.ctx.globalState.get<string>(EMAIL_KEY);
    const token = await this.ctx.secrets.get(TOKEN_KEY);
    this.post({
      type: 'status',
      helper: this.running ? 'running' : this.starting ? 'starting' : 'down',
      error: this.helperError,
      signedIn: token ? email ?? 'your account' : null,
      settings: this.settings,
    });
  }

  private async onWebviewMessage(m: any) {
    switch (m.type) {
      case 'ready':
        if (!this.running && !this.starting) {
          void this.startHelper();
        }
        return this.publishStatus();
      case 'signIn':
        return this.signIn();
      case 'start':
        return this.startSession();
      case 'chooseModule':
        return this.startModuleLab();
      case 'send':
        return this.send(String(m.text ?? ''));
      case 'connector':
        return this.setConnector(String(m.id), !!m.on);
      case 'chooseProject':
        return this.chooseProject();
      case 'speak':
        return this.updateSettings({ speak: { enabled: !!m.on } });
      case 'audit':
        return this.showAudit();
      case 'checkOffline':
        return this.checkOffline();
      case 'monitor':
        return this.monitor(m.action === 'start' ? 'start' : 'stop');
    }
  }

  // ── the helper ───────────────────────────────────────────────────────────

  private findHelperDir(): string | null {
    const cfg = vscode.workspace.getConfiguration('altrobyte').get<string>('helperDir', '').trim();
    const candidates = [
      cfg,
      path.join(this.ctx.extensionPath, 'runtime', 'helper'), // carried inside the extension: nothing for the learner to install
      path.join(this.ctx.globalStorageUri.fsPath, 'runtime', 'helper'),
      path.join(this.ctx.extensionPath, '..', '..', 'altrocoach-backend', 'helper'), // a development checkout next to this repo
    ].filter(Boolean);
    return candidates.find((d) => fs.existsSync(path.join(d, 'altrobyte_helper', '__main__.py'))) ?? null;
  }

  /** Joins the helper running on this computer (the desktop app may have started it) or starts one.
   *  `restart` ends the running one first. */
  async startHelper(restart = false): Promise<void> {
    if (this.starting) {
      return;
    }
    this.starting = true;
    this.helperError = null;
    const before = this.running;
    await this.stopHelper();
    if (restart && before) {
      await shutdownHelper(before.info, helperHome());
    }
    await this.publishStatus();
    try {
      const dir = this.findHelperDir();
      if (!dir) {
        throw new Error('The Altrobyte helper was not found. Set "altrobyte.helperDir" to the folder that contains altrobyte_helper (see the helper README).');
      }
      const bundledPython = path.join(this.ctx.extensionPath, 'runtime', 'python', 'python.exe');
      const python = choosePython(vscode.workspace.getConfiguration('altrobyte').get<string>('helperPython', 'python'),
        fs.existsSync(bundledPython) ? bundledPython : null);
      this.running = await connectHelper({ python, helperDir: dir, onLog: (l) => this.output.appendLine(`[helper] ${l}`) });
      this.running.proc?.on('exit', (code) => {
        if (this.running) {
          this.running = null;
          this.client = null;
          this.helperError = `The helper stopped (exit ${code}). Use "Altrobyte: Restart the helper".`;
          void this.publishStatus();
        }
      });
      this.client = new HelperClient(this.running.info);
      this.output.appendLine(`helper ${this.running.info.version} on 127.0.0.1:${this.running.info.port} (${this.running.attached ? 'joined the one already running' : 'started by this window'})`);
      await this.configureHelper();
      const sub = this.client.events((k, d) => this.onHelperEvent(k, d).catch((e) => this.fail(e)), (why) => {
        if (why !== 'aborted') {
          this.output.appendLine(`event stream ended: ${why}`);
          // The helper ended (it was restarted from another app, or it timed out while this window was idle).
          // Join or start the one that is running now, once, instead of leaving a dead panel.
          if (this.running && !this.starting) {
            setTimeout(() => void this.startHelper(), 800);
          }
        }
      });
      this.events = sub;
      await sub.ready;
    } catch (e) {
      this.helperError = (e as Error).message;
      this.output.appendLine(`could not start the helper: ${this.helperError}`);
    } finally {
      this.starting = false;
      await this.publishStatus();
    }
  }

  /** A ready folder under Documents, so a learner never has to find or pick one to begin. */
  private makeStarterFolder(): string | undefined {
    try {
      const dir = starterFolderPath(process.env.USERPROFILE || os.homedir());
      fs.mkdirSync(dir, { recursive: true });
      return dir;
    } catch {
      return undefined;
    }
  }

  private pioAsked = false;

  /** Building and uploading go through PlatformIO. If it is not on this computer, offer to install it once, in one click. */
  private async offerPlatformIO(): Promise<void> {
    if (this.pioAsked) {
      return;
    }
    const extension = !!vscode.extensions.getExtension('platformio.platformio-ide');
    const core = fs.existsSync(path.join(os.homedir(), '.platformio'));
    if (!needsPlatformIO(extension, core)) {
      return;
    }
    this.pioAsked = true;
    const pick = await vscode.window.showInformationMessage(
      'Building and uploading to your board needs the PlatformIO IDE extension. Install it now? It takes a few minutes the first time.',
      'Install PlatformIO',
      'Not now',
    );
    if (pick === 'Install PlatformIO') {
      await vscode.commands.executeCommand('workbench.extensions.installExtension', 'platformio.platformio-ide');
    }
  }

  async stopHelper() {
    this.events?.abort();
    this.events = null;
    this.stopMonitorPolling();
    const r = this.running;
    this.running = null;
    this.client = null;
    r?.detach(); // never end a helper other apps may be using; it ends itself when nobody is connected
  }

  /** Tell a freshly started helper everything the editor knows. */
  private async configureHelper() {
    const c = this.client!;
    const cfg = vscode.workspace.getConfiguration('altrobyte');
    const token = await this.ctx.secrets.get(TOKEN_KEY);
    if (token) {
      await c.post('/session/auth', { token });
    }
    const patch: any = { api_base: cfg.get<string>('apiBase') };
    this.settings = await c.get('/settings');
    const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    // A learner needs a folder to work in. Use the one they opened, else make the starter folder (the desktop app starts in the
    // same one). A folder chosen earlier that has since been deleted is replaced too, instead of failing later.
    const current = this.settings.project_dir as string | undefined;
    if (!current || !fs.existsSync(current)) {
      patch.project_dir = folder ?? this.makeStarterFolder();
    }
    this.settings = await c.put('/settings', patch);
    await this.pushEnvironment();
  }

  private async pushEnvironment() {
    if (!this.client) {
      return;
    }
    const pio = vscode.extensions.getExtension('platformio.platformio-ide');
    const software: Record<string, string> = { vscode: vscode.version };
    if (pio?.packageJSON?.version) {
      software['platformio-ide'] = String(pio.packageJSON.version);
    }
    const root = this.settings?.project_dir as string | undefined;
    const diagnostics = root
      ? mapDiagnostics(
          vscode.languages.getDiagnostics().map(([uri, ds]) => ({
            file: uri.fsPath,
            diagnostics: ds.map((d) => ({ line: d.range.start.line, severity: d.severity, message: d.message })),
          })),
          root,
        )
      : [];
    await this.client.post('/environment', { software, diagnostics }).catch(() => undefined);
  }

  /** The editor's own errors go to the helper, so the trainer sees exactly what the learner sees. */
  watchDiagnostics(): vscode.Disposable {
    return vscode.languages.onDidChangeDiagnostics(() => {
      clearTimeout(this.diagTimer);
      this.diagTimer = setTimeout(() => void this.pushEnvironment(), 800);
    });
  }

  // ── events from the helper ───────────────────────────────────────────────

  private async onHelperEvent(kind: string, data: any) {
    switch (kind) {
      case 'approval_request':
        return this.askApproval(data);
      case 'message':
        this.post({ type: 'message', text: data.text });
        return this.speak(data.text);
      case 'error':
        return this.post({ type: 'error', text: describeError(data), kind: data.kind });
      case 'turn_done':
        return this.post({ type: 'turn', waiting: data.waiting, finished: data.finished });
      case 'state':
      case 'activity':
        return this.post({ type: kind, ...(kind === 'state' ? { state: data } : { text: data.text }) });
      case 'ui':
        return this.showInteractive(data);
      case 'open_file':
        return this.openFile(String(data.path), data.line);
    }
  }

  /** The assistant points at a line: show it, so the learner never has to hunt for where to type. */
  private async openFile(file: string, line: unknown) {
    const root = this.settings?.project_dir as string | undefined;
    if (!root || !fs.existsSync(file) || !path.resolve(file).toLowerCase().startsWith(path.resolve(root).toLowerCase())) {
      return;                                                  // only ever files inside the project the learner chose
    }
    const at = new vscode.Position(editorLine(line), 0);
    const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(file));
    await vscode.window.showTextDocument(doc, { selection: new vscode.Range(at, at), preview: false, viewColumn: vscode.ViewColumn.One });
    await vscode.commands.executeCommand('revealLine', { lineNumber: at.line, at: 'center' });
  }

  /** Pictures open beside the editor; the pin form lives in the chat. */
  private async showInteractive(ui: { type: string; props?: any }) {
    if (ui.type === 'pin_map') {
      return this.post({ type: 'pinmap' });
    }
    if (ui.type === 'quiz') {
      return this.askQuiz(ui.props ?? {});
    }
    const props = ui.props ?? {};
    const body = ui.type === 'wiring_diagram' ? String(props.svg ?? '') : ui.type === 'visual' ? String(props.html ?? '') : '';
    if (!body) {
      return;
    }
    const title = String(props.title || (ui.type === 'wiring_diagram' ? 'How to connect it' : 'Picture'));
    if (!this.visualPanel) {
      this.visualPanel = vscode.window.createWebviewPanel('altrobyteVisual', title, { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true }, { enableScripts: false });
      this.visualPanel.onDidDispose(() => (this.visualPanel = undefined));
    }
    this.visualPanel.title = title;
    this.visualPanel.webview.html = visualPage(title, body);
    this.visualPanel.reveal(vscode.ViewColumn.Beside, true);
    this.post({ type: 'system', text: `Opened a picture beside your editor: ${title}` });
  }

  /** A quick question from the trainer, as VS Code's own picker. The lesson, not the model, decides if the choice is right. */
  private async askQuiz(props: { milestone?: string; question?: string; options?: string[] }) {
    const options = Array.isArray(props.options) ? props.options.map(String) : [];
    if (!props.milestone || options.length < 2) {
      return;
    }
    const picked = await vscode.window.showQuickPick(options, { title: 'Quick question', placeHolder: String(props.question ?? ''), ignoreFocusOut: true });
    if (picked === undefined) {
      return;                                                  // dismissed: the trainer will ask again in the chat
    }
    this.post({ type: 'system', text: `You chose: ${picked}` });
    await this.send(quizAnswerText(String(props.milestone), options.indexOf(picked)));
  }

  /** The learner is asked, every time, before anything is built or uploaded. */
  private async askApproval(req: { id: string; title: string; detail: string }) {
    const choice = await vscode.window.showWarningMessage(req.title, { modal: true, detail: req.detail }, 'Allow');
    try {
      await this.client?.post(`/approvals/${req.id}`, { allow: choice === 'Allow' });
    } catch {
      /* the question had already timed out; the answer was "no" */
    }
  }

  private async speak(text: string) {
    if (!this.client || !this.settings?.speak?.enabled) {
      return;
    }
    try {
      const wav = await this.client.audio(text);
      this.post({ type: 'audio', data: 'data:audio/wav;base64,' + wav.toString('base64') });
    } catch (e) {
      if (!this.voiceWarned) {
        this.voiceWarned = true;
        this.post({ type: 'system', text: `Voice is not available: ${(e as Error).message}` });
      }
    }
  }

  // ── actions ──────────────────────────────────────────────────────────────

  private apiBase(): string {
    return vscode.workspace.getConfiguration('altrobyte').get<string>('apiBase', '').replace(/\/+$/, '');
  }

  private async callApi(path: string, payload: object): Promise<{ ok: boolean; status: number; body: any } | undefined> {
    try {
      const res = await fetch(`${this.apiBase()}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      return { ok: res.ok, status: res.status, body: await res.json().catch(() => ({})) };
    } catch {
      this.post({ type: 'error', text: describeError({ kind: 'offline' }) });
      return undefined;
    }
  }

  private async finishSignIn(token: string, who: string): Promise<void> {
    await this.ctx.secrets.store(TOKEN_KEY, token);
    await this.ctx.globalState.update(EMAIL_KEY, who);
    await this.client?.post('/session/auth', { token });
    await this.publishStatus();
  }

  async signIn(): Promise<void> {
    const pick = await vscode.window.showQuickPick(
      [
        { label: 'I am a learner', description: 'Sign in with your WhatsApp number (OTP)', learner: true },
        { label: 'I am an educator', description: 'Sign in with email and password', learner: false },
      ],
      { placeHolder: 'How do you sign in to Altrobyte?', ignoreFocusOut: true },
    );
    if (!pick) {
      return;
    }
    return pick.learner ? this.signInLearner() : this.signInEducator();
  }

  private async signInLearner(): Promise<void> {
    const phone = await vscode.window.showInputBox({ prompt: 'Your WhatsApp number (with country code, e.g. 919876543210)', ignoreFocusOut: true, value: this.ctx.globalState.get<string>(EMAIL_KEY) });
    if (!phone) {
      return;
    }
    let name: string | undefined;
    let sent = await this.callApi('/student/standalone/request-otp', { phone });
    if (!sent) {
      return;
    }
    if (sent.status === 422 || sent.status === 404) {
      name = await vscode.window.showInputBox({ prompt: 'New here! Your name', ignoreFocusOut: true });
      if (!name) {
        return;
      }
      sent = await this.callApi('/student/standalone/request-otp', { phone, name });
      if (!sent) {
        return;
      }
    }
    if (!sent.ok) {
      this.post({ type: 'error', text: typeof sent.body.detail === 'string' ? sent.body.detail : 'Could not send the OTP. Check the number.' });
      return;
    }
    const otp = await vscode.window.showInputBox({ prompt: 'Enter the OTP sent on WhatsApp', ignoreFocusOut: true });
    if (!otp) {
      return;
    }
    const done = await this.callApi('/student/standalone/verify-otp', name ? { phone, otp, name } : { phone, otp });
    const token = done?.body.token ?? done?.body.jwt_token;
    if (!done) {
      return;
    }
    if (!done.ok || !token) {
      this.post({ type: 'error', text: typeof done.body.detail === 'string' ? done.body.detail : 'That OTP did not work. Try again.' });
      return;
    }
    await this.finishSignIn(token, phone);
  }

  private async signInEducator(): Promise<void> {
    const email = await vscode.window.showInputBox({ prompt: 'Your Altrobyte email', ignoreFocusOut: true });
    if (!email) {
      return;
    }
    const password = await vscode.window.showInputBox({ prompt: 'Your Altrobyte password', password: true, ignoreFocusOut: true });
    if (!password) {
      return;
    }
    const res = await this.callApi('/auth/login', { email, password });
    if (!res) {
      return;
    }
    const token = res.body.token ?? res.body.jwt_token;
    if (!res.ok || !token) {
      this.post({ type: 'error', text: typeof res.body.detail === 'string' ? res.body.detail : 'Sign-in failed. Check your email and password.' });
      return;
    }
    await this.finishSignIn(token, email);
  }

  async signOut(): Promise<void> {
    await this.client?.post('/session/end').catch(() => undefined);
    await this.client?.post('/session/auth', { token: '' }).catch(() => undefined);
    await this.ctx.secrets.delete(TOKEN_KEY);
    await this.publishStatus();
  }

  /** Pick one of the experiments the teachers have switched on (each made from a note of a module), and run it. */
  async startModuleLab(): Promise<void> {
    const base = vscode.workspace.getConfiguration('altrobyte').get<string>('apiBase', '').replace(/\/+$/, '');
    let labs: { id: number; title: string; module_title: string }[] = [];
    try {
      const res = await fetch(`${base}/ai-labs`);
      labs = ((await res.json()) as any).labs ?? [];
    } catch {
      this.post({ type: 'error', text: describeError({ kind: 'offline' }) });
      return;
    }
    if (!labs.length) {
      this.post({ type: 'system', text: 'None of your modules has an AI Lab experiment yet.' });
      return;
    }
    const pick = await vscode.window.showQuickPick(
      labs.map((l) => ({ label: l.title, description: l.module_title, id: l.id })),
      { placeHolder: 'Which experiment do you want to do?', matchOnDescription: true },
    );
    if (pick) {
      await this.startSession({ labId: pick.id });
    }
  }

  /** A link from the Altrobyte app ("Start in VS Code"). Anything on the web can open a link, so the learner confirms first. */
  async handleLink(uri: vscode.Uri): Promise<void> {
    const link = labLink(uri.path, uri.query);
    if (link === null) {
      return;
    }
    const ok = await vscode.window.showInformationMessage('Start the AI Lab experiment from your Altrobyte module?', { modal: true }, 'Start');
    if (ok === 'Start') {
      await vscode.commands.executeCommand('altrobyte.trainer.focus');
      await this.startSession({ labId: link.lab, moduleId: link.module });
    }
  }

  async startSession(what: { labId?: number; moduleId?: number } = {}): Promise<void> {
    if (!this.client) {
      await this.startHelper();
    }
    if (!(await this.ctx.secrets.get(TOKEN_KEY))) {
      await this.signIn();
    }
    if (!(await this.ctx.secrets.get(TOKEN_KEY)) || !this.client) {
      this.post({ type: 'error', text: 'Sign in first, then start the session.' });
      return;
    }
    await this.client.post('/session/auth', { token: await this.ctx.secrets.get(TOKEN_KEY) });
    this.voiceWarned = false;
    void this.offerPlatformIO(); // does not hold the session back: the learner can answer while the trainer says hello
    try {
      const body = what.labId !== undefined ? { lab_id: what.labId } : what.moduleId !== undefined ? { module_id: what.moduleId } : undefined;
      await this.client.post('/session/start', body);
    } catch (e) {
      this.fail(e);
    }
  }

  private async send(text: string) {
    try {
      await this.client?.post('/session/chat', { text });
    } catch (e) {
      this.fail(e);
    }
  }

  private async updateSettings(patch: any) {
    if (!this.client) {
      return;
    }
    this.settings = await this.client.put('/settings', patch);
    this.post({ type: 'settings', settings: this.settings });
  }

  private async setConnector(id: string, on: boolean) {
    const grants = new Set<string>(this.settings?.grants ?? []);
    on ? grants.add(id) : grants.delete(id);
    await this.updateSettings({ grants: [...grants] });
  }

  async chooseProject(): Promise<void> {
    const picked = await vscode.window.showOpenDialog({ canSelectFolders: true, canSelectFiles: false, canSelectMany: false, openLabel: 'Use this project folder' });
    if (picked?.[0]) {
      await this.updateSettings({ project_dir: picked[0].fsPath });
      await this.pushEnvironment();
    }
  }

  async showAudit(): Promise<void> {
    if (!this.client) {
      vscode.window.showInformationMessage('The helper is not running.');
      return;
    }
    const { entries } = await this.client.get('/audit?limit=200');
    const doc = await vscode.workspace.openTextDocument({ content: formatAudit(entries), language: 'plaintext' });
    await vscode.window.showTextDocument(doc, { preview: true });
  }

  /** The checks that run on this computer, with no internet and no AI, in mission order, stopping at the first that fails. */
  private async checkOffline() {
    if (!this.client) {
      return;
    }
    await this.pushEnvironment();
    const results: { title: string; passed: boolean; evidence: string }[] = [];
    let ids: string[] | null = null;
    let titles: Record<string, string> = {};
    let done: Record<string, boolean> = {};
    const first = await this.client.post('/verify', { milestone: 'toolchain_ready' });
    done = first.done;
    titles = first.titles ?? {};
    ids = Object.keys(done);
    for (const id of ids) {
      if (done[id]) {
        results.push({ title: titles[id] ?? id, passed: true, evidence: '' });
        continue;
      }
      const r = id === 'toolchain_ready' ? first : await this.client.post('/verify', { milestone: id });
      if (r.error === 'needs_learner_confirmation') {
        continue; // wiring and dashboards are confirmed by you, not by a program
      }
      if (r.error) {
        results.push({ title: titles[id] ?? id, passed: false, evidence: r.error === 'prerequisites_not_met' ? 'needs an earlier step first' : r.say ?? r.error });
        break;
      }
      const passed = !!r.passed;
      results.push({ title: titles[id] ?? id, passed, evidence: passed ? '' : r.untrusted?.evidence ?? '' });
      if (!passed) {
        break;
      }
    }
    this.post({ type: 'verify', results });
  }

  private async monitor(action: 'start' | 'stop') {
    if (!this.client) {
      return;
    }
    if (action === 'start') {
      const { status } = await this.client.post('/monitor/start');
      this.post({ type: 'monitor', running: false, lines: [], status });
      this.startMonitorPolling();
    } else {
      await this.client.post('/monitor/stop');
      this.stopMonitorPolling();
      this.post({ type: 'monitor', running: false, lines: [], status: 'stopped' });
    }
  }

  private startMonitorPolling() {
    this.stopMonitorPolling();
    this.monitorTimer = setInterval(async () => {
      try {
        const m = await this.client!.get('/monitor?n=40');
        this.post({ type: 'monitor', ...m });
      } catch {
        /* helper gone: the status line will say so */
      }
    }, 1500);
  }

  private stopMonitorPolling() {
    clearInterval(this.monitorTimer);
    this.monitorTimer = undefined;
  }

  dispose() {
    clearTimeout(this.diagTimer);
    this.stopMonitorPolling();
    return this.stopHelper();
  }
}

export function activate(ctx: vscode.ExtensionContext) {
  const output = vscode.window.createOutputChannel('Altrobyte Trainer');
  const controller = new Controller(ctx, output);
  ctx.subscriptions.push(
    output,
    vscode.window.registerWebviewViewProvider('altrobyte.trainer', controller, { webviewOptions: { retainContextWhenHidden: true } }),
    controller.watchDiagnostics(),
    vscode.window.registerUriHandler({ handleUri: (uri) => controller.handleLink(uri) }),
    vscode.commands.registerCommand('altrobyte.signIn', () => controller.signIn()),
    vscode.commands.registerCommand('altrobyte.signOut', () => controller.signOut()),
    vscode.commands.registerCommand('altrobyte.startSession', async () => {
      await vscode.commands.executeCommand('altrobyte.trainer.focus');
      await controller.startSession();
    }),
    vscode.commands.registerCommand('altrobyte.startModuleLab', async () => {
      await vscode.commands.executeCommand('altrobyte.trainer.focus');
      await controller.startModuleLab();
    }),
    vscode.commands.registerCommand('altrobyte.chooseProject', () => controller.chooseProject()),
    vscode.commands.registerCommand('altrobyte.showAudit', () => controller.showAudit()),
    vscode.commands.registerCommand('altrobyte.restartHelper', () => controller.startHelper(true)),
    { dispose: () => void controller.dispose() },
  );
  return { controller }; // exposed so the tests that run inside VS Code can reach it
}

export async function deactivate() {
  /* disposal of the helper happens through ctx.subscriptions */
}
