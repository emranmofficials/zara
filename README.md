# ZaRa

Voice-first assistant app. Package: `com.zaraai.app`. Flutter 3.4+ / Dart 3.4+.

This is a **clean-room** implementation inspired by the *architecture* of a
studied app. No proprietary assets, branding, model files or license-bypass
code are included.

## Quick start

```sh
flutter pub get
flutter test          # widget + unit tests
flutter run           # device / emulator
```

Release APK:

```sh
flutter build apk --release
```

### On this ARM64 Android device (no native Flutter SDK)

A working Flutter 3.50.1 SDK (with the matching ARM64 Dart 3.14.0 and engine
artifacts) is installed at `~/flutter-sdk`, inside the Ubuntu 24.04 ARM64
`proot-distro` container. Two wrappers live in `tools/`:

```sh
sh tools/flutter-proot.sh pub get     # analyze, test, doctor - native ARM64
sh tools/flutter-proot.sh test
sh tools/flutter-build-proot.sh apk --debug   # QEMU-emulates x86_64 aapt2/adb
```

`flutter-proot.sh` runs Flutter/Dart natively; `flutter-build-proot.sh` adds
`proot --qemu=qemu-x86_64-static` so Android SDK tools that Google only ships
for x86_64 still work. The same commands run natively on a normal Flutter host.

## What is inside

- **Shell** — single `AppShell` with a grouped, searchable 57-route drawer,
  5-destination bottom nav and mic FAB
- **Navigation** — custom StateFlow-like route state (`RouteRegistry` / `RoutePage`),
  57 generated routes with Hinglish/Bengali voice aliases (longest alias wins)
- **Home** — Maya-style persona hero with an animated orb (tap to talk),
  time-based greeting, live voice state, mood cards, energy meter,
  weather/today cards, a visible Gemini setup banner (doc → engine → key) and
  12 quick-action chips
- **Chat** — live/old-chat header, history & clear, reply chip, attachment chip,
  message variants (text/voice/tool) and the pending-voice-reply confirm card
- **Yaadein** — date-grouped memories combined with backend memory facts
- **Vibes** — mood selection with persona-matched energy
- **Scanner** — camera permission flow, standby/live/recording state machine,
  flip/capture controls and "send detected text to chat"
- **Every other route has a real screen** — device/PC hub, rules & event
  triggers, markets, marketing, code projects, documents, pictures, terminal,
  QR scan, a drawable whiteboard, a settings-detail family with working
  switches, a permissions manager and static info pages
- **Personas** — 4 original personas with generated Material 3 themes
- **Voice (Bengali-only for now)** — `speech_to_text` ASR (`bn_IN` / `bn_BD`)
  + `flutter_tts` TTS (`bn-IN`) + pluggable `WakeWordEngine` (Bengali wake words,
  keyword spotter on partial transcripts, or inject your own `.tflite` engine).
  `lib/core/services/language_policy.dart` is the single source of truth for
  ASR locale, TTS locale, wake words and every model prompt, so no
  English/Hinglish answer can leak into the spoken pipeline.
- **Agent** — tool registry (tier budget, fuzzy `find_tool`), Gemini function
  calling and a confirm gate for external actions
- **Notifications** — `NotificationListenerService` reads reply actions only
  from a supported chat package whitelist, and sends through Android's public
  `RemoteInput` API (never accessibility clicks). Expired tokens are pruned
  from the in-memory cache automatically.
- **Backend** — optional Python FastAPI proxy (`server/`) for Gemini, tools,
  memory/history, backup/export-import, device tokens and chat summaries

## Settings

- **Gemini setup** — install doc first, then engine install. The bundled Bengali
  doc (`assets/docs/gemini_install_bn.md`) must be opened and acknowledged before
  the “ইঞ্জিন ইনস্টল করুন” button becomes enabled. Both flags persist in secure
  storage, so restarting the app cannot skip the order. Voice phrase:
  “জেমেনি ইন্সটল” / “gemini install doc”.
- Gemini API key (encrypted, on-device) **or** backend URL + Bearer token
- Persona, Bengali-only recognition locale, speech rate, Bengali wake words, test voice
- Notification access, tool budget info
- Chat summary, backup export/import, device register/revoke

No message is ever sent without a confirmation card.

## Structure

```
lib/core/agent        tool registry + dispatcher + confirm gate
lib/core/navigation   StateFlow-like routes
lib/core/services     Gemini, backend client, voice session, wake word engine
lib/core/theme        personas + themes
lib/core/notifications RemoteInput reply bridge
lib/features          Home, Chat, Vibes, Yaadein, Scanner, Settings,
                      devices, rules, tools, system (permissions + info)
lib/state             AppState
server/               optional Python FastAPI backend
test/                 widget + unit tests
tools/                route codegen (Python)
```

## Regenerate routes

```sh
python3 tools/generate_routes.py
```

## Offline preflight (no Flutter SDK needed)

```sh
python3 tools/check_project.py
```

Checks Python syntax, Dart import targets, stray scripts, package name,
manifest and required files.

## Release signing

```sh
python3 tools/generate_keystore.py          # prompts for passwords
# or: ZARA_STORE_PASSWORD=... ZARA_KEY_PASSWORD=... python3 tools/generate_keystore.py
flutter build apk --release
```

The script creates `android/app/zara-release.jks` and `android/key.properties`
(both gitignored). `android/key.properties.example` shows the format. Without a
keystore the release build is unsigned; debug builds use the default debug key.

Debug builds allow cleartext HTTP for the local backend through a debug-only
network security config; release builds stay HTTPS-only.

## CI

`.github/workflows/ci.yml` runs `flutter analyze`, `flutter test`, a debug APK
build and Python syntax checks on every push/PR.

## Backend logic test (no dependencies)

```sh
python3 server/smoke_test.py     # 15 checks: auth, tools, confirm, memory, backup, devices, summary
```

It stubs FastAPI/pydantic/httpx and exercises the real endpoint functions, so it
works even where those packages cannot be installed.

## Backend

See `server/README.md`. Run without a key in the app:

```sh
cd server && pip install -r requirements.txt
GEMINI_API_KEY="..." ZARA_TOKEN="master-secret" uvicorn main:app --reload --port 8000
```

Then set **Backend URL** to `http://10.0.2.2:8000` (emulator) or your LAN IP.

> The Android shell used to generate this project is aarch64 and has no
> Flutter SDK; sources were verified statically (Python syntax, Dart imports,
> stray characters). Run `flutter test` on a proper SDK host before release.
