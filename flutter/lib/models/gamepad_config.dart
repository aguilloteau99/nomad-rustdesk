import 'dart:convert';

import 'package:flutter/foundation.dart';

enum JoyConSide { left, right }

enum TriggerMode { modifier, action }

/// Represents a single gamepad action like "VK_UP", "ctrl+VK_Z", "mouse_left", "none".
class GamepadAction {
  final String raw;

  const GamepadAction(this.raw);

  bool get isNone => raw == 'none' || raw.isEmpty;
  bool get isMouse => raw.startsWith('mouse_');
  bool get isScroll => raw == 'scroll';
  bool get isMouseMove => raw == 'mouse_move';

  /// Extract modifiers and VK name from combo strings like "ctrl+shift+VK_Z".
  /// Returns null for mouse/scroll/none actions.
  ({bool ctrl, bool shift, bool alt, String vk})? get keyCombo {
    if (isMouse || isScroll || isMouseMove || isNone) return null;
    final parts = raw.split('+');
    final vk = parts.last;
    final mods = parts.sublist(0, parts.length - 1).map((m) => m.toLowerCase()).toSet();
    return (ctrl: mods.contains('ctrl'), shift: mods.contains('shift'), alt: mods.contains('alt'), vk: vk);
  }

  String get mouseButton {
    switch (raw) {
      case 'mouse_left': return 'left';
      case 'mouse_right': return 'right';
      case 'mouse_middle': return 'middle';
      case 'mouse_double': return 'double';
      default: return '';
    }
  }

  @override
  String toString() => raw;

  @override
  bool operator ==(Object other) => other is GamepadAction && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}

/// Predefined action choices for the UI dropdown.
class GamepadActions {
  static const List<({String label, String value})> all = [
    // Special
    (label: 'None (disabled)', value: 'none'),
    // Mouse
    (label: 'Left Click', value: 'mouse_left'),
    (label: 'Right Click', value: 'mouse_right'),
    (label: 'Middle Click', value: 'mouse_middle'),
    (label: 'Double Click', value: 'mouse_double'),
    // Stick-only
    (label: 'Mouse Move', value: 'mouse_move'),
    (label: 'Scroll', value: 'scroll'),
    // Navigation
    (label: 'Arrow Up', value: 'VK_UP'),
    (label: 'Arrow Down', value: 'VK_DOWN'),
    (label: 'Arrow Left', value: 'VK_LEFT'),
    (label: 'Arrow Right', value: 'VK_RIGHT'),
    (label: 'Tab', value: 'VK_TAB'),
    (label: 'Enter', value: 'VK_RETURN'),
    (label: 'Escape', value: 'VK_ESCAPE'),
    (label: 'Backspace', value: 'VK_BACK'),
    (label: 'Space', value: 'VK_SPACE'),
    (label: 'Delete', value: 'VK_DELETE'),
    // Page navigation
    (label: 'Home', value: 'VK_HOME'),
    (label: 'End', value: 'VK_END'),
    (label: 'Page Up', value: 'VK_PRIOR'),
    (label: 'Page Down', value: 'VK_NEXT'),
    // Edit combos
    (label: 'Ctrl+Z (Undo)', value: 'ctrl+VK_Z'),
    (label: 'Ctrl+Shift+Z (Redo)', value: 'ctrl+shift+VK_Z'),
    (label: 'Ctrl+C (Copy)', value: 'ctrl+VK_C'),
    (label: 'Ctrl+V (Paste)', value: 'ctrl+VK_V'),
    (label: 'Ctrl+X (Cut)', value: 'ctrl+VK_X'),
    (label: 'Ctrl+A (Select All)', value: 'ctrl+VK_A'),
    (label: 'Ctrl+S (Save)', value: 'ctrl+VK_S'),
    // Window/tab combos
    (label: 'Shift+Tab', value: 'shift+VK_TAB'),
    (label: 'Alt+Tab', value: 'alt+VK_TAB'),
    (label: 'Alt+F4', value: 'alt+VK_F4'),
    (label: 'Ctrl+W (Close Tab)', value: 'ctrl+VK_W'),
    (label: 'Ctrl+T (New Tab)', value: 'ctrl+VK_T'),
  ];

