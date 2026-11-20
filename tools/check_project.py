#!/usr/bin/env python3
"""Offline preflight checks for the ZaRa project.

Runs where the Flutter SDK is unavailable: Python syntax, Dart import targets,
stray non-target scripts in source, required markers and key Android files.

Usage:  python3 tools/check_project.py
"""
import py_compile
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXTERNAL = {
    "flutter", "provider", "http", "uuid", "flutter_secure_storage",
    "permission_handler", "speech_to_text", "flutter_tts", "flutter_test",
}
CJK = re.compile(r"[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]")
REQUIRED = [
    "pubspec.yaml", "lib/main.dart", "lib/app.dart",
    "lib/core/services/gemini_client.dart",
    "lib/core/services/voice_session.dart",
    "lib/core/services/wake_word_engine.dart",
    "lib/core/services/backend_client.dart",
    "lib/core/agent/tool_dispatcher.dart",
    "lib/state/app_state.dart",
    "android/app/src/main/AndroidManifest.xml",
    "android/app/src/main/kotlin/com/zaraai/app/MainActivity.kt",
    "server/main.py", "test/widget_test.dart", ".github/workflows/ci.yml",
]


def main() -> int:
    errors: list[str] = []
    notes: list[str] = []

    missing = [p for p in REQUIRED if not (ROOT / p).exists()]
    if missing:
        errors.append("missing files: " + ", ".join(missing))

    py_files = [p for p in ROOT.rglob("*.py") if "__pycache__" not in p.parts]
    for py in py_files:
        try:
            py_compile.compile(str(py), cfile=str(py) + ".pyc", doraise=True)
            (Path(str(py) + ".pyc")).unlink(missing_ok=True)
        except py_compile.PyCompileError as exc:
            errors.append(f"Python syntax: {py.relative_to(ROOT)}: {exc}")

    dart_files = list((ROOT / "lib").rglob("*.dart")) + list((ROOT / "test").rglob("*.dart"))
    for dart in dart_files:
        text = dart.read_text(encoding="utf-8")
        for imp in re.findall(r"import '([^']+)';", text):
            if imp.startswith("dart:"):
                continue
            if imp.startswith("package:"):
                if imp.startswith("package:zara/"):
                    target = ROOT / "lib" / imp.split("/", 1)[1]
                    if not target.exists():
                        errors.append(f"Dart import: {dart.relative_to(ROOT)} -> {imp}")
                elif imp.split(":")[1].split("/")[0] not in EXTERNAL:
                    errors.append(f"Unknown package: {dart.relative_to(ROOT)} -> {imp}")
            else:
                if not (dart.parent / imp).exists():
                    errors.append(f"Dart relative import: {dart.relative_to(ROOT)} -> {imp}")
        if CJK.search(text):
            errors.append(f"stray CJK script in {dart.relative_to(ROOT)}")

    manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    gradle = (ROOT / "android/app/build.gradle").read_text(encoding="utf-8")
    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    if "com.zaraai.app" not in gradle:
        errors.append("applicationId missing in build.gradle")
    if "networkSecurityConfig" not in manifest:
        errors.append("networkSecurityConfig missing in manifest")
    if "name: zara" not in pubspec:
        errors.append("pubspec name mismatch")

    notes.append(f"{len(dart_files)} Dart files")
    notes.append(f"{len(py_files)} Python files")
    notes.append(f"{len(list(ROOT.rglob('*')))} total entries")

    print("ZaRa preflight")
    print("  " + " | ".join(notes))
    if errors:
        print(f"FAILED ({len(errors)} problems):")
        for err in errors:
            print("  - " + err)
        return 1
    print("OK — static checks passed (Flutter SDK not required).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
