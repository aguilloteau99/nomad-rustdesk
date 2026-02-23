# APK Patch: Joy-Con Gamepad Controller + Voice Call UI

Patch for RustDesk 1.4.5 Android APK + Desktop. Adds Joy-Con L/R gamepad support with configurable mappings and voice call floating button.

## Overview

- **Gamepad controller**: Joy-Con L/R (horizontal mode) as configurable mouse/keyboard controller
  - Power 2.5 acceleration curve (Steam Input-inspired) for precise low-speed, fast high-speed movement
  - 3-layer button mapping (normal, ZL modifier, ZR modifier)
  - Configurable per-button actions via Settings UI
  - Mouse hold/drag support, scroll via analog stick + trigger
  - 60fps timer-based polling for smooth, consistent movement
- **Voice call floating button**: Tap-to-arm hangup button overlay during voice calls
- **Desktop settings**: Auto-accept voice call checkbox in Settings > General > Other

## Quick Start

### Apply the patch
```bash
cd ~/rustdesk
git apply docs/patches/apk/rustdesk-gamepad.patch
```

### Build APK (requires JDK 17)
```bash
cd ~/rustdesk/flutter
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug
```

**CRITICAL**: `flutter build apk` alone = NO native lib → crash. For full build with Rust native:
```bash
cd ~/rustdesk
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 python3 build.py --flutter --android
```

### Install
```bash
adb install -r ~/rustdesk/flutter/build/app/outputs/flutter-apk/app-debug.apk
```

### Pair Joy-Con
1. On Joy-Con L, press SYNC button (small button on rail, between SL and SR)
2. LEDs blink
3. Android: **Settings → Bluetooth → Pair new device**
4. Select "Joy-Con (L)"
5. Wait for connection (solid LEDs = connected)

### Enable in RustDesk
1. Open RustDesk Android app
2. **Settings → Mobile → Gamepad**
3. Enable "Joy-Con Support"
4. Select Joy-Con side (L or R)
5. Connect to remote desktop

## Hardware Support

**Nintendo Joy-Con Left or Right** in horizontal mode (held sideways, SL+SR facing you during sync). One Joy-Con at a time. Side selection in **Settings → Gamepad → Joy-Con Side**.

### Verified Keycodes (Samsung S10+ / Android 12)

| Button | KeyCode Android | Code | Verified |
|---|---|---|---|
| Analog stick | `AXIS_X`, `AXIS_Y` | — | ✅ Tested |
| Stick click | `KEYCODE_BUTTON_THUMBL` | 106 | ✅ Tested |
| Face ↑ | `KEYCODE_DPAD_UP` | 19 | ✅ Tested |
| Face ↓ | `KEYCODE_DPAD_DOWN` | 20 | ✅ Tested |
| Face ← | `KEYCODE_DPAD_LEFT` | 21 | ✅ Tested |
| Face → | `KEYCODE_DPAD_RIGHT` | 22 | ✅ Tested |
| L (bumper) | `KEYCODE_BUTTON_L1` | 102 | ✅ Tested |
| ZL (trigger) | `KEYCODE_BUTTON_L2` | 104 | ✅ Tested (digital, not analog) |
| Minus (-) | `KEYCODE_BUTTON_SELECT` | 109 | ✅ Tested |
| Home | `KEYCODE_BUTTON_MODE` | 110 | ✅ Tested |
| SL | Variable | — | ⚠️ Ignored |
| SR | Variable | — | ⚠️ Ignored |
| Capture | Non-standard | — | ❌ Ignored |

**Note**: Face buttons send `DPAD_*` (not `BUTTON_A/B/X/Y`) on this device. Code handles both via dual-mapping for compatibility.

**Note ZL**: Joy-Con ZL is a **digital button** (KeyEvent 104), not an analog trigger. Android also sends `AXIS_LTRIGGER=0.0` in every MotionEvent, which could override button state. Resolved via `_zlFromKey` priority flag.

### Joy-Con Right Keycodes (horizontal mode)

