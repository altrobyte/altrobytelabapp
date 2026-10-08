import { CONNECTORS } from './logic';

/** The trainer panel. Uses the editor's own theme colours, so it looks native in light and dark. */
export function panelHtml(nonce: string, cspSource: string): string {
  const connectors = JSON.stringify(CONNECTORS);
  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}'; media-src data:;">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: var(--vscode-font-family); font-size: var(--vscode-font-size); color: var(--vscode-foreground); padding: 0; margin: 0; display: flex; flex-direction: column; height: 100vh; }
  button { font-family: inherit; cursor: pointer; border: 1px solid var(--vscode-button-border, transparent); border-radius: 2px; padding: 4px 10px;
           background: var(--vscode-button-background); color: var(--vscode-button-foreground); }
  button:hover { background: var(--vscode-button-hoverBackground); }
  button.secondary { background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground); }
  button:disabled { opacity: .5; cursor: default; }
  input[type=text] { flex: 1; font-family: inherit; padding: 5px 8px; background: var(--vscode-input-background); color: var(--vscode-input-foreground); border: 1px solid var(--vscode-input-border, transparent); border-radius: 2px; }
  #top { padding: 8px 10px; border-bottom: 1px solid var(--vscode-panel-border); display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  #status { flex: 1; font-size: 12px; opacity: .85; min-width: 120px; }
  #banner { display: none; padding: 8px 10px; font-size: 12px; background: var(--vscode-inputValidation-warningBackground); border-bottom: 1px solid var(--vscode-inputValidation-warningBorder); }
  #chat { flex: 1; overflow-y: auto; padding: 10px; }
  .msg { max-width: 92%; margin: 6px 0; padding: 7px 10px; border-radius: 8px; line-height: 1.45; white-space: pre-wrap; word-wrap: break-word; }
  .trainer { background: var(--vscode-editor-inactiveSelectionBackground); }
  .learner { background: var(--vscode-button-background); color: var(--vscode-button-foreground); margin-left: auto; }
  .system { font-size: 12px; font-style: italic; opacity: .75; }
  #activity { font-size: 12px; opacity: .8; padding: 0 10px 4px; min-height: 16px; }
  #composer { display: flex; gap: 6px; padding: 8px 10px; border-top: 1px solid var(--vscode-panel-border); }
  details { border-top: 1px solid var(--vscode-panel-border); padding: 6px 10px; }
  summary { cursor: pointer; font-weight: 600; padding: 3px 0; }
  .row { display: flex; align-items: flex-start; gap: 6px; margin: 4px 0; font-size: 12px; }
  .row small { opacity: .7; display: block; }
  .ms { margin: 3px 0; font-size: 12px; } .ms .done { color: var(--vscode-testing-iconPassed); } .ms .lock { opacity: .55; }
  pre { margin: 4px 0; padding: 6px; background: var(--vscode-textCodeBlock-background); font-size: 11px; max-height: 140px; overflow: auto; white-space: pre-wrap; }
  .tiny { font-size: 11px; opacity: .7; }
</style></head>
<body>
  <div id="top">
    <div id="status">Starting…</div>
    <button id="signIn" class="secondary" style="display:none">Sign in</button>
    <button id="start" disabled>Start session</button>
    <label class="tiny" title="Read the trainer's replies aloud"><input type="checkbox" id="speak"> 🔊</label>
  </div>
  <div id="banner"></div>
  <div id="chat"></div>
  <div id="activity"></div>
  <div id="composer"><input type="text" id="input" placeholder="Reply to the trainer…" disabled><button id="send" disabled>Send</button></div>
  <details open><summary>Progress <span id="count" class="tiny"></span></summary><div id="progress" class="tiny">Start a session to see your milestones.</div>
    <div style="margin-top:6px"><button id="offline" class="secondary">Check my progress (no internet needed)</button></div><div id="offlineOut"></div></details>
  <details><summary>What the trainer may look at</summary><div id="connectors"></div>
    <div class="row"><span>Project folder:</span><code id="folder" style="flex:1;word-break:break-all"></code><button id="chooseProject" class="secondary">Choose</button></div></details>
  <details><summary>Serial monitor</summary><div class="row"><button id="monStart" class="secondary">Start</button><button id="monStop" class="secondary">Stop</button><span id="monInfo" class="tiny"></span></div><pre id="monLines">(nothing yet)</pre></details>
  <details><summary>Privacy</summary><div class="tiny">Your code stays on this computer. Passwords and keys are hidden before anything is sent.</div>
    <div style="margin-top:6px"><button id="audit" class="secondary">Show what the trainer did and what was sent</button></div></details>
