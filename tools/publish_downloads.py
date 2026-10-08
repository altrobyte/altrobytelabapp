"""Puts the downloadable extension next to the web build, so the "Connect VS Code" page can offer it.

    flutter build web --release --no-wasm-dry-run
    python tools/publish_downloads.py
    python stamp_version.py && firebase deploy --only hosting

It copies the packaged .vsix into build/web/downloads/ under a stable name and writes latest.json (version, size and
sha256) that the page shows. The .vsix itself stays out of git: it is a build product (about 15 MB).
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / "vscode_extension"
OUT = ROOT / "build" / "web" / "downloads"
NAME = "altrobyte-trainer-win32-x64.vsix"


def main() -> None:
    version = json.loads((EXT / "package.json").read_text(encoding="utf-8"))["version"]
    src = EXT / f"altrobyte-trainer-win32-x64-{version}.vsix"
    if not src.exists():
        sys.exit(f"{src.name} not found. Build it first: cd vscode_extension && npx vsce package --no-dependencies --target win32-x64")
    if not (ROOT / "build" / "web" / "index.html").exists():
        sys.exit("build/web does not exist. Run flutter build web first.")
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, OUT / NAME)
    data = (OUT / NAME).read_bytes()
    info = {"version": version, "file": NAME, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    (OUT / "latest.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    print(f"published {NAME} v{version}, {len(data) / 1e6:.1f} MB, sha256 {info['sha256'][:16]}...")


if __name__ == "__main__":
    main()
