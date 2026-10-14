"""Refuses a desktop release whose parts do not match. Run before tools/build_installer.py:

    python tools/check_release.py

It checks that
  - the app's version is the same in both pubspec.yaml files and in lib/desktop/app_version.dart;
  - the helper and trainer engine bundled in vscode_extension/runtime are exactly the backend's current code (an old
    copy there once nearly shipped: the build only rebuilt the runtime when it was missing);
  - the app asks for at least the helper version it ships with, so an older helper left running is replaced;
  - the web build is not involved (that has its own check, tools/check_web_build.py).
"""
import filecmp
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKEND = ROOT.parent / "altrocoach-backend"
RUNTIME = ROOT / "vscode_extension" / "runtime"


def pub_version(path: Path) -> str:
    m = re.search(r"^version:\s*([0-9.]+)", path.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else ""


def dart_const(path: Path, name: str) -> str:
    m = re.search(rf"const {name} = '([^']+)'", path.read_text(encoding="utf-8"))
    return m.group(1) if m else ""


def helper_version(folder: Path) -> str:
    m = re.search(r'__version__ = "([^"]+)"', (folder / "altrobyte_helper" / "__init__.py").read_text(encoding="utf-8"))
    return m.group(1) if m else ""


def same_tree(a: Path, b: Path) -> list:
    """Files that differ or are missing between two folders (ignoring caches and tests)."""
    skip = {"__pycache__", "tests"}
    out = []

    def walk(cmp: filecmp.dircmp, rel: str):
        for n in cmp.left_only + cmp.right_only:
            if n not in skip and not n.endswith(".pyc"):
                out.append(f"{rel}{n} (only on one side)")
        for n in cmp.diff_files:
            out.append(f"{rel}{n} (differs)")
        for n, sub in cmp.subdirs.items():
            if n not in skip:
                walk(sub, f"{rel}{n}/")
    walk(filecmp.dircmp(a, b, ignore=list(skip)), "")
    return out


def as_tuple(v: str) -> tuple:
    return tuple(int(x) for x in re.findall(r"\d+", v)[:3])


def main() -> int:
    problems = []
    app = pub_version(ROOT / "pubspec.yaml")
    desk = pub_version(ROOT / "desktop_app" / "pubspec.yaml")
    code = dart_const(ROOT / "lib" / "desktop" / "app_version.dart", "appVersion")
    if not (app == desk == code):
        problems.append(f"app version differs: pubspec {app}, desktop_app/pubspec {desk}, app_version.dart {code}")

    if not (RUNTIME / "python" / "python.exe").exists():
        problems.append("the runtime is not built: run vscode_extension/tools/build_runtime.py")
    else:
        for src, dst in ((BACKEND / "helper" / "altrobyte_helper", RUNTIME / "helper" / "altrobyte_helper"),
                         (BACKEND / "trainer", RUNTIME / "trainer")):
            diff = same_tree(src, dst)
            if diff:
                problems.append(f"{dst.relative_to(ROOT)} is not the backend's current code: " + "; ".join(diff[:6]))
        shipped = helper_version(RUNTIME / "helper")
        wanted = dart_const(ROOT / "lib" / "desktop" / "helper_client.dart", "minHelperVersion")
        if as_tuple(wanted) > as_tuple(shipped):
            problems.append(f"the app wants helper {wanted} but ships {shipped}")
        elif as_tuple(wanted) < as_tuple(shipped):
            problems.append(f"the app accepts an older helper ({wanted}) than it ships ({shipped}): an old one left running "
                            f"would be used. Set minHelperVersion to {shipped}.")

    if problems:
        print("NOT READY TO RELEASE:")
        for p in problems:
            print(" -", p)
        return 1
    print(f"release parts match: app {app}, helper {helper_version(RUNTIME / 'helper')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
