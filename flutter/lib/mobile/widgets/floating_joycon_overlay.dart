import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/gamepad_model.dart';
import 'package:flutter_hbb/models/gamepad_config.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const double _kOverlayWidth = 100;
const double _kCanvasHeight = 230;
const double _kSpaceToEdge = 10.0;

/// Draggable Joy-Con overlay (vertical orientation) showing PC action mappings.
/// Supports both Joy-Con L and R with config-driven labels and mirrored body.
/// The entire overlay body is draggable.
class FloatingJoyconOverlay extends StatefulWidget {
  final GamepadModel gamepadModel;
  const FloatingJoyconOverlay({super.key, required this.gamepadModel});

  @override
  State<FloatingJoyconOverlay> createState() => _FloatingJoyconOverlayState();
}

class _FloatingJoyconOverlayState extends State<FloatingJoyconOverlay> {
  bool _faded = true;
  Timer? _fadeTimer;
  late final Worker _pressedWorker;

  // Drag state
  Offset _position = Offset.zero;
  bool _isInitialized = false;
  Orientation? _previousOrientation;
  Offset _preSavedPos = Offset.zero;
  bool _isDragging = false;
  Offset _pointerStart = Offset.zero;
  static const double _kDragThreshold = 8.0;

  @override
  void initState() {
    super.initState();
    _pressedWorker = ever(widget.gamepadModel.pressedButtons, (_) => _onButtonActivity());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ori = MediaQuery.of(context).orientation;
      _previousOrientation = ori;
      _resetPosition(ori);
    });
  }

  @override
  void dispose() {
    _pressedWorker.dispose();
    _fadeTimer?.cancel();
    _trySavePosition();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_previousOrientation == null ||
        _previousOrientation != currentOrientation) {
      _resetPosition(currentOrientation);
    }
    _previousOrientation = currentOrientation;
  }

  // --- Fade on inactivity ---

  void _onButtonActivity() {
    if (_faded && mounted) {
      setState(() => _faded = false);
    }
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _faded = true);
    });
  }

  // --- Position persistence ---

  String _getPositionKey(Orientation ori) {
    return 'joycon-${ori == Orientation.portrait ? 'p' : 'l'}-pos';
  }

  void _restorePosition(Orientation ori) {
    final ps = bind.getLocalFlutterOption(k: _getPositionKey(ori));
    if (ps.isNotEmpty) {
      try {
        final m = jsonDecode(ps);
        _position = Offset(
            (m['x'] as num).toDouble(), (m['y'] as num).toDouble());
        _preSavedPos = _position;
        return;
      } catch (e) {
        debugPrint('Bad saved joycon position: $e');
      }
    }
    // Default: bottom-left
    final size = MediaQuery.of(context).size;
    _position = Offset(
      _kSpaceToEdge,
      size.height - _kCanvasHeight - 100,
    );
  }

  void _trySavePosition() {
    if (_previousOrientation == null) return;
    if ((_position - _preSavedPos).distanceSquared < 0.1) return;
    final pos = jsonEncode({'x': _position.dx, 'y': _position.dy});
    bind.setLocalFlutterOption(
        k: _getPositionKey(_previousOrientation!), v: pos);
    _preSavedPos = _position;
  }

  void _resetPosition(Orientation ori) {
    setState(() {
      _restorePosition(ori);
      _isInitialized = true;
    });
  }

  // --- Drag handling ---

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDragging) {
      if ((event.position - _pointerStart).distance > _kDragThreshold) {
        _isDragging = true;
      } else {
        return;
      }
    }
    final size = MediaQuery.of(context).size;
    Offset newPos = _position + event.delta;
    newPos = Offset(
      newPos.dx.clamp(_kSpaceToEdge,
          size.width - _kOverlayWidth - _kSpaceToEdge),
      newPos.dy.clamp(_kSpaceToEdge,
          size.height - _kCanvasHeight - _kSpaceToEdge),
    );
    setState(() => _position = newPos);
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.landscape || !_isInitialized) {
      return const Positioned(child: Offstage());
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: AnimatedOpacity(
        opacity: _faded ? 0.35 : 0.95,
        duration: const Duration(milliseconds: 500),
        child: Listener(
          onPointerDown: (event) {
            _isDragging = false;
            _pointerStart = event.position;
          },
          onPointerMove: _onPointerMove,
          onPointerUp: (_) {
            if (_isDragging) _trySavePosition();
          },
          child: Obx(() {
            final pressed = widget.gamepadModel.pressedButtons.toSet();
            final config = widget.gamepadModel.config;
            return CustomPaint(
              size: const Size(_kOverlayWidth, _kCanvasHeight),
              painter: _JoyconPainter(
                pressedButtons: pressed,
                batteryLevel: widget.gamepadModel.batteryLevel.value,
                config: config,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// Shorthand aliases for GamepadModel keycodes (avoids verbose GamepadModel.kXxx in layouts)
const int _kDpadUp = GamepadModel.kDpadUp;
const int _kDpadDown = GamepadModel.kDpadDown;
const int _kDpadLeft = GamepadModel.kDpadLeft;
const int _kDpadRight = GamepadModel.kDpadRight;
const int _kButtonA = GamepadModel.kButtonA;
const int _kButtonB = GamepadModel.kButtonB;
const int _kButtonX = GamepadModel.kButtonX;
const int _kButtonY = GamepadModel.kButtonY;
const int _kButtonL1 = GamepadModel.kButtonL1;
const int _kButtonL2 = GamepadModel.kButtonL2;
const int _kButtonR1 = GamepadModel.kButtonR1;
const int _kButtonR2 = GamepadModel.kButtonR2;
const int _kButtonThumbl = GamepadModel.kButtonThumbl;
const int _kButtonThumbr = GamepadModel.kButtonThumbr;
const int _kButtonSelect = GamepadModel.kButtonSelect;
const int _kButtonStart = GamepadModel.kButtonStart;
const int _kButtonMode = GamepadModel.kButtonMode;

/// Button zone definition — layout position and associated keycodes.
/// Labels are computed at paint time from config.
class _BtnZone {
  final Offset center;
  final double radius;
  final String logicalButton; // LogicalButton name for config lookup
  final Set<int> keycodes;
  final bool isRect;
  final Size rectSize;
  final bool isTrigger; // ZL/ZR trigger (special label handling)
  final bool isStick; // stick zone (background fill)

  const _BtnZone(
    this.center,
    this.radius,
    this.logicalButton,
    this.keycodes, {
    this.isRect = false,
    this.rectSize = Size.zero,
    this.isTrigger = false,
    this.isStick = false,
  });
}

class _JoyconPainter extends CustomPainter {
  final Set<int> pressedButtons;
  final int batteryLevel;
  final GamepadConfig config;

  _JoyconPainter({
    required this.pressedButtons,
    required this.batteryLevel,
    required this.config,
  });

  bool get _isRight => config.side == JoyConSide.right;

  bool get _isModMode {
    final triggerKeycode = _isRight ? _kButtonR2 : _kButtonL2;
    final bumperKeycode = _isRight ? _kButtonR1 : _kButtonL1;
    final bumperIsModifier = _isRight
        ? config.rMode == TriggerMode.modifier
        : config.lMode == TriggerMode.modifier;
    return pressedButtons.contains(triggerKeycode) ||
        (bumperIsModifier && pressedButtons.contains(bumperKeycode));
  }

  bool get _isZlHeld => pressedButtons.contains(_kButtonL2);
  bool get _isZrHeld => pressedButtons.contains(_kButtonR2);
  bool get _isLHeld => pressedButtons.contains(_kButtonL1);
  bool get _isRHeld => pressedButtons.contains(_kButtonR1);

  // Canvas: 100 x 230 (vertical Joy-Con)
  // Layout top-to-bottom: bumpers -> minus -> stick -> d-pad diamond -> enter
  // Positions defined for L side; mirrored for R side.

  // --- Bumper buttons (top edge) ---
  // For L: ZL on left, L on right. For R: mirrored (ZR on right, R on left).
  static const _triggerL = _BtnZone(
    Offset(28, 12), 0, '', {_kButtonL2},
    isRect: true, rectSize: Size(40, 16), isTrigger: true,
  );
  static const _bumperL = _BtnZone(
    Offset(72, 12), 0, LogicalButton.bumper, {_kButtonL1},
    isRect: true, rectSize: Size(40, 16),
  );
  // R-side variants (same positions, different keycodes)
  static const _triggerR = _BtnZone(
    Offset(72, 12), 0, '', {_kButtonR2},
    isRect: true, rectSize: Size(40, 16), isTrigger: true,
  );
  static const _bumperR = _BtnZone(
    Offset(28, 12), 0, LogicalButton.bumper, {_kButtonR1},
    isRect: true, rectSize: Size(40, 16),
  );

  // --- Minus/Plus button (between bumpers and stick) ---
  static const _menu = _BtnZone(
    Offset(50, 37), 0, LogicalButton.menuMinus, {_kButtonSelect},
    isRect: true, rectSize: Size(44, 16),
  );

  // --- Stick (upper-mid face) ---
  static const _stickL = _BtnZone(
    Offset(50, 78), 24, LogicalButton.stick, {_kButtonThumbl, -1},
    isStick: true,
  );
  static const _stickR = _BtnZone(
    Offset(50, 78), 24, LogicalButton.stick, {_kButtonThumbr, -1},
    isStick: true,
  );

  // --- D-pad diamond (lower face, 4 round buttons) ---
  static const double _dpadCY = 149;
  static const double _dpadCX = 50;
  static const double _dpadR = 14;
  static const double _dpadSpread = 24;

  static const _dpadUp = _BtnZone(
    Offset(_dpadCX, _dpadCY - _dpadSpread), _dpadR, LogicalButton.dpadUp,
    {_kDpadUp, _kButtonX},
  );
  static const _dpadDown = _BtnZone(
    Offset(_dpadCX, _dpadCY + _dpadSpread), _dpadR, LogicalButton.dpadDown,
    {_kDpadDown, _kButtonB},
  );
  static const _dpadLeft = _BtnZone(
    Offset(_dpadCX - _dpadSpread, _dpadCY), _dpadR, LogicalButton.dpadLeft,
    {_kDpadLeft, _kButtonY},
  );
  static const _dpadRight = _BtnZone(
    Offset(_dpadCX + _dpadSpread, _dpadCY), _dpadR, LogicalButton.dpadRight,
    {_kDpadRight, _kButtonA},
  );

  // --- Enter button (bottom) ---
  static const _enter = _BtnZone(
    Offset(50, 204), 0, LogicalButton.menuHome, {_kButtonStart, _kButtonMode},
    isRect: true, rectSize: Size(44, 16),
  );

  List<_BtnZone> _getButtons() {
    if (_isRight) {
      return [
        _triggerR, _bumperR,
        _menu,
        _stickR,
        _dpadUp, _dpadDown, _dpadLeft, _dpadRight,
        _enter,
      ];
    }
    return [
      _triggerL, _bumperL,
      _menu,
      _stickL,
      _dpadUp, _dpadDown, _dpadLeft, _dpadRight,
      _enter,
    ];
  }

  String _getLabelForButton(_BtnZone btn) {
    if (btn.isTrigger) {
      // Trigger button: show MOD (with optional tap action) or action label
      final isZl = btn.keycodes.contains(_kButtonL2);
      final mode = isZl ? config.zlMode : config.zrMode;
      if (mode == TriggerMode.modifier) {
        final tapAction = isZl ? config.zlAction : config.zrAction;
        if (tapAction.isNotEmpty && tapAction != 'none') {
          return 'MOD/${GamepadActions.shortLabel(tapAction)}';
        }
        return 'MOD';
      }
      final shortAction = isZl ? config.zlAction : config.zrAction;
      final longAction = isZl ? config.zlLongAction : config.zrLongAction;
      final shortLabel = GamepadActions.shortLabel(shortAction);
      if (longAction.isNotEmpty && longAction != 'none') {
        return '$shortLabel/${GamepadActions.shortLabel(longAction)}';
      }
      return shortLabel;
    }

    // Bumper in modifier mode shows 'MOD' (with optional tap action)
    if (btn.logicalButton == LogicalButton.bumper) {
      final bumperMode = _isRight ? config.rMode : config.lMode;
      if (bumperMode == TriggerMode.modifier) {
        final tapAction = _isRight ? config.rAction : config.lAction;
        if (tapAction.isNotEmpty && tapAction != 'none') {
          return 'MOD/${GamepadActions.shortLabel(tapAction)}';
        }
        return 'MOD';
      }
      // Long press label for bumpers
      final longAction = _isRight ? config.rLongAction : config.lLongAction;
      if (longAction.isNotEmpty && longAction != 'none') {
        final action = config.getAction(btn.logicalButton,
            zlHeld: _isZlHeld, zrHeld: _isZrHeld, lHeld: _isLHeld, rHeld: _isRHeld);
        final shortLabel = GamepadActions.shortLabel(action);
        return '$shortLabel/${GamepadActions.shortLabel(longAction)}';
      }
    }

    // For stick: show movement action + click action
    if (btn.logicalButton == LogicalButton.stick) {
      final stickAction = config.getAction(LogicalButton.stick,
          zlHeld: _isZlHeld, zrHeld: _isZrHeld, lHeld: _isLHeld, rHeld: _isRHeld);
      final stickLabel = GamepadActions.shortLabel(stickAction);
      final clickAction = config.getAction(LogicalButton.thumbstick,
          zlHeld: _isZlHeld, zrHeld: _isZrHeld, lHeld: _isLHeld, rHeld: _isRHeld);
      final clickLabel = GamepadActions.shortLabel(clickAction);
      if (clickLabel.isNotEmpty) return '$stickLabel\n$clickLabel';
      return stickLabel;
    }

    // Regular button: look up from config with all modifier states
    final action = config.getAction(btn.logicalButton,
        zlHeld: _isZlHeld, zrHeld: _isZrHeld, lHeld: _isLHeld, rHeld: _isRHeld);
    return GamepadActions.shortLabel(action);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final isModMode = _isModMode;

    // --- Joy-Con body shape ---
    // For L: left=rounded grip, right=flatter rail
    // For R: mirrored (right=rounded grip, left=flatter rail)
    final bodyPath = Path();
    const double top = 4;
    const double bot = 226;
    const double left = 4;
    const double right = 96;
    const double gripR = 40.0;
    const double railR = 12.0;

    if (_isRight) {
      // R side: grip on right, rail on left
      bodyPath.moveTo(left + railR, top);
      bodyPath.lineTo(right - gripR, top);
      bodyPath.arcToPoint(Offset(right, top + gripR),
          radius: const Radius.circular(gripR));
      bodyPath.lineTo(right, bot - gripR);
      bodyPath.arcToPoint(Offset(right - gripR, bot),
          radius: const Radius.circular(gripR));
      bodyPath.lineTo(left + railR, bot);
      bodyPath.arcToPoint(Offset(left, bot - railR),
          radius: const Radius.circular(railR));
      bodyPath.lineTo(left, top + railR);
      bodyPath.arcToPoint(Offset(left + railR, top),
          radius: const Radius.circular(railR));
    } else {
      // L side: grip on left, rail on right
      bodyPath.moveTo(left + gripR, top);
      bodyPath.lineTo(right - railR, top);
      bodyPath.arcToPoint(Offset(right, top + railR),
          radius: const Radius.circular(railR));
      bodyPath.lineTo(right, bot - railR);
      bodyPath.arcToPoint(Offset(right - railR, bot),
          radius: const Radius.circular(railR));
      bodyPath.lineTo(left + gripR, bot);
      bodyPath.arcToPoint(Offset(left, bot - gripR),
          radius: const Radius.circular(gripR));
      bodyPath.lineTo(left, top + gripR);
      bodyPath.arcToPoint(Offset(left + gripR, top),
          radius: const Radius.circular(gripR));
    }
    bodyPath.close();

    // Body fill
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );

    // Body border (blue in MOD mode)
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = isModMode
            ? Color(0xFF6366F1).withOpacity(0.8)
            : Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // --- Draw all buttons ---
    final btnBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final pressedFill = Paint()
      ..color = Color(0xFF6366F1).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
      shadows: [
        Shadow(blurRadius: 3, color: Colors.black),
        Shadow(blurRadius: 1, color: Colors.black),
      ],
    );

    const modLabelStyle = TextStyle(
      color: Color(0xFF90CAF9),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
      shadows: [
        Shadow(blurRadius: 3, color: Colors.black),
        Shadow(blurRadius: 1, color: Colors.black),
      ],
    );

    final buttons = _getButtons();
    for (final btn in buttons) {
      final isPressed = btn.keycodes.any(pressedButtons.contains);
      final label = _getLabelForButton(btn);
      // Use mod style when a modifier layer is active and the label differs from normal
      final String normalLabel;
      if (btn.isTrigger) {
        final isZl = btn.keycodes.contains(_kButtonL2);
        final mode = isZl ? config.zlMode : config.zrMode;
        if (mode == TriggerMode.modifier) {
          final tapAction = isZl ? config.zlAction : config.zrAction;
          normalLabel = (tapAction.isNotEmpty && tapAction != 'none')
              ? 'MOD/${GamepadActions.shortLabel(tapAction)}'
              : 'MOD';
        } else {
          final shortLabel = GamepadActions.shortLabel(isZl ? config.zlAction : config.zrAction);
          final longAction = isZl ? config.zlLongAction : config.zrLongAction;
          normalLabel = (longAction.isNotEmpty && longAction != 'none')
              ? '$shortLabel/${GamepadActions.shortLabel(longAction)}'
              : shortLabel;
        }
      } else if (btn.logicalButton == LogicalButton.bumper &&
          (_isRight ? config.rMode : config.lMode) == TriggerMode.modifier) {
        final tapAction = _isRight ? config.rAction : config.lAction;
        normalLabel = (tapAction.isNotEmpty && tapAction != 'none')
            ? 'MOD/${GamepadActions.shortLabel(tapAction)}'
            : 'MOD';
      } else {
        normalLabel = GamepadActions.shortLabel(config.getAction(btn.logicalButton));
      }
      final style = (isModMode && label != normalLabel)
          ? modLabelStyle
          : labelStyle;

      if (btn.isRect) {
        final rect = Rect.fromCenter(
          center: btn.center,
          width: btn.rectSize.width,
          height: btn.rectSize.height,
        );
        final RRect rrect;
        if (btn.isTrigger) {
          // Asymmetric rounding: pill-shaped on grip side, subtle on inner side
          const bigR = Radius.circular(8);
          const smallR = Radius.circular(4);
          final gripOnLeft = btn.center.dx < 50;
          rrect = RRect.fromRectAndCorners(
            rect,
            topLeft: gripOnLeft ? bigR : smallR,
            bottomLeft: gripOnLeft ? bigR : smallR,
            topRight: gripOnLeft ? smallR : bigR,
            bottomRight: gripOnLeft ? smallR : bigR,
          );
        } else {
          rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        }
        if (isPressed) canvas.drawRRect(rrect, pressedFill);
        canvas.drawRRect(rrect, btnBorderPaint);
        _drawLabel(canvas, label, style, btn.center);
      } else if (btn.radius > 0) {
        if (btn.isStick) {
          canvas.drawCircle(
            btn.center,
            btn.radius,
            Paint()
              ..color = Colors.white.withOpacity(0.08)
              ..style = PaintingStyle.fill,
          );
        }
        if (isPressed) {
          canvas.drawCircle(btn.center, btn.radius, pressedFill);
        }
        canvas.drawCircle(btn.center, btn.radius, btnBorderPaint);
        _drawLabel(canvas, label, style, btn.center);
      }
    }

    _drawBattery(canvas);
  }

  static const double _barX = 25;
  static const double _barY = 218;
  static const double _barW = 50;
  static const double _barH = 3;
  static const _barRadius = Radius.circular(1.5);
  static final _barTrackRRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(_barX, _barY, _barW, _barH), _barRadius,
  );
  static final _barTrackPaint = Paint()..color = Colors.white.withOpacity(0.1);

  void _drawBattery(Canvas canvas) {
    if (batteryLevel < 0) return;

    // Background track
    canvas.drawRRect(_barTrackRRect, _barTrackPaint);

    // Fill bar (green 31-100%, yellow 11-30%, red 0-10%)
    // Minimum 2px ensures 0% is visible as a red sliver
    final rawW = _barW * batteryLevel.toDouble() / 100.0;
    final fillW = rawW < 2.0 ? 2.0 : rawW;
    Color color;
    if (batteryLevel > 30) {
      color = Colors.greenAccent.withOpacity(0.7);
    } else if (batteryLevel > 10) {
      color = Colors.yellow.withOpacity(0.7);
    } else {
      color = Colors.red.withOpacity(0.7);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_barX, _barY, fillW, _barH), _barRadius,
      ),
      Paint()..color = color,
    );
  }

  void _drawLabel(Canvas canvas, String label, TextStyle style, Offset center) {
    // Reduce font for long labels (e.g. "Click/Bksp" or multi-line "Mouse\nRClk")
    final effectiveStyle = label.length > 6
        ? style.copyWith(fontSize: (style.fontSize ?? 12) - 2)
        : style;
    final tp = TextPainter(
      text: TextSpan(text: label, style: effectiveStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_JoyconPainter old) =>
      !setEquals(old.pressedButtons, pressedButtons) ||
      old.batteryLevel != batteryLevel ||
      !identical(old.config, config);
}
