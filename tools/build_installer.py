"""Packs the built desktop app (with its helper runtime) into one installer a learner double-clicks.

    python tools/build_desktop.py          # the app + runtime, into desktop_app/build/.../Release
    python tools/build_installer.py        # dist/AltrobyteTrainerSetup.exe + dist/desktop.json

Needs Inno Setup 6 (winget install JRSoftware.InnoSetup). The installer needs no admin rights and installs per user.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASE = ROOT / "desktop_app" / "build" / "windows" / "x64" / "runner" / "Release"
DIST = ROOT / "dist"
NAME = "AltrobyteTrainerSetup.exe"


def find_iscc() -> str:
    for base in (os.environ.get("LOCALAPPDATA", ""), os.environ.get("ProgramFiles(x86)", ""), os.environ.get("ProgramFiles", "")):
        p = Path(base) / "Programs" / "Inno Setup 6" / "ISCC.exe" if "Local" in base else Path(base) / "Inno Setup 6" / "ISCC.exe"
        if p.exists():
            return str(p)
    sys.exit("Inno Setup 6 was not found. Install it: winget install JRSoftware.InnoSetup")


def version() -> str:
    m = re.search(r"^version:\s*([0-9.]+)", (ROOT / "desktop_app" / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else "1.0.0"


def main() -> None:
    if not (RELEASE / "altrobyte_trainer.exe").exists() or not (RELEASE / "runtime" / "python" / "python.exe").exists():
        sys.exit("The app is not built with its runtime. Run: python tools/build_desktop.py")
    DIST.mkdir(exist_ok=True)
    v = version()
    subprocess.run([find_iscc(), f"/DAppVersion={v}", f"/DSourceDir={RELEASE}", f"/DOutDir={DIST}", str(ROOT / "tools" / "installer.iss")], check=True)
    exe = DIST / NAME
    data = exe.read_bytes()
    info = {"version": v, "file": NAME, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    (DIST / "desktop.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    print(f"built {exe} v{v}, {len(data) / 1e6:.0f} MB, sha256 {info['sha256'][:16]}...")


if __name__ == "__main__":
    main()
