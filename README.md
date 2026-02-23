# Nomad — The RustDesk Companion for Mobile Voice Coding

> Your backlog is infinite. Your back isn't.

Nomad turns your Android phone into a full coding workstation via [RustDesk](https://github.com/rustdesk/rustdesk). Auto portrait mode, voice transcription, Joy-Con gamepad. Code from anywhere.

**[nomadrust.dev](https://nomadrust.dev)**

---

## Features

### Auto Portrait Mode
Screen rotates to portrait and scales your desktop UI for phone-sized screens — larger menus, readable text. Everything reverts when you disconnect.

### Voice Transcription
Local Whisper STT via PipeWire. No cloud API, no latency, no privacy leak. Dictate code changes hands-free.

### Joy-Con Gamepad
8 buttons, 40+ configurable actions. ZL/ZR modifier layers (3 action sets per button). Power 2.5 acceleration curve. Fits in a pocket — no laptop needed.

### Smart Audio Routing
Auto-accepts voice calls. Routes phone audio to the transcription backend. Restores original audio on disconnect.

---

## How It Works

```
1. Connect    Open RustDesk on your phone. Nomad detects the connection,
              rotates your screen to portrait, and zooms for readability.

2. Code       Start a voice call. Your speech is transcribed locally
              via Whisper — zero cloud, zero latency. Use Joy-Con for navigation.

3. Disconnect Close RustDesk. Nomad restores landscape orientation
              and original zoom. Like you never left.
```

---

## Architecture

Not a mobile IDE. Your full desktop, streamed to your phone.

```
Phone (Android)                    Desktop (Linux)
┌─────────────────┐               ┌──────────────────────┐
│  RustDesk viewer │ ── remote ──▶│  RustDesk Server     │
│  Joy-Con L/R     │ ── input ──▶ │  Nomad Daemon        │
│  Phone mic       │ ── voice ──▶ │  Voxtype (local STT) │
└─────────────────┘               │  Full IDE / Docker   │
                                  └──────────────────────┘
```

- No sync issues — you work on the real filesystem
- No battery drain from compilation
- No mobile SDK limitations
- Full Linux toolchain, always

---

## This Repository

Fork of [RustDesk 1.4.5](https://github.com/rustdesk/rustdesk) with Nomad-specific modifications. All changes are derivative works licensed under **AGPL-3.0**.

### Desktop (Host)
- **Voice call auto-accept**: Config flag to skip the Connection Manager dialog
- **Voice call close signaling**: Server notifies client on hangup (prevents zombie audio)
- **Audio diagnostics**: Frame counter + RMS logging for troubleshooting

### Android (APK)
- **Joy-Con gamepad controller**: Nintendo Joy-Con L/R as mouse/keyboard with power 2.5 acceleration, 3-layer button mapping (normal + ZL + ZR), configurable per-button actions
- **Voice call floating button**: Tap-to-arm hangup overlay during voice calls
- **Gamepad settings**: Settings > Mobile > Gamepad (6 options + button mapping editor)

---

## Building

See upstream [RustDesk docs](https://github.com/rustdesk/rustdesk/blob/master/README.md) for full build instructions and dependencies.

### Linux desktop
```bash
python3 build.py --flutter
```

### Android APK
```bash
cd flutter && JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug
```

> **Note**: `flutter build apk` alone builds Flutter only (no Rust native lib). For full build including voice call support, use `python3 build.py --flutter --android`.

---

## Documentation

Detailed patch documentation in [`docs/patches/`](docs/patches/):

- [Host patches](docs/patches/host/CLAUDE.md) — Voice call auto-accept + close signaling
- [APK patches](docs/patches/apk/CLAUDE.md) — Joy-Con gamepad + voice call UI
- [Hardware specs](docs/patches/apk/docs/HARDWARE-SPECS.md) — Joy-Con keycodes, acceleration curves
- [Implementation guide](docs/patches/apk/docs/IMPLEMENTATION-GUIDE.md) — Code walkthrough
- [Overlay widgets](docs/patches/apk/docs/OVERLAY-WIDGETS.md) — Floating UI rendering

---

## Branches

- **`nomad`** — Active branch with all Nomad modifications
- **`master`** — Upstream RustDesk (synced periodically)

---

## License

AGPL-3.0 — same as upstream RustDesk. See [LICENCE](LICENCE).

Joy-Con™ is a trademark of Nintendo. Nomad is not affiliated with or endorsed by Nintendo.
Works with RustDesk (AGPL). Nomad is a separate proprietary product.
