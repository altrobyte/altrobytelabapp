"""Puts the downloads next to the web build: the VS Code extension and the desktop app installer.

    flutter build web --release --no-wasm-dry-run
    python tools/publish_downloads.py                  # keep exactly what is live now (the usual case)
    python tools/publish_downloads.py --extension      # publish the newly packaged .vsix (a public release: approve first)
    python tools/publish_downloads.py --installer      # publish dist/AltrobyteTrainerSetup.exe (a public release: approve first)
    python tools/publish_downloads.py --team           # put dist/AltrobyteTrainerSetup.exe at downloads/team/ for the team to test
    python tools/check_web_build.py && python stamp_version.py && firebase deploy --only hosting

A deploy replaces the whole site, so a download that is not put back is gone. By default this puts back the very files
that are live (checked by their sha256), and refuses to go on if it cannot: a web change must never silently remove the
download link or publish a version nobody approved.
"""
import argparse
import hashlib
import json
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / "vscode_extension"
DIST = ROOT / "dist"
OUT = ROOT / "build" / "web" / "downloads"
SITE = "https://altrobytelab.com/downloads"
VSIX = "altrobyte-trainer-win32-x64.vsix"
SETUP = "AltrobyteTrainerSetup.exe"


def live(name: str):
    """The live description file, or None when the site has none (it answers with its home page instead)."""
    # Tried three times: one slow answer used to read as "nothing is live", and the build then left the live download out.
    for attempt in range(3):
        try:
            with urllib.request.urlopen(f"{SITE}/{name}", timeout=20) as r:
                return json.loads(r.read().decode("utf-8"))
        except json.JSONDecodeError:
            return None                  # the home page came back: nothing of that name is live
        except Exception:       # noqa: BLE001
            if attempt == 2:
                return None


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put(src: Path, name: str, info_name: str, version: str, out: Path = OUT) -> None:
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, out / name)
    data = (out / name).read_bytes()
    info = {"version": version, "file": name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    (out / info_name).write_text(json.dumps(info, indent=2), encoding="utf-8")
    print(f"{out.relative_to(OUT.parent).as_posix()}/{name} v{version}, {len(data) / 1e6:.1f} MB, sha256 {info['sha256'][:16]}...")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--extension", action="store_true", help="publish the .vsix packaged now (needs approval)")
    ap.add_argument("--installer", action="store_true", help="publish dist/AltrobyteTrainerSetup.exe (needs approval)")
    ap.add_argument("--team", action="store_true", help="put dist/AltrobyteTrainerSetup.exe at downloads/team/ for the team")
    a = ap.parse_args()
    if not (ROOT / "build" / "web" / "index.html").exists():
        sys.exit("build/web does not exist. Run flutter build web first.")
    problems = []

    # The extension
    if a.extension:
        version = json.loads((EXT / "package.json").read_text(encoding="utf-8"))["version"]
        src = EXT / f"altrobyte-trainer-win32-x64-{version}.vsix"
        if not src.exists():
            sys.exit(f"{src.name} not found. Package it first.")
        put(src, VSIX, "latest.json", version)
    else:
        info = live("latest.json")
        if info:
            src = EXT / f"altrobyte-trainer-win32-x64-{info['version']}.vsix"
            if src.exists() and sha(src) == info["sha256"]:
                put(src, VSIX, "latest.json", info["version"])
            else:
                problems.append(f"the live extension v{info['version']} is not on this computer as published (sha256 "
                                f"{info['sha256'][:12]}...): the deploy would remove it")

    # The desktop installer
    if a.installer:
        info = json.loads((DIST / "desktop.json").read_text(encoding="utf-8")) if (DIST / "desktop.json").exists() else None
        if not info or not (DIST / SETUP).exists():
            sys.exit("dist/AltrobyteTrainerSetup.exe is not built. Run: python tools/build_installer.py")
        put(DIST / SETUP, SETUP, "desktop.json", info["version"])
    else:
        info = live("desktop.json")
        if info:
            src = DIST / SETUP
            if src.exists() and sha(src) == info["sha256"]:
                put(src, SETUP, "desktop.json", info["version"])
            else:
                problems.append(f"the live installer v{info['version']} is not in dist/ as published: the deploy would remove it")
        else:
            print("no desktop installer is live yet; none is published (use --installer once it is approved)")

    # The team's test build (5 Nov 2026, founder: the team tests it fully before it is published). Not linked for
    # learners: /learn offers it to admins only, and the desktop app's update check reads downloads/desktop.json.
    if a.team:
        info = json.loads((DIST / "desktop.json").read_text(encoding="utf-8")) if (DIST / "desktop.json").exists() else None
        if not info or not (DIST / SETUP).exists():
            sys.exit("dist/AltrobyteTrainerSetup.exe is not built. Run: python tools/build_installer.py")
        put(DIST / SETUP, SETUP, "desktop.json", info["version"], OUT / "team")
    else:
        info = live("team/desktop.json")
        if info:
            src = DIST / SETUP
            if src.exists() and sha(src) == info["sha256"]:
                put(src, SETUP, "desktop.json", info["version"], OUT / "team")
            else:
                problems.append(f"the team build v{info['version']} is not in dist/ as published: the deploy would remove it")

    if problems:
        print("NOT SAFE TO DEPLOY:")
        for p in problems:
            print(" -", p)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
