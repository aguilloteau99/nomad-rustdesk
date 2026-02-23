import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/chat_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const double _kVoiceButtonSize = 48.0;
const double _kVoiceHitAreaSize = 56.0;
const double _kSpaceToEdge = 15.0;
final Color _kDefaultColor = Colors.black.withOpacity(0.4);

class FloatingVoiceCallButton extends StatefulWidget {
  final FFI ffi;
  const FloatingVoiceCallButton({super.key, required this.ffi});

  @override
  State<FloatingVoiceCallButton> createState() =>
      _FloatingVoiceCallButtonState();
}

class _FloatingVoiceCallButtonState extends State<FloatingVoiceCallButton>
    with TickerProviderStateMixin {
  Offset _position = Offset.zero;
  bool _isInitialized = false;
  Rect? _lastBlockedRect;
  Orientation? _previousOrientation;
  Offset _preSavedPos = Offset.zero;
  bool _isDragging = false;
  Offset _pointerStart = Offset.zero;
  static const double _kDragThreshold = 8.0;

  // Tap-to-arm state for hangup
  bool _armed = false;

  // Pulse glow for connected state
  late AnimationController _pulseController;
  // Countdown arc for armed state (replaces Timer)
  late AnimationController _armCountdown;

  late final Worker _statusWorker;

  CursorModel get _cursorModel => widget.ffi.cursorModel;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _armCountdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _armed = false);
        }
      });
    _statusWorker = ever(widget.ffi.chatModel.voiceCallStatus, (status) {
      if (status != VoiceCallStatus.connected && _armed && mounted) {
        setState(() => _armed = false);
        _armCountdown.stop();
        _armCountdown.reset();
      }
      // Manage pulse animation reactively (outside build)
      if (status == VoiceCallStatus.connected && !_armed) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ori = MediaQuery.of(context).orientation;
      _previousOrientation = ori;
      _resetPosition(ori);
    });
  }

  @override
  void dispose() {
    _statusWorker.dispose();
    _pulseController.dispose();
    _armCountdown.dispose();
    if (_lastBlockedRect != null) {
      _cursorModel.removeBlockedRect(_lastBlockedRect!);
    }
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

  // --- Position persistence ---

  String _getPositionKey(Orientation ori) {
    return 'voice-${ori == Orientation.portrait ? 'p' : 'l'}-pos';
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
        debugPrint('Bad saved voice button position: $e');
      }
    }
    _position = const Offset(_kSpaceToEdge, 80);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateBlockedRect();
    });
  }

  // --- Blocked rect ---

  void _updateBlockedRect() {
    if (_lastBlockedRect != null) {
      _cursorModel.removeBlockedRect(_lastBlockedRect!);
    }
    final newRect = Rect.fromLTWH(
        _position.dx, _position.dy, _kVoiceHitAreaSize, _kVoiceHitAreaSize);
    _cursorModel.addBlockedRect(newRect);
    _lastBlockedRect = newRect;
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
          size.width - _kVoiceHitAreaSize - _kSpaceToEdge),
      newPos.dy.clamp(_kSpaceToEdge,
          size.height - _kVoiceHitAreaSize - _kSpaceToEdge),
    );
    final changed = !(isDoubleEqual(newPos.dx, _position.dx) &&
        isDoubleEqual(newPos.dy, _position.dy));
    setState(() => _position = newPos);
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateBlockedRect();
      });
    }
  }

  // --- Tap logic ---

  void _onTap() async {
    final status = widget.ffi.chatModel.voiceCallStatus.value;
    switch (status) {
      case VoiceCallStatus.notStarted:
        if (isAndroid) {
          if (!await AndroidPermissionManager.check(kRecordAudio)) {
            final granted =
                await AndroidPermissionManager.request(kRecordAudio);
            if (!granted) {
              showToast(translate('voice_call_mic_denied'));
              return;
            }
          }
        }
        bind.sessionRequestVoiceCall(sessionId: widget.ffi.sessionId);
        break;
      case VoiceCallStatus.waitingForResponse:
        bind.sessionCloseVoiceCall(sessionId: widget.ffi.sessionId);
        break;
      case VoiceCallStatus.connected:
        if (_armed) {
          bind.sessionCloseVoiceCall(sessionId: widget.ffi.sessionId);
          setState(() => _armed = false);
          _armCountdown.stop();
          _armCountdown.reset();
        } else {
          setState(() => _armed = true);
          _armCountdown.forward(from: 0.0);
        }
        break;
      default:
        break;
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Positioned(child: Offstage());
    }
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Listener(
        onPointerDown: (event) {
          _isDragging = false;
          _pointerStart = event.position;
        },
        onPointerMove: _onPointerMove,
        onPointerUp: (_) {
          if (!_isDragging) {
            _onTap();
          } else {
            _trySavePosition();
          }
        },
        child: SizedBox(
          width: _kVoiceHitAreaSize,
          height: _kVoiceHitAreaSize,
          child: Center(
            child: Obx(() => _buildButton()),
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    final status = widget.ffi.chatModel.voiceCallStatus.value;

    final IconData icon;
    final Color color;

    if (status == VoiceCallStatus.connected && _armed) {
      icon = Icons.call_end;
      color = Colors.red.withOpacity(0.9);
    } else {
      switch (status) {
        case VoiceCallStatus.waitingForResponse:
        case VoiceCallStatus.connected:
          icon = Icons.mic;
          color = Color(0xFF6366F1).withOpacity(0.9);
          break;
        default:
          icon = Icons.mic_none;
          color = Colors.grey.withOpacity(0.7);
          break;
      }
    }

    // Base button circle
    Widget child = Container(
      width: _kVoiceButtonSize,
      height: _kVoiceButtonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kDefaultColor,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 24),
    );


    // Connected state: subtle pulse glow
    if (status == VoiceCallStatus.connected && !_armed) {
      child = AnimatedBuilder(
        animation: _pulseController,
        builder: (context, ch) {
          final glow = _pulseController.value * 6;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      Color(0xFF6366F1).withOpacity(0.3 * _pulseController.value),
                  blurRadius: glow,
                  spreadRadius: glow * 0.5,
                ),
              ],
            ),
            child: ch,
          );
        },
        child: child,
      );
    }

    // Armed state: depleting red countdown arc
    if (status == VoiceCallStatus.connected && _armed) {
      child = AnimatedBuilder(
        animation: _armCountdown,
        builder: (context, ch) {
          return CustomPaint(
            painter: _CountdownArcPainter(
              progress: _armCountdown.value,
              color: Colors.red.withOpacity(0.8),
            ),
            child: ch,
          );
        },
        child: child,
      );
    }

    return child;
  }
}

/// Draws a depleting circular arc (360° → 0°) as progress goes 0 → 1.
class _CountdownArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CountdownArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final remaining = 1.0 - progress;
    if (remaining <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 3;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * remaining,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CountdownArcPainter old) => old.progress != progress;
}