| Button | KeyCode Android | Code | Verified |
|---|---|---|---|
| Analog stick | `AXIS_X`, `AXIS_Y` | — | ⚠️ To test |
| Stick click | `KEYCODE_BUTTON_THUMBR` | 107 | ⚠️ To test |
| R (bumper) | `KEYCODE_BUTTON_R1` | 103 | ⚠️ To test |
| ZR (trigger) | `KEYCODE_BUTTON_R2` | 105 | ⚠️ To test |
| Plus (+) | `KEYCODE_BUTTON_START` | 108 | ⚠️ To test |
| Home | `KEYCODE_BUTTON_MODE` | 110 | ⚠️ To test |

Same dual-mapping logic applies. ZR uses `_zrFromKey` priority flag to prevent `AXIS_RTRIGGER` override.

## Default Mappings

**Note**: All mappings are fully configurable via **Settings → Gamepad → Button Mappings**. Tables below show defaults for Joy-Con L. Joy-Con R uses ZR as modifier instead of ZL.

### Normal Layer

| Input | Action |
|---|---|
| Stick | Mouse movement (power 2.5 acceleration) |
| Stick click | Right click |
| L (bumper) | Left click |
| ZL (trigger) | **Modifier** (hold for combos/scroll) |
| ↑ | Arrow Up |
| ↓ | Arrow Down |
| ← | Arrow Left |
| → | Arrow Right |
| Home (110) | Enter |
| Minus (109) | Backspace |

### ZL Modifier Layer

| Input | Action |
|---|---|
| ZL + Stick | Scroll wheel (throttled ~15fps) |
| ZL + ↑ | Shift+Tab (navigate backward) |
| ZL + ↓ | Escape |
| ZL + ← | Ctrl+C (copy) |
| ZL + → | Ctrl+Z (undo) |
| ZL + L | Ctrl+A (select all) |
| ZL + Minus | Ctrl+S (save) |
| ZL + Home | Space |

### ZR Modifier Layer

Used when Joy-Con side is set to Right. Same structure as ZL layer.

## Configuration Options

All settings stored via `bind.mainSetLocalOption()` (Nomad_local.toml). Accessible in **Settings → Mobile → Gamepad**.

| Option Key | Type | Default | Description |
|---|---|---|---|
| `gamepad-enabled` | `'Y'`/`''` | `''` | Enable/disable gamepad support |
| `gamepad-mouse-speed` | `'0.5'`..`'3.0'` | `'1.5'` | Mouse speed multiplier |
| `gamepad-scroll-speed` | `'0.3'`..`'3.0'` | `'1.0'` | Scroll speed multiplier |
| `gamepad-rotate-axes` | `'Y'`/`''` | `''` | Swap stick X/Y axes (90° rotation) |
| `gamepad-show-overlay` | `'Y'`/`''` | `''` | Show Joy-Con button overlay in session |
| `gamepad-side` | `''`/`'right'` | `''` | Joy-Con side (`''` = left) |
| `gamepad-mappings` | JSON string | `''` | Full button mapping config (GamepadConfig) |

**Voice call option** (separate section):
| Option Key | Type | Default | Description |
|---|---|---|---|
| `show-voice-call-button` | `''`/`'N'` | `''` | Show floating voice call button (hidden if `'N'`) |

## Technical Implementation

### Architecture

