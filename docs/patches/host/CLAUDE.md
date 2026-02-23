# Host Patch: Voice Call Auto-Accept + Close Signaling + Audio Diagnostics

Patch for RustDesk 1.4.5 desktop (Linux/Windows). Modifies `src/server/connection.rs` and `src/client.rs` (~162 lines).

## Overview

1. **Auto-accept**: When `voice-call-auto-accept` config flag is `"Y"`, incoming voice calls are accepted automatically without showing the CM dialog. Calls `handle_voice_call(true)` directly.

2. **Close signaling**: When the client hangs up, the server now logs `"Voice call closed"` and sends `VoiceCallRequest(is_connect=false)` back to the client, telling it to stop audio capture. Without this, the Android client continues sending audio indefinitely after hangup.

3. **Audio frame counter** (`connection.rs`): Tracks `voice_audio_frame_count` on the server side. Logs every 250th frame with data length. Resets on call accept. Helps diagnose audio pipeline issues.

4. **Audio decoder guard** (`client.rs`): Returns early from `handle_frame()` if `audio_decoder` is None — prevents panic when frames arrive before format is received.

5. **Audio diagnostics** (`client.rs`): Logs frame count + RMS level every 250 frames on the client side. Enhanced `recved audio format` log to include channels. Logs total frame count on decoder loop exit.

## Why These Patches Are Needed

### Problem 1: Manual Accept Breaks Mobile Voice Workflow
By default, RustDesk shows a Connection Manager (CM) dialog on the desktop when a mobile client initiates a voice call. This requires the user to click "Accept" on the desktop, which defeats the purpose of hands-free mobile voice coding. The auto-accept patch allows companion tools to detect voice calls via log patterns and accept them automatically without user intervention.

### Problem 2: Android Keeps Sending Audio After Hangup
When the Android client hangs up a voice call (via floating button or back navigation), the server's `close_voice_call()` method is called but **does not notify the client**. Result: Android microphone stays open and continues streaming audio data indefinitely. The close signaling patch sends `VoiceCallRequest(is_connect=false)` back to the client to stop capture.

## RustDesk Config File Hierarchy (CRITICAL)

RustDesk uses **3 separate TOML files**, each read by different APIs:

| File | Suffix | Read by API | Purpose |
|------|--------|-------------|---------|
| `Nomad.toml` | `""` | `Config::get_id()` | Identity only (ID, keys, password) |
| `Nomad2.toml` | `"2"` | `Config::get_option()` / `Config::set_option()` | **Options (this is what we use)** |
| `Nomad_local.toml` | `"_local"` | `LocalConfig::get_option()` | UI preferences (window size, etc.) |

**Config sync behavior**:
- `--service` (root daemon) syncs its `Nomad2.toml` to `--server` (user GUI) at startup
- Root's config path: `/root/.config/rustdesk/Nomad2.toml`
- User's config is **OVERWRITTEN** on every server restart with root's config
- **Implication**: Options must be set on the root service, not the user GUI

## How to Apply

Manual edit in `src/server/connection.rs`:

### Auto-Accept (~line 3164)

**Find this code**:
```rust
// Notify the connection manager.
self.send_to_cm(Data::VoiceCallIncoming);
```

**Replace with**:
```rust
if Config::get_option("voice-call-auto-accept") == "Y" {
    log::info!("Voice call auto-accepted via config flag");
    self.handle_voice_call(true).await;
} else {
    self.send_to_cm(Data::VoiceCallIncoming);
}
```