  /// Short display label for the overlay (max ~5 chars).
  static String shortLabel(String actionValue) {
    switch (actionValue) {
      case 'none': return '';
      case 'mouse_left': return 'Click';
      case 'mouse_right': return 'RClk';
      case 'mouse_middle': return 'MClk';
      case 'mouse_double': return 'DblC';
      case 'mouse_move': return 'Mouse';
      case 'scroll': return 'Scroll';
      case 'VK_UP': return '\u25B4';
      case 'VK_DOWN': return '\u25BE';
      case 'VK_LEFT': return '\u25C2';
      case 'VK_RIGHT': return '\u25B8';
      case 'VK_TAB': return 'Tab';
      case 'VK_RETURN': return 'Enter';
      case 'VK_ESCAPE': return 'Esc';
      case 'VK_BACK': return 'Bksp';
      case 'VK_SPACE': return 'Spc';
      case 'VK_DELETE': return 'Del';
      case 'VK_HOME': return 'Home';
      case 'VK_END': return 'End';
      case 'VK_PRIOR': return 'PgUp';
      case 'VK_NEXT': return 'PgDn';
      default: break;
    }
    // Handle combos: "ctrl+shift+VK_Z" → "CS-Z"
    if (actionValue.contains('+')) {
      final parts = actionValue.split('+');
      final vk = parts.last.replaceFirst('VK_', '');
      final mods = parts.sublist(0, parts.length - 1);
      final modStr = mods.map((m) {
        switch (m.toLowerCase()) {
          case 'ctrl': return 'C';
          case 'shift': return 'S';
          case 'alt': return 'A';
          default: return m[0].toUpperCase();
        }
      }).join('');
      return '$modStr-$vk';
    }
    // Bare VK_ key
    if (actionValue.startsWith('VK_')) {
      return actionValue.replaceFirst('VK_', '');
    }
    return actionValue;
  }

  /// Full label for settings UI.
  static String fullLabel(String actionValue) {
    for (final entry in all) {
      if (entry.value == actionValue) return entry.label;
    }
    return actionValue;
  }
}

/// Logical button names (independent of Joy-Con side).
class LogicalButton {
  static const String stick = 'stick';
  static const String dpadUp = 'dpad_up';
  static const String dpadDown = 'dpad_down';
  static const String dpadLeft = 'dpad_left';
  static const String dpadRight = 'dpad_right';
  static const String bumper = 'bumper';
  static const String thumbstick = 'thumbstick';
  static const String menuMinus = 'menu_minus';
  static const String menuHome = 'menu_home';

  /// All buttons in display order.
  static const List<String> allButtons = [
    stick, dpadUp, dpadDown, dpadLeft, dpadRight,
    bumper, thumbstick, menuMinus, menuHome,
  ];

  /// Human-readable label for each button (side-agnostic).
  static String label(String button, JoyConSide side) {
    switch (button) {
      case stick: return 'Stick';
      case dpadUp: return 'D-Pad Up / X';
      case dpadDown: return 'D-Pad Down / B';
      case dpadLeft: return 'D-Pad Left / Y';
      case dpadRight: return 'D-Pad Right / A';
      case bumper: return side == JoyConSide.left ? 'L (Bumper)' : 'R (Bumper)';
      case thumbstick: return 'Stick Click';
      case menuMinus: return side == JoyConSide.left ? 'Minus (-)' : 'Plus (+)';
      case menuHome: return 'Home';
      default: return button;
    }
  }
}

/// Full gamepad configuration: side, trigger modes, bumper modes, 5 mapping layers.
class GamepadConfig {
  JoyConSide side;
  TriggerMode zlMode;
  TriggerMode zrMode;
  String zlAction; // action when zlMode == TriggerMode.action
  String zrAction; // action when zrMode == TriggerMode.action
  String zlLongAction; // long press action (empty or 'none' = disabled)
  String zrLongAction;
  TriggerMode lMode; // bumper L mode (default: action = regular button)
  TriggerMode rMode; // bumper R mode (default: action = regular button)
  String lAction; // bumper L tap action in modifier mode (default: 'none')
  String rAction; // bumper R tap action in modifier mode (default: 'none')
  String lLongAction; // bumper long press action
  String rLongAction;
  Map<String, String> normalLayer;
  Map<String, String> zlLayer;
  Map<String, String> zrLayer;
  Map<String, String> lLayer; // bumper L modifier layer
  Map<String, String> rLayer; // bumper R modifier layer

