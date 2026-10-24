"""Puts the offline wake-word model into the Altron app (android/app/src/altron/assets/model-en-in) before a build.

Vosk's small Indian English model, 36 MB to download, kept out of git. Run once:  python tools/fetch_vosk_model.py
"""
import io
import pathlib
import shutil
import tempfile
import urllib.request
import zipfile

URL = "https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip"
DEST = pathlib.Path(__file__).resolve().parent.parent / "android/app/src/altron/assets/model-en-in"


def main():
    if (DEST / "am/final.mdl").exists():
        print("model already in place:", DEST)
        return
    data = urllib.request.urlopen(URL, timeout=300).read()
    with tempfile.TemporaryDirectory() as tmp:
        zipfile.ZipFile(io.BytesIO(data)).extractall(tmp)
        src = pathlib.Path(tmp) / "vosk-model-small-en-in-0.4"
        shutil.rmtree(DEST, ignore_errors=True)
        shutil.copytree(src, DEST)
    (DEST / "README").unlink(missing_ok=True)
    (DEST / "uuid").write_text("vosk-model-small-en-in-0.4\n")       # Vosk's StorageService unpacks a model only with this
    print("model ready:", DEST)


if __name__ == "__main__":
    main()