**What this does**:
- Checks `voice-call-auto-accept` option from `Nomad2.toml` (root's config)
- If `"Y"`: calls `handle_voice_call(true)` directly (skips CM dialog)
- If not set: falls back to original behavior (shows CM dialog)
- Logs to RustDesk log file for verification

### Close Signaling (~line 3720)

**Find the `close_voice_call()` method** (around line 3720):
```rust
fn close_voice_call(&mut self) {
    // existing code...
}
```

**Add at the TOP of the method** (before existing code):
```rust
log::info!("Voice call closed");
let msg = new_voice_call_request(false);
self.send(msg).await;
```

**What this does**:
- Logs `"Voice call closed"` to RustDesk log (useful for detecting call end)
- Creates `VoiceCallRequest(is_connect=false)` message
- Sends back to client to signal audio capture should stop
- Prevents Android from continuing to stream audio after hangup

## How to Enable Auto-Accept

### Method 1: CLI (requires root)
```bash
# Set the option
sudo rustdesk --option voice-call-auto-accept Y

# Verify (should show voice-call-auto-accept = 'Y')
sudo cat /root/.config/rustdesk/Nomad2.toml | grep voice-call

# Restart RustDesk service to apply
sudo systemctl restart rustdesk
```

### Method 2: Manual edit (if CLI fails)
```bash
sudo nano /root/.config/rustdesk/Nomad2.toml
```

Add under `[options]` section:
```toml
[options]
voice-call-auto-accept = 'Y'
```

Save and restart:
```bash
sudo systemctl restart rustdesk
```

### Method 3: Desktop GUI (desktop only)
For the desktop-side user to enable auto-accept:
1. Open RustDesk desktop app
2. Settings > General > Other
3. Check "Auto-accept voice calls"
4. Restart RustDesk

**Note**: This sets the option in the **user's** config, which gets overwritten by the service. For persistent auto-accept with `--service` running, use Method 1 or 2.

## Log Patterns for Testing

These log patterns are useful for detecting state transitions:

| Pattern | Event | FSM Transition |
|---------|-------|----------------|
| `Call snapshot of display service` | Connection start | `IDLE → PHONE_MODE` |
| `Connection closed:` | Connection end | `PHONE_MODE → IDLE` |
| `recved audio format` | Voice call start | `PHONE_MODE → VOICE_CALL` |
| `Voice call closed` | Voice call end (our patch) | `VOICE_CALL → PHONE_MODE` |
| `Audio decoder loop exits` | Voice call end (fallback) | `VOICE_CALL → PHONE_MODE` |

### Verify Auto-Accept Works
```bash
# Tail RustDesk log
sudo tail -f ~/.local/share/rustdesk/log/server.log

# Expected on incoming voice call (if auto-accept enabled):
# [INFO] Voice call auto-accepted via config flag
# [INFO] recved audio format <...>

# Expected on hangup (our close signaling patch):
# [INFO] Voice call closed
```

## Known Issues (RustDesk 1.4.5)

### Voice Call Works Only Once Per Session
**Symptom**: First voice call works perfectly. Second call in the same connection crashes or fails silently.

**Root cause**: Audio state (encoder/decoder, audio capture device) is not reset between calls. When `handle_voice_call(false)` is called to end the call, cleanup is incomplete.

**Workaround**: Disconnect and reconnect RustDesk between voice calls.

**Upstream issue**: RustDesk #5847 (audio state leak)

### SIGSEGV on Second Voice Call
**Symptom**: `SIGSEGV` crash in `gtk_window_is_maximized` when attempting a second voice call.

**Root cause**: Flutter/GTK3 upstream bug. The RustDesk GUI tries to check window state after the voice call window has been destroyed but GTK3 still has a dangling reference.

**Workaround**: Same as above — disconnect and reconnect between calls.

**Upstream issue**: Flutter #98472, RustDesk #5847

### "Failed to start voice call" on Android (False Error)
**Symptom**: Android shows "Failed to start voice call" toast notification, but the call actually works (audio streams correctly).

**Root cause**: Android RustDesk client shows error toast based on timing, not actual voice call state. If `VoiceCallResponse` arrives after a timeout, it assumes failure even if the call connected.

**Workaround**: Ignore the toast. If you hear audio and the floating button shows "connected" state (pulsing blue icon), the call is working.

**Upstream issue**: RustDesk Android UI bug (false negative)

## Build & Test

### Build RustDesk Desktop (Linux)
```bash
cd ~/rustdesk
python3 build.py --flutter
```

**Build time**: ~4 minutes on modern hardware.

### Install
```bash
sudo dpkg -i ~/rustdesk/rustdesk-1.4.5.deb
```

### Test Auto-Accept
1. Apply patches, build, install
2. Enable auto-accept (see "How to Enable" section)
3. Connect from Android RustDesk client
4. Tap voice call button on Android
5. **Expected**: Desktop accepts immediately (no CM dialog), audio streams

### Test Close Signaling
1. During voice call, tap hangup on Android (red button after tap-to-arm)
2. Check Android mic icon in status bar: should **disappear** (mic released)
3. Check RustDesk log: should show `"Voice call closed"`

**Without this patch**: Android mic stays on indefinitely, log shows nothing on hangup.

## Applying to Fresh RustDesk Clone

If you're applying these patches to a fresh clone of RustDesk 1.4.5:

```bash
cd ~/rustdesk
git checkout 1.4.5

# Apply patches manually (no unified patch file for host yet)
nano src/server/connection.rs
# Apply edits as described in "How to Apply" section

# Build
python3 build.py --flutter

# Install
sudo dpkg -i ~/rustdesk/rustdesk-1.4.5.deb
```

## Standalone Testing

You can test these patches standalone:

1. Enable auto-accept on desktop (root config)
2. Connect from Android RustDesk
3. Tap voice call button
4. Verify desktop auto-accepts (no dialog)
5. Verify audio streams both ways
6. Tap hangup on Android
7. Verify Android mic releases (status bar icon disappears)

If all steps pass, patches are working correctly.

## Generating Unified Patch (Optional)

To create a unified patch file for version control:

```bash
cd ~/rustdesk
git diff src/server/connection.rs > docs/patches/host/rustdesk-voice-auto-accept.patch
```

To apply from patch file:
```bash
cd ~/rustdesk
git apply docs/patches/host/rustdesk-voice-auto-accept.patch
```

## Configuration API Reference

**Reading options** (Rust code):
```rust
use hbb_common::config::Config;

// Read option from Nomad2.toml
let value = Config::get_option("voice-call-auto-accept");
// Returns: "Y" if set, "" if not set
```

**Setting options** (CLI):
```bash
# Requires root (modifies /root/.config/rustdesk/Nomad2.toml)
sudo rustdesk --option voice-call-auto-accept Y

# To disable:
sudo rustdesk --option voice-call-auto-accept ""
```

**DO NOT USE** (wrong API):
```rust
// This reads Nomad_local.toml, NOT Nomad2.toml!
LocalConfig::get_option("voice-call-auto-accept")  // ❌ WRONG
```

## References

- RustDesk source: `src/server/connection.rs` (lines ~3164, ~3720)
- RustDesk config API: `hbb_common/src/config.rs`
- RustDesk tag: 1.4.5
- Known issues: RustDesk #5847 (audio state leak), Flutter #98472 (GTK3 crash)

## Patch Summary

- **Lines changed**: ~64 insertions (auto-accept, close signaling, audio diagnostics, i18n)
- **Files modified**: 3 (`src/server/connection.rs`, `src/client.rs`, `src/lang/fr.rs`, `src/lang/template.rs`)
- **Risk level**: Low (purely additive, falls back to original behavior if option not set)
- **Testing**: Verified on Ubuntu 22.04, RustDesk 1.4.5, Samsung S10+ Android 12