  GamepadConfig({
    required this.side,
    this.zlMode = TriggerMode.modifier,
    this.zrMode = TriggerMode.modifier,
    this.zlAction = 'none',
    this.zrAction = 'none',
    this.zlLongAction = 'none',
    this.zrLongAction = 'none',
    this.lMode = TriggerMode.action,
    this.rMode = TriggerMode.action,
    this.lAction = 'none',
    this.rAction = 'none',
    this.lLongAction = 'none',
    this.rLongAction = 'none',
    required this.normalLayer,
    required this.zlLayer,
    required this.zrLayer,
    required this.lLayer,
    required this.rLayer,
  });

  /// Get the action for a button given the current modifier state.
  /// Priority order: ZR layer > ZL layer > R layer > L layer > Normal layer.
  /// When multiple modifiers are held, the highest-priority layer with a
  /// non-empty action for that button wins.
  String getAction(String logicalButton, {
    bool zlHeld = false, bool zrHeld = false,
    bool lHeld = false, bool rHeld = false,
  }) {
    // Trigger layers (highest priority)
    if (zrHeld && zrMode == TriggerMode.modifier) {
      final action = zrLayer[logicalButton];
      if (action != null && action != 'none' && action.isNotEmpty) return action;
    }
    if (zlHeld && zlMode == TriggerMode.modifier) {
      final action = zlLayer[logicalButton];
      if (action != null && action != 'none' && action.isNotEmpty) return action;
    }
    // Bumper layers (second priority)
    if (rHeld && rMode == TriggerMode.modifier) {
      final action = rLayer[logicalButton];
      if (action != null && action != 'none' && action.isNotEmpty) return action;
    }
    if (lHeld && lMode == TriggerMode.modifier) {
      final action = lLayer[logicalButton];
      if (action != null && action != 'none' && action.isNotEmpty) return action;
    }
    return normalLayer[logicalButton] ?? 'none';
  }

  Map<String, dynamic> toJson() => {
    'side': side == JoyConSide.left ? 'left' : 'right',
    'zlMode': zlMode == TriggerMode.modifier ? 'modifier' : 'action',
    'zrMode': zrMode == TriggerMode.modifier ? 'modifier' : 'action',
    'zlAction': zlAction,
    'zrAction': zrAction,
    'zlLongAction': zlLongAction,
    'zrLongAction': zrLongAction,
    'lMode': lMode == TriggerMode.modifier ? 'modifier' : 'action',
    'rMode': rMode == TriggerMode.modifier ? 'modifier' : 'action',
    'lAction': lAction,
    'rAction': rAction,
    'lLongAction': lLongAction,
    'rLongAction': rLongAction,
    'normalLayer': normalLayer,
    'zlLayer': zlLayer,
    'zrLayer': zrLayer,
    'lLayer': lLayer,
    'rLayer': rLayer,
  };

  factory GamepadConfig.fromJson(Map<String, dynamic> json) {
    return GamepadConfig(
      side: json['side'] == 'right' ? JoyConSide.right : JoyConSide.left,
      zlMode: json['zlMode'] == 'action' ? TriggerMode.action : TriggerMode.modifier,
      zrMode: json['zrMode'] == 'action' ? TriggerMode.action : TriggerMode.modifier,
      zlAction: json['zlAction'] as String? ?? 'none',
      zrAction: json['zrAction'] as String? ?? 'none',
      zlLongAction: json['zlLongAction'] as String? ?? 'none',
      zrLongAction: json['zrLongAction'] as String? ?? 'none',
      lMode: json['lMode'] == 'modifier' ? TriggerMode.modifier : TriggerMode.action,
      rMode: json['rMode'] == 'modifier' ? TriggerMode.modifier : TriggerMode.action,
      lAction: json['lAction'] as String? ?? 'none',
      rAction: json['rAction'] as String? ?? 'none',
      lLongAction: json['lLongAction'] as String? ?? 'none',
      rLongAction: json['rLongAction'] as String? ?? 'none',
      normalLayer: Map<String, String>.from(json['normalLayer'] as Map? ?? {}),
      zlLayer: Map<String, String>.from(json['zlLayer'] as Map? ?? {}),
      zrLayer: Map<String, String>.from(json['zrLayer'] as Map? ?? {}),
      lLayer: Map<String, String>.from(json['lLayer'] as Map? ?? {}),
      rLayer: Map<String, String>.from(json['rLayer'] as Map? ?? {}),
    );
  }

