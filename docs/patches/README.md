# Nomad Patches for RustDesk

This fork (`nomad` branch) contains patches for RustDesk 1.4.5 for the [Nomad](https://nomadrust.dev) application.

## Patches

### Host (Desktop Linux/Windows)

Voice call auto-accept and close signaling for the desktop host.

- **Guide**: [host/CLAUDE.md](host/CLAUDE.md)
- **Changes**: `src/server/connection.rs`, `src/client.rs`, `src/lang/`

### APK (Android)

Joy-Con gamepad controller and voice call floating button for the Android APK.

- **Guide**: [apk/CLAUDE.md](apk/CLAUDE.md)
- **Deep-dive docs**: [apk/docs/](apk/docs/)
  - [HARDWARE-SPECS.md](apk/docs/HARDWARE-SPECS.md) — Joy-Con keycodes, acceleration
  - [IMPLEMENTATION-GUIDE.md](apk/docs/IMPLEMENTATION-GUIDE.md) — File-by-file code walkthrough
  - [OVERLAY-WIDGETS.md](apk/docs/OVERLAY-WIDGETS.md) — Floating UI rendering
  - [AUDIT-TRAIL.md](apk/docs/AUDIT-TRAIL.md) — Review corrections

## License

These patches are derivative works of RustDesk and are licensed under **AGPL-3.0**.
