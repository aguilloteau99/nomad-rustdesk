# Flutter Overlays: Voice Call Button + Joy-Con Overlay

Two floating Android widgets for RustDesk remote sessions.

> **Parent guide**: See `patches/apk/CLAUDE.md` for quick start and overview.


| File | Action |
|---|---|
| `flutter/lib/mobile/widgets/floating_voice_call.dart` | Created |
| `flutter/lib/mobile/widgets/floating_joycon_overlay.dart` | Created (L+R mirroring, config-driven labels) |
| `flutter/lib/models/gamepad_model.dart` | Modified (added `pressedButtons`, `config` getter) |
| `flutter/lib/models/gamepad_config.dart` | Created (data model for configurable mappings) |
| `flutter/lib/mobile/pages/remote_page.dart` | Modified (paints list, conditional voice button) |
| `flutter/lib/mobile/pages/settings_page.dart` | Modified (overlay toggle, voice call button toggle) |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | Modified (auto-accept checkbox) |

## Integration Point

Both widgets are added to `remote_page.dart:getBodyForMobile()` paints list (NOT `FloatingMouseWidgets.build()`).
This ensures visibility in both touch and mouse modes.

## Visual Style (reuse existing constants from `floating_mouse_widgets.dart:28-31`)

```
fill:    Colors.black.withOpacity(0.4)
border:  Colors.white.withOpacity(0.7)
pressed: Colors.blue.withOpacity(0.7)
```

---

## Feature A: Floating Voice Call Button

**Template**: `FloatingLeftRightButton` pattern (draggable, position-persisted, blocked rect).

**API**:
- State: `gFFI.chatModel.voiceCallStatus` — `Rx<VoiceCallStatus>` via `Obx()`
- Start: `bind.sessionRequestVoiceCall(sessionId: ffi.sessionId)`
- Stop: `bind.sessionCloseVoiceCall(sessionId: ffi.sessionId)`

**UX**:
- Start call: single tap
- Cancel pending: single tap
- End call: tap-to-arm (1st tap = pulse + `Icons.call_end`, 2nd tap within 3s = hang up)

**Visual states**:

| State | Icon | Color | Animation |
|---|---|---|---|
| `notStarted` | `Icons.mic_none` | grey | none |
| `waitingForResponse` | `Icons.mic` | blue | none (instant transition) |
| `connected` | `Icons.mic` | blue | pulsing glow |
| `connected` + armed | `Icons.call_end` | red | depleting countdown arc (3s) |

**Size**: 48dp visible, 56dp hit area. Default position: (15, 80).
**Position keys**: `voice-p-pos` (portrait), `voice-l-pos` (landscape) via `bind.setLocalFlutterOption`.

---

## Feature B: Transparent Joycon Overlay (L + R)

**Widget**: `CustomPaint` with `_JoyconPainter`, wrapped in `IgnorePointer` + `AnimatedOpacity`.

**GamepadModel addition**: `RxSet<int> pressedButtons` — tracked in `_onButton()` BEFORE early returns.

### Joy-Con L/R mirroring

The overlay renders both Joy-Con L and R. The side is determined by `GamepadModel.config.side`:
- **Body shape**: Separate path drawing for L/R (grip radius swaps sides)
- **Button zones**: Separate constants for L/R triggers (`_triggerL`/`_triggerR`), bumpers (`_bumperL`/`_bumperR`), stick click (`_stickL`/`_stickR`)
- **Keycodes**: L uses L1(102), L2(104), Thumbl(106); R uses R1(103), R2(105), Thumbr(107)

### Config-driven labels

Button labels are no longer hardcoded. Each `_BtnZone` has a `logicalButton` field. Labels are computed via:
```
config.getAction(logicalButton, zlHeld=false, zrHeld=false) → GamepadActions.shortLabel()
```

For modifier layers, the overlay shows the ZL/ZR layer label when the modifier is held:
```
config.getAction(logicalButton, zlHeld=true) → shortLabel() for ZL layer
```

### Button layout (labels from config, not hardcoded)

| Zone | Joy-Con L Keycodes | Joy-Con R Keycodes | Default Label (normal) |
|---|---|---|---|
| Trigger | 104 (L2) | 105 (R2) | Scroll |
| Bumper | 102 (L1) | 103 (R1) | Click |
| D-pad Up | 19, 99 | 19, 99 | ↑ |
| D-pad Down | 20, 97 | 20, 97 | ↓ |
| D-pad Left | 21, 100 | 21, 100 | ← |
| D-pad Right | 22, 96 | 22, 96 | → |
| Stick click | 106 (Thumbl) | 107 (Thumbr) | RClk |
| Menu (minus/plus) | 109 | 109 | Bksp |
| Home | 108, 110 | 108, 110 | Enter |

**Behavior**:
- Auto-fade to 35% opacity after 15s without button input
- Hidden in landscape
- Toggle: Settings > Gamepad > Show Button Overlay (`gamepad-show-overlay`)
- `shouldRepaint` compares `pressedButtons`, `batteryLevel`, and full `config.toJsonString()` (catches layer/mode/side changes)

**Position**: Draggable via grip bar at top. Default: bottom-left. Position persisted per orientation (`joycon-p-pos`, `joycon-l-pos` via `bind.setLocalFlutterOption`).

### Voice call button visibility

The `FloatingVoiceCallButton` is conditionally rendered in `remote_page.dart`:
```dart
if (bind.mainGetLocalOption(key: 'show-voice-call-button') != 'N')
```
Controlled by: Settings > Voice Call > Show voice call button (local option, shown by default).

Note: auto-accept configuration is desktop-only (Settings > General > Other checkbox). The server-side check in `connection.rs` reads the desktop's `Nomad2.toml`, so a mobile toggle would have no effect.

---

## Build

```bash
# Dart-only (no Rust rebuild needed)
cd ~/rustdesk/flutter
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Test Checklist

- [ ] Voice button visible in touch AND mouse mode
- [ ] Voice button drag + position persistence per orientation
- [ ] Voice call states: grey -> blue -> blue+glow -> red+countdown arc (armed)
- [ ] Tap-to-arm hangup (3s timeout)
- [ ] Blocked rect prevents remote click-through
- [ ] Joycon overlay visible when gamepad + setting enabled
- [ ] Button highlights match physical presses
- [ ] IgnorePointer: overlay doesn't block touch
- [ ] Auto-fade after 15s inactivity
- [ ] Hidden in landscape
- [ ] No crash on rotation
- [ ] 60fps maintained
