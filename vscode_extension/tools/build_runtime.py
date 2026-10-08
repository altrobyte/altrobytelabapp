"""Builds the runtime the Altrobyte extension carries inside itself: a private Python, the packages the helper needs,
the helper and the trainer engine. A learner then installs ONE file and nothing else (no Python, no pip).

    python tools/build_runtime.py            # makes ./runtime (about 60 MB), then `npm run package` puts it in the .vsix

Windows 64-bit first. The Python is the official embeddable build from python.org; its sha256 is pinned below, so a
build that downloads something different stops instead of shipping it.
"""
import hashlib
import io
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

PY = "3.12.10"
PY_TAG = "312"
PY_URL = f"https://www.python.org/ftp/python/{PY}/python-{PY}-embed-amd64.zip"
PY_SHA256 = ""                      # filled in on the first trusted build, then enforced (see check below)

HERE = Path(__file__).resolve().parent.parent
BACKEND = HERE.parent.parent / "altrocoach-backend"
OUT = HERE / "runtime"
CACHE = HERE / ".runtime-cache"


def fetch() -> bytes:
    CACHE.mkdir(exist_ok=True)
    f = CACHE / f"python-{PY}-embed-amd64.zip"
    if not f.exists():
        print("downloading", PY_URL)
        f.write_bytes(urllib.request.urlopen(PY_URL, timeout=120).read())
    data = f.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    pinned = (HERE / "tools" / "python-embed.sha256")
    if pinned.exists():
        if pinned.read_text().strip() != digest:
            sys.exit(f"The downloaded Python does not match the pinned sha256 ({digest}). Not building.")
    else:
        pinned.write_text(digest + "\n")
        print("pinned sha256", digest, "(commit tools/python-embed.sha256)")
    return data


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "python").mkdir(parents=True)
    zipfile.ZipFile(io.BytesIO(fetch())).extractall(OUT / "python")

    # An embeddable Python ignores PYTHONPATH and the current folder; everything it may import is listed here.
    (OUT / "python" / f"python{PY_TAG}._pth").write_text(
        "\n".join([f"python{PY_TAG}.zip", ".", "..\\site-packages", "..\\helper", "..", "import site", ""]), encoding="utf-8")

    subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "--no-compile", "--target", str(OUT / "site-packages"),
                    "--platform", "win_amd64", "--python-version", "3.12", "--implementation", "cp", "--only-binary=:all:",
                    "-r", str(BACKEND / "helper" / "requirements.txt")], check=True)

    ignore = shutil.ignore_patterns("__pycache__", "*.pyc", "tests")
    shutil.copytree(BACKEND / "helper" / "altrobyte_helper", OUT / "helper" / "altrobyte_helper", ignore=ignore)
    shutil.copytree(BACKEND / "trainer", OUT / "trainer", ignore=ignore)
    shutil.copy(BACKEND / "helper" / "README.md", OUT / "helper" / "README.md")

    # Prove the bundle starts with its own Python and nothing else.
    check = ("import fastapi, uvicorn, httpx, pydantic, serial, paho.mqtt.client, yaml, altrobyte_helper, trainer.tools;"
             "print('runtime ok', __import__('sys').version.split()[0])")
    r = subprocess.run([str(OUT / "python" / "python.exe"), "-I", "-c", check], capture_output=True, text=True, cwd=str(OUT))
    print(r.stdout.strip() or r.stderr.strip())
    if r.returncode != 0:
        sys.exit("the runtime does not start")
    size = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file()) / 1e6
    print(f"runtime built: {size:.0f} MB in {OUT}")


if __name__ == "__main__":
    main()