```
┌─────────────────┐
│   Joy-Con (BT)  │
└────────┬────────┘
         │ Bluetooth HID
         ▼
┌─────────────────────────────────────────────────┐
│              Android Activity                    │
│  ┌─────────────────────────────────────────┐    │
│  │ dispatchKeyEvent()                       │    │
│  │ dispatchGenericMotionEvent()             │    │
│  └────────────────┬────────────────────────┘    │
│                   │                              │
│  ┌────────────────▼────────────────────────┐    │
│  │         GamepadHandler.kt               │    │
│  │  - Filter SOURCE_GAMEPAD/JOYSTICK       │    │
│  │  - Apply deadzone (0.15)                │    │
│  │  - Remap [deadzone,1.0] → [0.0,1.0]     │    │
│  │  - Stream via EventChannel              │    │
│  └────────────────┬────────────────────────┘    │
└───────────────────┼─────────────────────────────┘
                    │ EventChannel
                    ▼
┌─────────────────────────────────────────────────┐
│              Flutter/Dart                        │
│  ┌────────────────────────────────────────┐     │
│  │         GamepadModel                    │     │
│  │  - Listen EventChannel                  │     │
│  │  - Track ZL/ZR modifier state           │     │
│  │  - 60fps Timer for mouse move           │     │
│  │  - Config-driven dispatch (3 layers)    │     │
│  │  - GamepadConfig (JSON persistence)     │     │
│  └────────────────┬───────────────────────┘     │
│                   │                              │
│  ┌────────────────▼───────────────────────┐     │
│  │         InputModel (existing)           │     │
│  │  - sendMouse(type, buttons, x, y)       │     │
│  │  - inputKey(name, down, press)          │     │
│  │  - Modifier state: ctrl, shift, alt     │     │
│  └────────────────┬───────────────────────┘     │
└───────────────────┼─────────────────────────────┘
                    │ RustDesk Protocol
                    ▼
┌─────────────────────────────────────────────────┐
│           Remote Desktop (Linux/Windows)         │
│  - Receives mouse/keyboard events               │
│  - Executes on remote desktop                   │
└─────────────────────────────────────────────────┘
```

### Deadzone & Remapping

- **Value**: 0.15 (15% of stick travel)
- **Remapping**: `[deadzone, 1.0]` → `[0.0, 1.0]` to prevent speed jumps
- **Reason**: Joy-Cons are prone to drift; 15% filters out parasitic movement

Applied in `GamepadHandler.kt`:
```kotlin
private fun applyDeadzone(value: Float): Float {
    if (abs(value) < DEADZONE) return 0f
    val sign = if (value > 0) 1f else -1f
    return sign * (abs(value) - DEADZONE) / (1f - DEADZONE)
}
```

### Mouse Acceleration

Power 2.5 curve for precise low-speed, fast high-speed movement:

```
speed = (baseSpeed + (maxSpeed - baseSpeed) × magnitude^accelPower) × mouseSpeed

Where:
  magnitude = √(x² + y²), clamped [0, 1]
  baseSpeed = 1.0 pixel/tick
  maxSpeed = 25.0 pixels/tick
  accelPower = 2.5
  mouseSpeed = 1.5 (configurable in Settings)
  tickRate = ~60fps (16ms)
```

Inspired by Steam Input / JoyShockMapper. Power 2.5 (vs quadratic 2.0) creates a wider precision zone for small movements, ideal for clicking UI buttons.

| Deflection | Speed (raw) | × mouseSpeed 1.5 | Pixels/second |
|---|---|---|---|
| 10% | ~1.0 px/tick | ~1.5 | ~94 px/s |
| 25% | ~1.1 px/tick | ~1.6 | ~100 px/s |
| 50% | ~2.4 px/tick | ~3.6 | ~225 px/s |
| 100% | 25 px/tick | 37.5 | ~2340 px/s |

### Timer-Based Polling

Mouse movement uses a Dart Timer at 60fps rather than sending on each Android MotionEvent:
- **Constant frequency** independent of device (MotionEvent = 30-120Hz variable)
- **Smooth movement** via fractional pixel accumulator
- Caches axis values, polls at fixed interval
- Allows independent scroll throttling (~15fps when ZL held)

### Scroll Mechanism

ZL + stick = scroll wheel:
- **Throttle**: ~15fps (`_scrollTickCounter % 4 != 0` with 60fps timer)
- **Value**: Raw value sent (`'y': '$y'`) — Windows server multiplies by `WHEEL_DELTA=120`
- **State reset**: `_scrollRemainderY` and `_scrollTickCounter` reset on ZL false→true transition

### ZL/ZR Dual-Source with KeyEvent Priority

Joy-Con ZL is a digital button (KeyEvent 104), but Android also sends `AXIS_LTRIGGER=0.0` in every MotionEvent. Without protection, the 60Hz axis event would override button state. Same for ZR (KeyEvent 105 / `AXIS_RTRIGGER`).

