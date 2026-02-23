import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../common.dart';
import 'model.dart';
import 'input_model.dart';
import 'platform_model.dart';
import 'gamepad_config.dart';

/// Translates gamepad input into remote desktop actions (mouse movement,
/// clicks, keys, scroll). Supports Joy-Con L and R via configurable mappings.
class GamepadModel {
  final WeakReference<FFI> parent;

  static const _channel =
      EventChannel('com.carriez.flutter_hbb/gamepad_events');

  StreamSubscription? _subscription;
  Timer? _moveTimer;

  // Stick axis state
  double _axisX = 0;
  double _axisY = 0;

  // Fractional remainder from truncation — accumulates across ticks so small movements are not lost
  double _deltaRemainderX = 0;
  double _deltaRemainderY = 0;

  // Scroll state (modifier + stick)
  double _scrollRemainderY = 0;
  int _scrollTickCounter = 0;

  // ZL modifier state (can come from KeyEvent or MotionEvent AXIS_LTRIGGER)
  bool _zlHeld = false;
  bool _zlFromKey = false;

  // ZR modifier state (can come from KeyEvent or MotionEvent AXIS_RTRIGGER)
  bool _zrHeld = false;
  bool _zrFromKey = false;

  // Bumper modifier state (digital-only, no FromKey needed)
  bool _lHeld = false;
  bool _rHeld = false;

  // Keycodes with a mouse button held down (for drag support)
  final Map<int, MouseButtons> _heldMouseButtons = {};

  // Cursor initialization (Point 2: center on first use)
  bool _cursorInitialized = false;

  // Long press timers and state (Point 4)
  Timer? _zlLpTimer;
  Timer? _zrLpTimer;
  Timer? _lLpTimer;
  Timer? _rLpTimer;
  bool _zlLpFired = false;
  bool _zrLpFired = false;
  bool _lLpFired = false;
  bool _rLpFired = false;
  static const _longPressDuration = Duration(milliseconds: 500);

  // Track whether a modifier was used for a combo (another button pressed while held).
  // Tap action fires on release only if: not used as modifier AND held < 300ms.
  bool _zlUsedAsModifier = false;
  bool _zrUsedAsModifier = false;
  bool _lUsedAsModifier = false;
  bool _rUsedAsModifier = false;

  // Timestamps for modifier key-down — used to distinguish quick tap from hold
  DateTime? _zlDownTime;
  DateTime? _zrDownTime;
  DateTime? _lDownTime;
  DateTime? _rDownTime;
  static const _modifierTapThreshold = Duration(milliseconds: 300);

  /// Returns true if the modifier was held for less than [_modifierTapThreshold].
  bool _wasQuickTap(DateTime? downTime) {
    if (downTime == null) return false;
    return DateTime.now().difference(downTime) < _modifierTapThreshold;
  }

  /// Observable set of currently-pressed button keycodes (for UI overlay).
  final RxSet<int> pressedButtons = <int>{}.obs;

  /// Battery level: 0-100, or -1 if no data received (API < 31, device absent, or no battery).
  final RxInt batteryLevel = (-1).obs;

  // Cached settings (refreshed on start, not every tick)
  double _mouseSpeed = 1.5;
  double _scrollSpeed = 1.0;
  bool _rotateAxes = false;

  // Config-driven mappings
  GamepadConfig _config = GamepadConfig.defaultLeft();

  void _resetMovementState() {
    _scrollRemainderY = 0;
    _scrollTickCounter = 0;
    _deltaRemainderX = 0;
    _deltaRemainderY = 0;
  }

  // Acceleration parameters
  static const double _baseSpeed = 1.0;
  static const double _maxSpeed = 25.0;
  static const double _accelPower = 2.5;
  static const int _tickMs = 16; // ~60fps

  // Android keycodes (values match android.view.KeyEvent constants).
  // Public so the Joy-Con overlay can reference them without duplication.
  static const int kDpadUp = 19;
  static const int kDpadDown = 20;
  static const int kDpadLeft = 21;
  static const int kDpadRight = 22;
  static const int kButtonA = 96;
  static const int kButtonB = 97;
  static const int kButtonX = 99;
  static const int kButtonY = 100;
  static const int kButtonL1 = 102;
  static const int kButtonL2 = 104;
  static const int kButtonThumbl = 106;
  static const int kButtonR1 = 103;
  static const int kButtonR2 = 105;
  static const int kButtonThumbr = 107;
  static const int kButtonSelect = 109;
  static const int kButtonStart = 108;
  static const int kButtonMode = 110;