<script nonce="${nonce}">
  const vscode = acquireVsCodeApi();
  const CONNECTORS = ${connectors};
  const $ = (id) => document.getElementById(id);
  const chat = $('chat');
  let settings = null, session = false, busy = false, signedIn = false, helperUp = false;

  function add(role, text) { const d = document.createElement('div'); d.className = 'msg ' + role; d.textContent = text; chat.appendChild(d); chat.scrollTop = chat.scrollHeight; }
  function refreshControls() {
    $('start').disabled = !helperUp || !signedIn || busy;
    $('start').textContent = session ? 'Restart session' : 'Start session';
    $('input').disabled = !session || busy; $('send').disabled = !session || busy;
    $('signIn').style.display = helperUp && !signedIn ? '' : 'none';
  }
  function renderConnectors() {
    const el = $('connectors'); el.innerHTML = '';
    for (const c of CONNECTORS) {
      const row = document.createElement('label'); row.className = 'row';
      const box = document.createElement('input'); box.type = 'checkbox'; box.checked = !!(settings && settings.grants.includes(c.id));
      box.onchange = () => vscode.postMessage({ type: 'connector', id: c.id, on: box.checked });
      const txt = document.createElement('span'); txt.innerHTML = '<b></b><small></small>'; txt.firstChild.textContent = c.label; txt.lastChild.textContent = c.help;
      row.append(box, txt); el.appendChild(row);
    }
    $('folder').textContent = (settings && settings.project_dir) || 'not chosen yet';
    $('speak').checked = !!(settings && settings.speak && settings.speak.enabled);
  }
  function renderProgress(state) {
    const el = $('progress'); el.innerHTML = '';
    for (const m of state.progress) {
      const d = document.createElement('div'); d.className = 'ms';
      const icon = m.status === 'done' ? '✓' : m.status === 'blocked' ? '🔒' : '○';
      d.innerHTML = '<span></span> <span></span>'; d.firstChild.className = m.status === 'done' ? 'done' : m.status === 'blocked' ? 'lock' : '';
      d.firstChild.textContent = icon; d.lastChild.textContent = m.title + (m.status === 'done' ? ' (' + (m.kind === 'learner_confirmed' ? 'you confirmed' : 'verified') + ')' : '');
      el.appendChild(d);
    }
    $('count').textContent = state.progress.filter(m => m.status === 'done').length + '/' + state.progress.length;
  }
  function send() { const t = $('input').value.trim(); if (!t || !session || busy) return; add('learner', t); $('input').value = ''; busy = true; refreshControls(); vscode.postMessage({ type: 'send', text: t }); }

  $('send').onclick = send;
  $('input').onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } };
  $('start').onclick = () => { chat.innerHTML = ''; busy = true; session = true; refreshControls(); vscode.postMessage({ type: 'start' }); };
  $('signIn').onclick = () => vscode.postMessage({ type: 'signIn' });
  $('chooseProject').onclick = () => vscode.postMessage({ type: 'chooseProject' });
  $('audit').onclick = () => vscode.postMessage({ type: 'audit' });
  $('offline').onclick = () => { $('offlineOut').textContent = 'Checking…'; vscode.postMessage({ type: 'checkOffline' }); };
  $('monStart').onclick = () => vscode.postMessage({ type: 'monitor', action: 'start' });
  $('monStop').onclick = () => vscode.postMessage({ type: 'monitor', action: 'stop' });
  $('speak').onchange = (e) => vscode.postMessage({ type: 'speak', on: e.target.checked });

  window.addEventListener('message', (ev) => {
    const m = ev.data;
    switch (m.type) {
      case 'status':
        helperUp = m.helper === 'running'; signedIn = !!m.signedIn; settings = m.settings || settings;
        $('status').textContent = m.helper === 'running' ? (signedIn ? 'Signed in as ' + m.signedIn : 'Not signed in') : m.helper === 'starting' ? 'Starting the helper…' : 'The helper is not running';
        const banner = $('banner');
        if (m.helper === 'down') { banner.style.display = 'block'; banner.textContent = m.error || 'The helper could not start.'; } else { banner.style.display = 'none'; }
        renderConnectors(); refreshControls(); break;
      case 'message': add('trainer', m.text); break;
      case 'system': add('system', m.text); break;
      case 'state': renderProgress(m.state); break;
      case 'activity': $('activity').textContent = m.text ? 'The trainer is ' + m.text + '…' : ''; break;
      case 'turn': busy = false; $('activity').textContent = ''; if (m.finished) add('system', 'Mission complete: every milestone is proven.'); refreshControls(); if (!$('input').disabled) $('input').focus(); break;
      case 'error': busy = false; $('activity').textContent = ''; add('system', m.text); if (m.kind === 'gone') session = false; refreshControls(); break;
      case 'audio': { const a = new Audio(m.data); a.play().catch(() => {}); break; }
      case 'verify': $('offlineOut').innerHTML = ''; for (const r of m.results) { const d = document.createElement('div'); d.className = 'ms'; d.textContent = (r.passed ? '✓ ' : '✗ ') + r.title + (r.passed ? '' : ' — ' + r.evidence); $('offlineOut').appendChild(d); } break;
      case 'monitor': $('monInfo').textContent = m.running ? m.port + ' @ ' + m.baud + ' baud' : (m.status || 'stopped'); $('monLines').textContent = m.lines.length ? m.lines.join('\\n') : '(nothing yet)'; break;
      case 'settings': settings = m.settings; renderConnectors(); break;
    }
  });
  vscode.postMessage({ type: 'ready' });
</script></body></html>`;
}
