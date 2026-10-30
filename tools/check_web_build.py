"""Refuses to let a broken web build be deployed.

An incomplete `flutter build web` (seen when the disk was nearly full) left out manifest.json and assets/FontManifest.json;
Firebase then answered those with index.html, the app failed to parse them at start-up, and every visitor got a white
page. Run this after the build and before `firebase deploy`:

    flutter build web --release --no-wasm-dry-run && python tools/publish_downloads.py && python tools/check_web_build.py && python stamp_version.py && firebase deploy --only hosting
"""
import json
import sys
from pathlib import Path

WEB = Path(__file__).resolve().parent.parent / "build" / "web"
NEEDED = ["index.html", "app.html", "main.dart.js", "flutter_bootstrap.js", "flutter.js", "manifest.json", "favicon.png", "version.json",
          "assets/FontManifest.json", "assets/AssetManifest.bin.json", "canvaskit/canvaskit.wasm", "live/index.html", "live/v2/index.html", "pricing/index.html", "session/index.html", "home/index.html", "home/img/workshop.jpg", "class/index.html", "admissions/index.html"]
JSON = ["manifest.json", "assets/FontManifest.json", "version.json"]

missing = [f for f in NEEDED if not (WEB / f).is_file() or (WEB / f).stat().st_size == 0]
broken = []
for f in JSON:
    try:
        json.loads((WEB / f).read_text(encoding="utf-8"))
    except Exception:       # noqa: BLE001
        broken.append(f)
# The downloads are put next to the build by tools/publish_downloads.py; a deploy without them removes the links.
if not (WEB / "downloads" / "latest.json").is_file():
    missing.append("downloads/latest.json (run python tools/publish_downloads.py first)")
if missing or broken:
    sys.exit("The web build is incomplete, do not deploy it. Missing: " + ", ".join(missing) +
             ("; not valid JSON: " + ", ".join(broken) if broken else "") + ". Delete build/web and build again (building over an old build has left files out twice), and keep some disk space free.")
print("web build complete")