**Solution**: `_zlFromKey` / `_zrFromKey` flags
- KeyEvent `BUTTON_L2 down` → `_zlHeld=true`, `_zlFromKey=true`
- KeyEvent `BUTTON_L2 up` → `_zlHeld=false`, `_zlFromKey=false`
- MotionEvent `AXIS_LTRIGGER` → ignored if `_zlFromKey==true`
- Identical mechanism for ZR with `_zrFromKey`

### Config-Driven Button Dispatch

```
GamepadModel._onButton(keyCode, isDown)
  ├─ _toLogicalButton(keyCode)        ← side-dependent (L1=102 vs R1=103)
  ├─ _config.getAction(logical, zlHeld, zrHeld, lHeld, rHeld)
  │     ├─ If zrHeld && zrMode==modifier → lookup zrLayer
  │     ├─ If zlHeld && zlMode==modifier → lookup zlLayer
  │     └─ Else → normalLayer
  ├─ isDown → _pressOrExecute(keyCode, actionStr)
  │     ├─ 'mouse_left/right/middle' → tapDown() + track
  │     └─ other → _executeAction() ← parses "ctrl+VK_Z", etc.
  └─ !isDown → _releaseHeldMouse(keyCode)  ← tapUp() if tracked
```

**Logical buttons** (side-independent):
- `DPAD_UP` (19) / `BUTTON_X` (99) → `'dpad_up'`
- `L1` (102) [Joy-Con L] / `R1` (103) [Joy-Con R] → `'bumper'`
- `THUMBL` (106) / `THUMBR` (107) → `'thumbstick'`
- `SELECT` (109) → `'menu_minus'`
- `START` (108) / `MODE` (110) → `'menu_home'`

**Trigger modes**:
- **Modifier**: Activates ZL/ZR layer when held
- **Action**: Sends configured action on press (e.g., Escape)

### Key API Reference

#### InputModel (`flutter/lib/models/input_model.dart`)
```dart
// Key press (VK_* names). Modifier state: inputModel.ctrl, .shift, .alt, .command
inputModel.inputKey('VK_UP', press: true);
inputModel.inputKey('VK_ESCAPE', press: true);

// Modifier combo (e.g., Ctrl+Z):
final savedCtrl = inputModel.ctrl;
try {
  inputModel.ctrl = true;
  inputModel.inputKey('VK_Z');
} finally {
  inputModel.ctrl = savedCtrl;  // Restore original state
}

// Mouse clicks
inputModel.tap(MouseButtons.left);           // Instant click (down+up)
inputModel.tapDown(MouseButtons.left);       // Hold (enables drag)
inputModel.tapUp(MouseButtons.left);         // Release

// Mouse movement (absolute coords, clamped to display rect)
ffi.cursorModel.moveByDelta(dx.toDouble(), dy.toDouble());
```

#### Scroll
```dart
// Raw value — server multiplies by WHEEL_DELTA=120 on Windows
bind.sessionSendMouse(
  sessionId: ffi.sessionId,
  msg: json.encode({'type': 'wheel', 'y': '$y'})
);
```

#### Settings Persistence
```dart
// Local options (Nomad_local.toml — client-side, per-device)
bind.mainSetLocalOption(key: 'gamepad-enabled', value: 'Y');
String enabled = bind.mainGetLocalOption(key: 'gamepad-enabled');  // returns String
```

## Files Modified (15 total)