  /// Sentinel keycode added to [pressedButtons] when stick axes are active
  /// (magnitude > deadzone). Used by the overlay to highlight the stick circle.
  static const int kStickActive = -1;

  GamepadModel(this.parent);

  /// Current config (for overlay to read side, layers, labels).
  GamepadConfig get config => _config;

  void refreshSettings() {
    final v = bind.mainGetLocalOption(key: 'gamepad-mouse-speed');
    _mouseSpeed = double.tryParse(v) ?? 1.5;
    final sv = bind.mainGetLocalOption(key: 'gamepad-scroll-speed');
    _scrollSpeed = double.tryParse(sv) ?? 1.0;
    _rotateAxes = bind.mainGetLocalOption(key: 'gamepad-rotate-axes') == 'Y';
    _loadConfig();
  }

  void _loadConfig() {
    final jsonStr = bind.mainGetLocalOption(key: 'gamepad-mappings');
    if (jsonStr.isNotEmpty) {
      _config = GamepadConfig.fromJsonString(jsonStr);
    } else {
      // Default based on saved side preference
      final side = bind.mainGetLocalOption(key: 'gamepad-side');
      _config = GamepadConfig.defaultFor(
          side == 'right' ? JoyConSide.right : JoyConSide.left);
    }
  }

  /// Reload config from storage (called by settings page after changes).
  void reloadConfig() {
    final ffi = parent.target;
    if (ffi != null && !ffi.closed) {
      for (final button in _heldMouseButtons.values) {
        ffi.inputModel.tapUp(button);
      }
    }
    _heldMouseButtons.clear();
    _loadConfig();
  }