  factory GamepadConfig.fromJsonString(String jsonStr) {
    try {
      return GamepadConfig.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to parse gamepad config: $e');
      return GamepadConfig.defaultLeft();
    }
  }

  /// Default Joy-Con L config matching the original hardcoded behavior.
  factory GamepadConfig.defaultLeft() => GamepadConfig(
    side: JoyConSide.left,
    zlMode: TriggerMode.modifier,
    zrMode: TriggerMode.modifier,
    normalLayer: {
      LogicalButton.stick: 'mouse_move',
      LogicalButton.dpadUp: 'VK_UP',
      LogicalButton.dpadDown: 'VK_DOWN',
      LogicalButton.dpadLeft: 'VK_LEFT',
      LogicalButton.dpadRight: 'VK_RIGHT',
      LogicalButton.bumper: 'mouse_left',
      LogicalButton.thumbstick: 'mouse_right',
      LogicalButton.menuMinus: 'VK_BACK',
      LogicalButton.menuHome: 'VK_RETURN',
    },
    zlLayer: {
      LogicalButton.stick: 'scroll',
      LogicalButton.dpadUp: 'shift+VK_TAB',
      LogicalButton.dpadDown: 'VK_ESCAPE',
      LogicalButton.dpadLeft: 'ctrl+VK_C',
      LogicalButton.dpadRight: 'ctrl+VK_Z',
      LogicalButton.bumper: 'ctrl+VK_A',
      LogicalButton.thumbstick: 'none',
      LogicalButton.menuMinus: 'ctrl+VK_S',
      LogicalButton.menuHome: 'VK_SPACE',
    },
    zrLayer: const {},
    lLayer: const {},
    rLayer: const {},
  );

  /// Default Joy-Con R config (mirrored).
  factory GamepadConfig.defaultRight() => GamepadConfig(
    side: JoyConSide.right,
    zlMode: TriggerMode.modifier,
    zrMode: TriggerMode.modifier,
    normalLayer: {
      LogicalButton.stick: 'mouse_move',
      LogicalButton.dpadUp: 'VK_UP',
      LogicalButton.dpadDown: 'VK_DOWN',
      LogicalButton.dpadLeft: 'VK_LEFT',
      LogicalButton.dpadRight: 'VK_RIGHT',
      LogicalButton.bumper: 'mouse_left',
      LogicalButton.thumbstick: 'mouse_right',
      LogicalButton.menuMinus: 'VK_BACK',
      LogicalButton.menuHome: 'VK_RETURN',
    },
    zlLayer: const {},
    zrLayer: {
      LogicalButton.stick: 'scroll',
      LogicalButton.dpadUp: 'shift+VK_TAB',
      LogicalButton.dpadDown: 'VK_ESCAPE',
      LogicalButton.dpadLeft: 'ctrl+VK_C',
      LogicalButton.dpadRight: 'ctrl+VK_Z',
      LogicalButton.bumper: 'ctrl+VK_A',
      LogicalButton.thumbstick: 'none',
      LogicalButton.menuMinus: 'ctrl+VK_S',
      LogicalButton.menuHome: 'VK_SPACE',
    },
    lLayer: const {},
    rLayer: const {},
  );

  /// Get the appropriate default config for a side.
  static GamepadConfig defaultFor(JoyConSide side) =>
      side == JoyConSide.left ? GamepadConfig.defaultLeft() : GamepadConfig.defaultRight();

  String toJsonString() => json.encode(toJson());
}