### New Files (8)
| File | Description |
|---|---|
| `flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/GamepadHandler.kt` | Native Android event handler (EventChannel → Dart) |
| `flutter/lib/models/gamepad_model.dart` | Dart state machine (config dispatch, acceleration, 60fps timer) |
| `flutter/lib/models/gamepad_config.dart` | Data model (`GamepadConfig`, `GamepadAction`, `LogicalButton`) |
| `flutter/lib/mobile/pages/gamepad_mappings_page.dart` | Full button mapping editor UI (3 layers, trigger modes) |
| `flutter/lib/mobile/widgets/floating_joycon_overlay.dart` | Joy-Con L/R overlay (config-driven labels, mirrored rendering) |
| `flutter/lib/mobile/widgets/floating_voice_call.dart` | Voice call floating button (tap-to-arm hangup) |
| `flutter/lib/common/utils/secure_storage.dart` | Nomad license secure storage (uses LocalConfig fallback) |
| `flutter/lib/common/widgets/qr_activation.dart` | QR code widget for mobile license activation |

### Modified Files (6)
| File | Change |
|---|---|
| `flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainActivity.kt` | EventChannel setup + dispatchKeyEvent/dispatchGenericMotionEvent overrides |
| `flutter/lib/models/model.dart` | Add `GamepadModel` to FFI class, add `CursorModel.moveByDelta()` |
| `flutter/lib/mobile/pages/remote_page.dart` | Lifecycle: start/stop gamepad, conditional voice button, overlay integration |
| `flutter/lib/mobile/pages/settings_page.dart` | Settings UI: gamepad section (6 options), Joy-Con side, mappings nav, voice call toggle |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | Auto-accept voice calls checkbox + Nomad settings tab (license activation, QR, deactivation) |
| `flutter/pubspec.lock` | Dependency lock file updates |

## Nomad Settings Tab (Desktop)

New **Settings → Nomad** tab for license management.

### Features
- **License Key**: Text field for entering license keys
- **Activate / Deactivate**: Buttons for license activation and seat release
- **Status Display**: Shows active/expired/inactive with color-coded text
- **QR Code**: Toggle to show QR activation widget for mobile scanning
- **Storage**: Uses `LocalConfig` via `bind.mainSetLocalOption()` / `bind.mainGetLocalOption()`

## Voice Call Floating UI

### Button States

| State | Icon | Color | Animation |
|---|---|---|---|
| `notStarted` | `Icons.mic_none` | Grey | None |
| `waitingForResponse` | `Icons.mic` | Blue | None |
| `connected` | `Icons.mic` | Blue | Pulsing glow |
| `connected` + armed | `Icons.call_end` | Red | Countdown arc (3s) |

### UX Flow
- **Start call**: Single tap
- **Cancel pending**: Single tap
- **End call**: Tap-to-arm (1st tap = pulse + red icon, 2nd tap within 3s = hang up)

### Visibility Control
Controlled by: **Settings → Voice Call → Show voice call button** (`show-voice-call-button` local option, shown by default).

**Note**: Auto-accept configuration is desktop-only (Settings > General > Other checkbox). The server-side check in `connection.rs` reads the desktop's `Nomad2.toml`, so a mobile toggle has no effect.

## Joy-Con Overlay

Transparent overlay showing button zones with config-driven labels. Renders both Joy-Con L and R (side selected via `config.side`).

**Features**:
- Auto-fade to 35% opacity after 15s without input
- Hidden in landscape
- Draggable via grip bar
- Button labels update dynamically with config changes
- Shows modifier layer labels when ZL/ZR held

**Toggle**: Settings → Gamepad → Show Button Overlay (`gamepad-show-overlay`)

## Build Instructions

### Environment Requirements
- **JDK 17**: `/usr/lib/jvm/java-17-openjdk-amd64` (Gradle 7.6.4 incompatible with Java 21)
- **Android NDK**: `~/Android/Sdk/ndk/27.0.12077973/`
- **Rust targets**: `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`, `i686-linux-android`
- **cargo-ndk**: 3.1.2
- **VCPKG_ROOT**: `~/vcpkg` (for native lib dependencies)

### Flutter-Only Debug APK (~106MB, 3-4 min)
```bash
cd ~/rustdesk/flutter
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug
```

**IMPORTANT**: This builds Flutter code only. For voice call support, you need the full build.

### Full Build with Rust Native
Includes voice call patch in `src/server/connection.rs`:
```bash
cd ~/rustdesk
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 python3 build.py --flutter --android
```

