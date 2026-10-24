"""Altron's hands on the founder's PC (A10, 25 Oct 2026).

The founder tells Altron on the phone "PC par PlatformIO ka naya ESP32 project banao, LED blink"; after a yes, Altron
queues it (backend founder_altron.pc_queue). This agent, running on the PC, takes the task, has Claude Code do it headless
in Documents\\Altrobyte\\projects (new projects, code, opening VS Code), and reports two lines back, which Altron reads out
when asked.

Run:   python tools/altron_pc_agent.py         (or the "Altron PC" shortcut in the Startup folder)
Needs: the founder's app key in %APPDATA%\\Altrobyte\\founder_key.txt, and Claude Code (`claude`) installed and signed in.
Claude Code may edit files and run only pio, platformio, code, git, mkdir and ls: nothing else on the PC.
"""
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.request

API = "https://edu.altrobytelab.com"
HOME = pathlib.Path(os.environ.get("USERPROFILE") or pathlib.Path.home())
WORK = HOME / "Documents" / "Altrobyte" / "projects"
KEY_FILE = pathlib.Path(os.environ.get("APPDATA", HOME)) / "Altrobyte" / "founder_key.txt"
LOG = pathlib.Path(os.environ.get("APPDATA", HOME)) / "Altrobyte" / "pc_agent.log"
ALLOWED = ["Read", "Write", "Edit", "Glob", "Grep",
           "Bash(pio:*)", "Bash(platformio:*)", "Bash(code:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(ls:*)"]
GUIDE = ("\n\nWork inside the current folder (the founder's projects folder); make a new sub-folder for a new project. "
         "For ESP32 or other boards use PlatformIO. When done, open the project in VS Code with `code <folder>`. "
         "Finish with exactly two short lines: what you did, and the folder.")


def log(*a):
    line = time.strftime("%H:%M:%S ") + " ".join(str(x) for x in a)
    print(line, flush=True)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def call(path, body=None, token="", key=""):
    req = urllib.request.Request(API + path, data=json.dumps(body or {}).encode(), method="POST",
                                 headers={"Content-Type": "application/json",
                                          **({"Authorization": "Bearer " + token} if token else {}),
                                          **({"X-Founder-Key": key} if key else {})})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode() or "{}")


def run_claude(task: str) -> tuple:
    WORK.mkdir(parents=True, exist_ok=True)
    exe = "claude.cmd" if os.name == "nt" else "claude"
    cmd = [exe, "-p", task + GUIDE, "--permission-mode", "acceptEdits", "--allowedTools", *ALLOWED]
    try:
        p = subprocess.run(cmd, cwd=str(WORK), capture_output=True, text=True, encoding="utf-8", errors="replace",
                           timeout=20 * 60)
    except FileNotFoundError:
        return False, "Claude Code is not installed on the PC."
    except subprocess.TimeoutExpired:
        return False, "It took more than 20 minutes and was stopped."
    out = (p.stdout or "").strip()
    lines = [l for l in out.splitlines() if l.strip()]
    return p.returncode == 0, ("\n".join(lines[-2:]) if lines else (p.stderr or "no answer")[-400:])


def main():
    if not KEY_FILE.exists():
        sys.exit(f"Put the founder app key in {KEY_FILE} first.")
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    token, token_at = "", 0.0
    log("Altron PC agent is running. Projects folder:", WORK)
    while True:
        try:
            if not token or time.time() - token_at > 3600:
                token, token_at = call("/founder/key-login", key=key)["token"], time.time()
            t = call("/founder/pc/next", token=token).get("task")
            if t:
                log("task", t["id"], ":", t["task"][:120])
                ok, result = run_claude(t["task"])
                call(f"/founder/pc/{t['id']}/done", {"ok": ok, "result": result}, token=token)
                log("done" if ok else "failed", ":", result.replace("\n", " | ")[:200])
                continue
        except Exception as e:      # noqa: BLE001 - offline or the server restarting: try again shortly
            log("waiting:", type(e).__name__)
            token = ""
        time.sleep(6)


if __name__ == "__main__":
    main()
