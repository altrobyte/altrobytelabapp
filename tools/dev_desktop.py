"""Run the desktop app straight from the source, for testing. No installer, no install.

    python tools\\dev_desktop.py            # start the app (debug mode); press r in this window to reload after a change
    python tools\\dev_desktop.py --release  # the fast, final-speed build, started once (no reload)

What it does, each time:
  1. copies the newest helper and trainer code into the runtime the app uses, and stops a helper that is already running
     (the VS Code extension's, or an older one), so the app always talks to the code you are testing;
  2. copies the app's code into desktop_app/ and keeps doing so while it runs, so `r` picks up the latest change;
  3. starts the app with Flutter.

If Flutter says a plugin folder "is not an existing directory", open the terminal with "Run as administrator" (or restart
Windows): that is a Windows state, not a problem in the code.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "desktop_app"
RUNTIME = ROOT / "vscode_extension" / "runtime"
BACKEND = ROOT.parent / "altrocoach-backend"
SYNC = ROOT / "tools" / "sync_desktop_app.py"


def helper_home() -> Path:
    if os.environ.get("ALTROBYTE_HOME"):
        return Path(os.environ["ALTROBYTE_HOME"])
    return Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "Altrobyte"


def stop_running_helper() -> bool:
    """Ask the helper that is running (whoever started it) to end, so the app starts the one being tested."""
    try:
        info = json.loads((helper_home() / "helper.json").read_text(encoding="utf-8"))
        req = urllib.request.Request(f"http://127.0.0.1:{info['port']}/shutdown", method="POST", data=b"{}",
                                     headers={"Authorization": f"Bearer {info['token']}", "Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=3).read()
        time.sleep(1.5)
        return True
    except Exception:       # noqa: BLE001 - none running, or already gone
        return False


def refresh_helper_code() -> None:
    """The helper and the trainer engine, as they are in the backend folder right now."""
    if not (RUNTIME / "python" / "python.exe").exists():
        print("+ building the runtime (first time only)", flush=True)
        subprocess.run([sys.executable, str(ROOT / "vscode_extension" / "tools" / "build_runtime.py")], check=True)
        return
    ignore = shutil.ignore_patterns("__pycache__", "*.pyc", "tests")
    for src, dst in ((BACKEND / "helper" / "altrobyte_helper", RUNTIME / "helper" / "altrobyte_helper"), (BACKEND / "trainer", RUNTIME / "trainer")):
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst, ignore=ignore)


def sync(quiet: bool = True) -> None:
    subprocess.run([sys.executable, str(SYNC)], cwd=str(ROOT), check=not quiet,
                   stdout=subprocess.DEVNULL if quiet else None, stderr=subprocess.DEVNULL if quiet else None)


def keep_synced(stop: threading.Event) -> None:
    while not stop.wait(2.0):
        sync()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", action="store_true", help="run the optimised build (no reload)")
    args = ap.parse_args()

    if stop_running_helper():
        print("+ stopped the helper that was running", flush=True)
    refresh_helper_code()
    print("+ helper and trainer code refreshed", flush=True)
    sync(quiet=False)

    env = dict(os.environ, ALTROBYTE_RUNTIME=str(RUNTIME))          # the app uses this runtime instead of an installed one
    stop = threading.Event()
    threading.Thread(target=keep_synced, args=(stop,), daemon=True).start()
    cmd = ["flutter", "run", "-d", "windows"] + (["--release"] if args.release else [])
    print("+ " + " ".join(cmd) + ("" if args.release else "   (press r to reload after a change, q to quit)"), flush=True)
    try:
        subprocess.run(cmd, cwd=str(APP), env=env, shell=sys.platform == "win32")
    finally:
        stop.set()


if __name__ == "__main__":
    main()