**Steps inside build.py**:
1. `./flutter/build_android_deps.sh arm64-v8a` (builds native deps with vcpkg)
2. `cargo ndk --platform 21 --target aarch64-linux-android build --release --features flutter`
3. Copy `liblibrustdesk.so` → rename to `librustdesk.so` in `jniLibs/arm64-v8a/`
4. `flutter build apk --debug`

**Critical notes**:
- `flutter build apk` alone = NO native lib → crash on launch
- Gradle 7.6.4 requires JDK 17 (not 21)
- `hwcodec` feature fails cross-compile — use `--features flutter` instead

### Install APK
```bash
adb install -r ~/rustdesk/flutter/build/app/outputs/flutter-apk/app-debug.apk
```

## Test Checklist

### Basic Joy-Con L
- [ ] Joy-Con L paired via Bluetooth
- [ ] Gamepad enabled in Settings
- [ ] RustDesk connected to desktop
- [ ] Stick moves cursor (smooth, precise at low deflection)
- [ ] Stick center = no drift (deadzone 0.15)
- [ ] L button = left click
- [ ] Stick click = right click
- [ ] Face buttons = arrow keys
- [ ] Home = Enter
- [ ] Minus = Backspace
- [ ] ZL + stick = scroll wheel
- [ ] ZL + face buttons = combos (Shift+Tab, Esc, Ctrl+C, Ctrl+Z)
- [ ] ZL + L = Ctrl+A (select all), ZL + Minus = Ctrl+S (save), ZL + Home = Space
- [ ] Touch input works alongside gamepad
- [ ] Disconnect Joy-Con = no crash
- [ ] Settings persist across app restart

### Joy-Con R + Configurable Mappings
- [ ] Switch side to R → overlay mirrors, R1=click, ZR=modifier
- [ ] Button mapping: change D-pad Up → Enter → verify sends Enter
- [ ] Trigger action mode: set ZL to Escape → verify sends Escape on press
- [ ] Hot reload: change mapping mid-session → `reloadConfig()` applies
- [ ] Reset to Default shows confirmation dialog
- [ ] Side switch with custom mappings shows confirmation dialog

### Voice Call UI
- [ ] Voice button: disable in settings → verify hidden in remote session
- [ ] Tap to start call → icon changes to blue
- [ ] Connected → icon pulses
- [ ] Tap-to-arm → red icon + countdown arc
- [ ] 2nd tap within 3s → call ends
- [ ] Desktop auto-accept: toggle checkbox → verify `Nomad2.toml` updated

## Known Issues (RustDesk 1.4.5)

- **Voice call once per session**: Audio state not reset between calls. 2nd call may crash (SIGSEGV in `gtk_window_is_maximized` — Flutter/GTK3 upstream bug).
- **"Failed to start voice call" on Android**: Display bug — call actually works.
- **Joy-Con drift**: If observed, increase deadzone or calibrate/repair Joy-Con.
- **SL/SR unreliable**: Keycodes vary by firmware/device — intentionally ignored.

## Troubleshooting

### Joy-Con won't connect
- Verify Bluetooth enabled on Android
- Reset Joy-Con: hold SYNC 5 seconds
- Remove existing pairing and retry

### Stick drift (phantom movement)
- Increase `gamepad-deadzone` (not exposed in UI — would need code change to 0.2 or 0.25)
- Joy-Con may need calibration or hardware repair

### High latency
- Verify stable Bluetooth connection
- Close other apps using Bluetooth
- Reduce `gamepad-mouse-speed` if movement is jerky