  void start() {
    if (_subscription != null && _moveTimer != null) return;
    // Cancel any stale state from a partial stop
    _subscription?.cancel();
    _moveTimer?.cancel();
    refreshSettings();
    _subscription = _channel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) {
        debugPrint('Gamepad stream error: $e');
        stop();
      },
      onDone: () {
        _subscription = null;
        stop();
      },
    );
    _moveTimer = Timer.periodic(
      Duration(milliseconds: _tickMs),
      (_) => _tickMouseMove(),
    );
  }

  void stop() {
    // Release any held mouse buttons before cleanup
    final ffi = parent.target;
    if (ffi != null && !ffi.closed) {
      for (final button in _heldMouseButtons.values) {
        ffi.inputModel.tapUp(button);
      }
    }
    _heldMouseButtons.clear();
    _subscription?.cancel();
    _subscription = null;
    _moveTimer?.cancel();
    _moveTimer = null;
    _axisX = 0;
    _axisY = 0;
    _resetMovementState();
    _zlHeld = false;
    _zlFromKey = false;
    _zrHeld = false;
    _zrFromKey = false;
    _lHeld = false;
    _rHeld = false;
    _cursorInitialized = false;
    _zlLpTimer?.cancel();
    _zrLpTimer?.cancel();
    _lLpTimer?.cancel();
    _rLpTimer?.cancel();
    _zlLpTimer = null;
    _zrLpTimer = null;
    _lLpTimer = null;
    _rLpTimer = null;
    _zlLpFired = false;
    _zrLpFired = false;
    _lLpFired = false;
    _rLpFired = false;
    _zlUsedAsModifier = false;
    _zrUsedAsModifier = false;
    _lUsedAsModifier = false;
    _rUsedAsModifier = false;
    _zlDownTime = null;
    _zrDownTime = null;
    _lDownTime = null;
    _rDownTime = null;
    pressedButtons.clear();
    batteryLevel.value = -1;
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final ffi = parent.target;
    if (ffi == null || ffi.closed) return;

    final type = event['type'] as String?;

    if (type == 'axis') {
      var x = (event['x'] as num?)?.toDouble() ?? 0;
      var y = (event['y'] as num?)?.toDouble() ?? 0;

      // Axis rotation for horizontal Joy-Con mode
      if (_rotateAxes) {
        final tmp = x;
        x = -y;
        y = tmp;
      }

      _axisX = x;
      _axisY = y;

      // Track stick activity for UI overlay (sentinel keycode)
      final magnitude = sqrt(x * x + y * y);
      final isActive = magnitude > 0.15;
      final wasActive = pressedButtons.contains(kStickActive);
      if (isActive && !wasActive) {
        pressedButtons.add(kStickActive);
      } else if (!isActive && wasActive) {
        pressedButtons.remove(kStickActive);
      }

      // ZL via MotionEvent (AXIS_LTRIGGER) — only if not already set by KeyEvent
      final ltrigger = (event['ltrigger'] as num?)?.toDouble() ?? 0;
      if (!_zlFromKey) {
        if (ltrigger > 0.5) {
          _zlHeld = true;
        } else if (ltrigger < 0.1) {
          _zlHeld = false;
        }
      }

      // ZR via MotionEvent (AXIS_RTRIGGER) — only if not already set by KeyEvent
      final rtrigger = (event['rtrigger'] as num?)?.toDouble() ?? 0;
      if (!_zrFromKey) {
        if (rtrigger > 0.5) {
          _zrHeld = true;
        } else if (rtrigger < 0.1) {
          _zrHeld = false;
        }
      }
    } else if (type == 'button') {
      _onButton(
        ffi,
        (event['keyCode'] as num?)?.toInt() ?? 0,
        event['action'] as String? ?? '',
      );
    } else if (type == 'battery') {
      final level = (event['level'] as num?)?.toInt() ?? -1;
      if (level != batteryLevel.value) {
        batteryLevel.value = level;
      }
    }
  }

  /// Map Android keycode to logical button name, respecting Joy-Con side.
  String? _toLogicalButton(int keyCode) {
    switch (keyCode) {
      // D-pad and face buttons (same keycodes for both sides)
      case kDpadUp:
      case kButtonX:
        return LogicalButton.dpadUp;
      case kDpadDown:
      case kButtonB:
        return LogicalButton.dpadDown;
      case kDpadLeft:
      case kButtonY:
        return LogicalButton.dpadLeft;
      case kDpadRight:
      case kButtonA:
        return LogicalButton.dpadRight;
      // Side-dependent buttons: bumper
      case kButtonL1:
        return _config.side == JoyConSide.left ? LogicalButton.bumper : null;
      case kButtonR1:
        return _config.side == JoyConSide.right ? LogicalButton.bumper : null;
      // Side-dependent buttons: thumbstick click
      case kButtonThumbl:
        return _config.side == JoyConSide.left ? LogicalButton.thumbstick : null;
      case kButtonThumbr:
        return _config.side == JoyConSide.right ? LogicalButton.thumbstick : null;
      // Menu buttons (shared keycodes)
      case kButtonSelect:
        return LogicalButton.menuMinus;
      case kButtonMode:
      case kButtonStart:
        return LogicalButton.menuHome;
      default:
        return null;
    }
  }

  /// Check if a keycode is a trigger (ZL or ZR).
  bool _isTrigger(int keyCode) {
    return keyCode == kButtonL2 || keyCode == kButtonR2;
  }

  void _tickMouseMove() {
    final ffi = parent.target;
    if (ffi == null || ffi.closed) {
      stop();
      return;
    }

    // Center cursor on first use (before any movement)
    if (!_cursorInitialized) {
      final displayRect = ffi.ffiModel.rect;
      if (displayRect != null && displayRect.width > 0 && displayRect.height > 0) {
        ffi.cursorModel.moveByDelta(displayRect.center.dx, displayRect.center.dy);
        _cursorInitialized = true;
      }
    }

    if (_axisX == 0 && _axisY == 0) return;

    if (!ffi.ffiModel.keyboard) return;
    if (ffi.connType == ConnType.viewCamera) return;

    // Check what the stick should do based on config and current modifiers
    final stickAction = _config.getAction(LogicalButton.stick,
        zlHeld: _zlHeld, zrHeld: _zrHeld, lHeld: _lHeld, rHeld: _rHeld);

    if (stickAction == 'scroll') {
      _tickScroll(ffi);
      return;
    }

    // Default: mouse move
    final magnitude =
        sqrt(_axisX * _axisX + _axisY * _axisY).clamp(0.0, 1.0);
    final speed =
        (_baseSpeed + (_maxSpeed - _baseSpeed) * pow(magnitude, _accelPower)) *
            _mouseSpeed;

    final angle = atan2(_axisY, _axisX);
    final dx = cos(angle) * speed * magnitude;
    final dy = sin(angle) * speed * magnitude;

    _sendMouseMove(ffi, dx, dy);
  }

  void _sendMouseMove(FFI ffi, double dx, double dy) {
    _deltaRemainderX += dx;
    _deltaRemainderY += dy;
    final x = _deltaRemainderX.truncate();
    final y = _deltaRemainderY.truncate();
    _deltaRemainderX -= x;
    _deltaRemainderY -= y;
    if (x == 0 && y == 0) return;

    ffi.cursorModel.moveByDelta(x.toDouble(), y.toDouble());
  }

  void _tickScroll(FFI ffi) {
    _scrollTickCounter++;
    // Throttle scroll to ~15fps — scrolling at 60fps overshoots on most UIs
    if (_scrollTickCounter % 4 != 0) return;

    final scrollSpeed = 3.0 * _scrollSpeed;
    _scrollRemainderY += _axisY * scrollSpeed;
    final y = _scrollRemainderY.truncate();
    _scrollRemainderY -= y;
    if (y == 0) return;

    bind.sessionSendMouse(
      sessionId: ffi.sessionId,
      msg: json.encode({
        'type': 'wheel',
        'y': '$y',
      }),
    );
  }

  void _onButton(FFI ffi, int keyCode, String action) {
    final isDown = action == 'down';

    // Track pressed state for UI overlay (before any early returns)
    if (isDown) {
      pressedButtons.add(keyCode);
    } else {
      pressedButtons.remove(keyCode);
    }

    // Handle triggers (ZL/ZR)
    if (_isTrigger(keyCode)) {
      _handleTrigger(keyCode, isDown, ffi);
      return;
    }

    // Mark held modifiers as "used for combo" when any other button is pressed.
    // This prevents the modifier's tap action from firing on release.
    if (isDown) {
      if (_zlHeld) _zlUsedAsModifier = true;
      if (_zrHeld) _zrUsedAsModifier = true;
      if (_lHeld) _lUsedAsModifier = true;
      if (_rHeld) _rUsedAsModifier = true;
    }

    // Handle bumper when in modifier mode (intercept before normal button path)
    if (keyCode == kButtonL1 && _config.side == JoyConSide.left && _config.lMode == TriggerMode.modifier) {
      if (isDown && !_lHeld) {
        _resetMovementState();
        _lUsedAsModifier = false;
      }
      if (isDown && _lDownTime == null) {
        _lDownTime = DateTime.now();
      }
      _lHeld = isDown;
      if (!isDown) {
        if (!_lUsedAsModifier && _wasQuickTap(_lDownTime)) {
          final tapAction = _config.lAction;
          if (tapAction.isNotEmpty && tapAction != 'none' && ffi.ffiModel.keyboard) {
            _executeAction(ffi.inputModel, tapAction);
          }
        }
        _lDownTime = null;
      }
      return;
    }
    if (keyCode == kButtonR1 && _config.side == JoyConSide.right && _config.rMode == TriggerMode.modifier) {
      if (isDown && !_rHeld) {
        _resetMovementState();
        _rUsedAsModifier = false;
      }
      if (isDown && _rDownTime == null) {
        _rDownTime = DateTime.now();
      }
      _rHeld = isDown;
      if (!isDown) {
        if (!_rUsedAsModifier && _wasQuickTap(_rDownTime)) {
          final tapAction = _config.rAction;
          if (tapAction.isNotEmpty && tapAction != 'none' && ffi.ffiModel.keyboard) {
            _executeAction(ffi.inputModel, tapAction);
          }
        }
        _rDownTime = null;
      }
      return;
    }

    // Handle bumper long press in action mode
    if (keyCode == kButtonL1 && _config.side == JoyConSide.left) {
      final longAction = _config.lLongAction;
      if (longAction.isNotEmpty && longAction != 'none') {
        if (isDown) {
          _lLpFired = false;
          _lLpTimer?.cancel();
          final weakRef = parent;
          _lLpTimer = Timer(_longPressDuration, () {
            _lLpFired = true;
            final f = weakRef.target;
            if (f != null && !f.closed && f.ffiModel.keyboard) {
              _executeAction(f.inputModel, longAction);
            }
          });
        } else {
          _lLpTimer?.cancel();
          _lLpTimer = null;
          if (!_lLpFired && ffi.ffiModel.keyboard) {
            final actionStr = _config.getAction(LogicalButton.bumper,
                zlHeld: _zlHeld, zrHeld: _zrHeld, lHeld: _lHeld, rHeld: _rHeld);
            _executeAction(ffi.inputModel, actionStr);
          }
          _lLpFired = false;
        }
        return;
      }
    }
    if (keyCode == kButtonR1 && _config.side == JoyConSide.right) {
      final longAction = _config.rLongAction;
      if (longAction.isNotEmpty && longAction != 'none') {
        if (isDown) {
          _rLpFired = false;
          _rLpTimer?.cancel();
          final weakRef = parent;
          _rLpTimer = Timer(_longPressDuration, () {
            _rLpFired = true;
            final f = weakRef.target;
            if (f != null && !f.closed && f.ffiModel.keyboard) {
              _executeAction(f.inputModel, longAction);
            }
          });
        } else {
          _rLpTimer?.cancel();
          _rLpTimer = null;
          if (!_rLpFired && ffi.ffiModel.keyboard) {
            final actionStr = _config.getAction(LogicalButton.bumper,
                zlHeld: _zlHeld, zrHeld: _zrHeld, lHeld: _lHeld, rHeld: _rHeld);
            _executeAction(ffi.inputModel, actionStr);
          }
          _rLpFired = false;
        }
        return;
      }
    }

    // Release held mouse button on UP
    if (!isDown) {
      _releaseHeldMouse(ffi, keyCode);
      return;
    }

    if (!ffi.ffiModel.keyboard) return;

    // Map keycode to logical button
    final logical = _toLogicalButton(keyCode);
    if (logical == null) return;

    // Look up action from config
    final actionStr = _config.getAction(logical,
        zlHeld: _zlHeld, zrHeld: _zrHeld, lHeld: _lHeld, rHeld: _rHeld);
    _holdMouseOrExecute(ffi, keyCode, actionStr);
  }

  void _handleTrigger(int keyCode, bool isDown, FFI ffi) {
    if (keyCode == kButtonL2) {
      // Check if ZL is in action mode
      if (_config.zlMode == TriggerMode.action) {
        if (isDown) {
          _zlHeld = true;
          _zlFromKey = true;
          if (ffi.ffiModel.keyboard) {
            final longAction = _config.zlLongAction;
            if (longAction.isNotEmpty && longAction != 'none') {
              _zlLpFired = false;
              _zlLpTimer?.cancel();
              final weakRef = parent;
              _zlLpTimer = Timer(_longPressDuration, () {
                _zlLpFired = true;
                final f = weakRef.target;
                if (f != null && !f.closed && f.ffiModel.keyboard) {
                  _executeAction(f.inputModel, longAction);
                }
              });
            } else {
              _holdMouseOrExecute(ffi, keyCode, _config.zlAction);
            }
          }
        } else {
          _zlHeld = false;
          _zlFromKey = false;
          final longAction = _config.zlLongAction;
          if (longAction.isNotEmpty && longAction != 'none') {
            _zlLpTimer?.cancel();
            _zlLpTimer = null;
            if (!_zlLpFired && ffi.ffiModel.keyboard) {
              _executeAction(ffi.inputModel, _config.zlAction);
            }
            _zlLpFired = false;
          } else {
            _releaseHeldMouse(ffi, keyCode);
          }
        }
        return;
      }
      // Modifier mode
      if (isDown && !_zlHeld) {
        _resetMovementState();
        _zlUsedAsModifier = false;
      }
      // Always record timestamp on first key-down (covers analog/digital race)
      if (isDown && _zlDownTime == null) {
        _zlDownTime = DateTime.now();
      }
      _zlHeld = isDown;
      _zlFromKey = isDown;
      if (!isDown) {
        // Tap action: only if not used as modifier AND was a quick tap
        if (!_zlUsedAsModifier && _wasQuickTap(_zlDownTime)) {
          final tapAction = _config.zlAction;
          if (tapAction.isNotEmpty && tapAction != 'none' && ffi.ffiModel.keyboard) {
            _executeAction(ffi.inputModel, tapAction);
          }
        }
        _zlDownTime = null;
      }
    } else if (keyCode == kButtonR2) {
      // Check if ZR is in action mode
      if (_config.zrMode == TriggerMode.action) {
        if (isDown) {
          _zrHeld = true;
          _zrFromKey = true;
          if (ffi.ffiModel.keyboard) {
            final longAction = _config.zrLongAction;
            if (longAction.isNotEmpty && longAction != 'none') {
              _zrLpFired = false;
              _zrLpTimer?.cancel();
              final weakRef = parent;
              _zrLpTimer = Timer(_longPressDuration, () {
                _zrLpFired = true;
                final f = weakRef.target;
                if (f != null && !f.closed && f.ffiModel.keyboard) {
                  _executeAction(f.inputModel, longAction);
                }
              });
            } else {
              _holdMouseOrExecute(ffi, keyCode, _config.zrAction);
            }
          }
        } else {
          _zrHeld = false;
          _zrFromKey = false;
          final longAction = _config.zrLongAction;
          if (longAction.isNotEmpty && longAction != 'none') {
            _zrLpTimer?.cancel();
            _zrLpTimer = null;
            if (!_zrLpFired && ffi.ffiModel.keyboard) {
              _executeAction(ffi.inputModel, _config.zrAction);
            }
            _zrLpFired = false;
          } else {
            _releaseHeldMouse(ffi, keyCode);
          }
        }
        return;
      }
      // Modifier mode
      if (isDown && !_zrHeld) {
        _resetMovementState();
        _zrUsedAsModifier = false;
      }
      // Always record timestamp on first key-down (covers analog/digital race)
      if (isDown && _zrDownTime == null) {
        _zrDownTime = DateTime.now();
      }
      _zrHeld = isDown;
      _zrFromKey = isDown;
      if (!isDown) {
        // Tap action: only if not used as modifier AND was a quick tap
        if (!_zrUsedAsModifier && _wasQuickTap(_zrDownTime)) {
          final tapAction = _config.zrAction;
          if (tapAction.isNotEmpty && tapAction != 'none' && ffi.ffiModel.keyboard) {
            _executeAction(ffi.inputModel, tapAction);
          }
        }
        _zrDownTime = null;
      }
    }
  }

  /// Convert a mouse GamepadAction to its MouseButtons enum value.
  static MouseButtons? _toMouseButton(GamepadAction action) {
    switch (action.mouseButton) {
      case 'left': return MouseButtons.left;
      case 'right': return MouseButtons.right;
      case 'middle': return MouseButtons.wheel;
      default: return null;
    }
  }

  /// For holdable mouse actions (left/right/middle): send tapDown and track
  /// the keyCode for release. For all other actions: delegate to _executeAction.
  void _holdMouseOrExecute(FFI ffi, int keyCode, String actionStr) {
    final action = GamepadAction(actionStr);
    if (action.isMouse && action.mouseButton != 'double') {
      final button = _toMouseButton(action);
      if (button != null) {
        final prev = _heldMouseButtons[keyCode];
        if (prev != null && prev != button) {
          ffi.inputModel.tapUp(prev);
        }
        ffi.inputModel.tapDown(button);
        _heldMouseButtons[keyCode] = button;
      }
      return;
    }
    _executeAction(ffi.inputModel, actionStr);
  }

  /// Release a held mouse button for this keyCode (if any).
  void _releaseHeldMouse(FFI ffi, int keyCode) {
    final button = _heldMouseButtons.remove(keyCode);
    if (button != null) {
      ffi.inputModel.tapUp(button);
    }
  }

  /// Execute a config action string (e.g. "VK_UP", "ctrl+VK_Z", "mouse_left", "none").
  void _executeAction(InputModel inputModel, String actionStr) {
    if (actionStr.isEmpty || actionStr == 'none') return;

    final action = GamepadAction(actionStr);

    // Single-click mouse actions (left/right/middle) use the hold/drag path
    // in _holdMouseOrExecute. Only double-click reaches here.
    if (action.isMouse) {
      if (action.mouseButton == 'double') {
        inputModel.tap(MouseButtons.left);
        final weakParent = parent;
        Future.delayed(const Duration(milliseconds: 60), () {
          final ffi = weakParent.target;
          if (ffi != null && !ffi.closed && ffi.ffiModel.keyboard) {
            ffi.inputModel.tap(MouseButtons.left);
          }
        });
      }
      return;
    }

    // mouse_move and scroll are handled by _tickMouseMove, not here
    if (action.isMouseMove || action.isScroll) return;

    // Key or combo
    final combo = action.keyCombo;
    if (combo != null) {
      final savedCtrl = inputModel.ctrl;
      final savedShift = inputModel.shift;
      final savedAlt = inputModel.alt;
      try {
        inputModel.ctrl = combo.ctrl;
        inputModel.shift = combo.shift;
        inputModel.alt = combo.alt;
        inputModel.inputKey(combo.vk);
      } finally {
        inputModel.ctrl = savedCtrl;
        inputModel.shift = savedShift;
        inputModel.alt = savedAlt;
      }
    }
  }

  void dispose() {
    stop();
  }
}
