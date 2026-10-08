"""Builds the Windows desktop app together with the helper runtime, ready to run or to zip.

    python tools/build_desktop.py                 # build into desktop_app/build/.../Release
    python tools/build_desktop.py --to "C:\\Users\\me\\Desktop\\Altrobyte Trainer"      # and copy it there

The helper (a private Python, its packages, the helper and the trainer engine) is built by vscode_extension/tools/build_runtime.py
and shipped inside the app folder as `runtime/`, which is where the app looks for it. Nothing else has to be installed.
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "desktop_app"
RELEASE = APP / "build" / "windows" / "x64" / "runner" / "Release"
RUNTIME = ROOT / "vscode_extension" / "runtime"


def run(cmd, cwd):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    subprocess.run(cmd, cwd=str(cwd), check=True, shell=sys.platform == "win32")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--to", help="copy the finished app into this folder (replaces what is there)")
    args = ap.parse_args()

    if not (RUNTIME / "python" / "python.exe").exists():
        run([sys.executable, str(ROOT / "vscode_extension" / "tools" / "build_runtime.py")], ROOT)
    run([sys.executable, str(ROOT / "tools" / "sync_desktop_app.py")], ROOT)
    run(["flutter", "build", "windows", "--release"], APP)

    target = RELEASE / "runtime"
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(RUNTIME, target)
    exe = RELEASE / "altrobyte_trainer.exe"
    if not exe.exists():
        sys.exit("the build did not produce altrobyte_trainer.exe")
    size = sum(f.stat().st_size for f in RELEASE.rglob("*") if f.is_file()) / 1e6
    print(f"built {exe} ({size:.0f} MB with the helper runtime)")

    if args.to:
        dest = Path(args.to)
        dest.mkdir(parents=True, exist_ok=True)
        for item in RELEASE.iterdir():
            tgt = dest / item.name
            if item.is_dir():
                if tgt.exists():
                    shutil.rmtree(tgt)
                shutil.copytree(item, tgt)
            else:
                shutil.copy2(item, tgt)
        print("copied to", dest)


if __name__ == "__main__":
    main()