### Buttons don't respond
- Verify gamepad enabled in Settings
- Test with [KeyEvent Display app](https://play.google.com/store/apps/details?id=aws.apps.keyeventdisplay) to see received keycodes
- Some buttons may have different keycodes depending on firmware/device

### Axes rotated/inverted
- Try enabling "Rotate Stick Axes" in Settings (90° CCW rotation)
- Samsung S10+ tested: rotation NOT needed (stick correct without rotation)

## Design Rationale

### Why `WeakReference<FFI>` in GamepadModel?
Prevents GamepadModel from keeping FFI session alive. If session closes, GC can reclaim FFI object. Timer detects `parent.target == null` and calls `stop()` to prevent leak.

### Why Timer 60fps instead of sending on each MotionEvent?
- Constant frequency independent of device (MotionEvent = 30-120Hz variable)
- Stick is continuous axis: cache last value, poll at fixed interval
- Allows independent scroll throttling (~15fps)

### Why power 2.5 acceleration?
Steam Input / JoyShockMapper use similar curves. Power 2.5 (vs quadratic 2.0) creates a wider precision zone for small movements, ideal for clicking UI buttons while still achieving high speed at full deflection.

### Why not use `InputModel.modify()` for mouse events?
Gamepad needs isolation from keyboard modifiers. If user has Shift pressed on keyboard while using stick, `modify()` would inject Shift into mouse events. Gamepad uses direct `json.encode({...})` to avoid this.

## Quality Audit

11 corrections applied from 4 PR review agents (code-reviewer, silent-failure-hunter, code-simplifier, comment-analyzer):

| # | Fix | Severity |
|---|---|---|
| 1 | Remove `y * 120` scroll double-multiplication (server already multiplies) | Critical |
| 2 | `onError` calls `stop()` (prevents Timer leak) | Critical |
| 3 | Remove `modify()` from mouse/scroll events (prevents modifier bleed) | Critical |
| 4 | Remove per-event `debugPrint` from `_onButton` | High |
| 5 | Reset scroll state on ZL false→true transition | High |
| 6 | Null `eventSink` in Kotlin ISE catch (prevents error loop) | High |
| 7 | `parent.target == null` → `stop()` (prevents Timer leak) | High |
| 8 | `ffi.ffiModel.keyboard` safe check (no force-unwrap) | Medium |
| 9 | `ConnType.viewCamera` guard (skip gamepad during camera view) | Medium |
| 10 | `gamepadHandler?.setEventSink(null)` in `onDestroy` | Medium |
| 11 | Remove unused `deviceId` from Kotlin event maps | Low |

## Detailed Documentation

See `docs/patches/apk/docs/` for deep-dive technical references:
- `HARDWARE-SPECS.md` — Full Joy-Con specs, verified keycodes, acceleration curves, troubleshooting
- `IMPLEMENTATION-GUIDE.md` — File-by-file code walkthrough, design decisions
- `OVERLAY-WIDGETS.md` — Voice call + Joy-Con overlay rendering details
- `AUDIT-TRAIL.md` — Full audit with pre/post verification, resolved uncertainties

## References

- [Android KeyEvent](https://developer.android.com/reference/android/view/KeyEvent)
- [Android MotionEvent](https://developer.android.com/reference/android/view/MotionEvent)
- [Handle controller actions](https://developer.android.com/develop/ui/views/touch-and-input/game-controllers/controller-input)
- [Joy-Con Wikipedia](https://en.wikipedia.org/wiki/Joy-Con)
- [KeyEvent Display App](https://play.google.com/store/apps/details?id=aws.apps.keyeventdisplay)
- [Steam Input](https://partner.steamgames.com/doc/features/steam_controller)
- [JoyShockMapper](https://github.com/Electronicks/JoyShockMapper)

## Patch Generation

After implementing changes, regenerate the patch:
```bash
cd ~/rustdesk
git add -A flutter/  # Include new files
git diff HEAD -- flutter/ > docs/patches/apk/rustdesk-gamepad.patch
```

Patch size: **~4031 lines** (16 files: 8 new, 7 modified, 1 build system)

### File Breakdown
- **Gamepad**: 6 files (GamepadHandler.kt, gamepad_model.dart, gamepad_config.dart, gamepad_mappings_page.dart, floating_joycon_overlay.dart, floating_voice_call.dart)
- **Nomad License**: 2 new files (secure_storage.dart, qr_activation.dart)
- **Modifications**: 6 files (MainActivity.kt, model.dart, remote_page.dart, settings_page.dart, desktop_setting_page.dart, pubspec.lock)
