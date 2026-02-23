import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../common.dart';
import '../../models/gamepad_config.dart';
import '../../models/platform_model.dart';

/// Full-page editor for gamepad button→action mappings.
class GamepadMappingsPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const GamepadMappingsPage({super.key, this.onChanged});

  @override
  State<GamepadMappingsPage> createState() => _GamepadMappingsPageState();
}

class _GamepadMappingsPageState extends State<GamepadMappingsPage> {
  late GamepadConfig _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final jsonStr = bind.mainGetLocalOption(key: 'gamepad-mappings');
    if (jsonStr.isNotEmpty) {
      _config = GamepadConfig.fromJsonString(jsonStr);
    } else {
      final side = bind.mainGetLocalOption(key: 'gamepad-side');
      _config = GamepadConfig.defaultFor(
          side == 'right' ? JoyConSide.right : JoyConSide.left);
    }
  }

  void _saveConfig() {
    bind.mainSetLocalOption(
        key: 'gamepad-mappings', value: _config.toJsonString());
    gFFI.gamepadModel.reloadConfig();
    widget.onChanged?.call();
  }

  void _showActionPicker(String logicalButton, Map<String, String> layer) {
    final currentValue = layer[logicalButton] ?? 'none';
    // Stick: analog actions only. Buttons: discrete actions only.
    final actions = logicalButton == LogicalButton.stick
        ? GamepadActions.all.where((e) =>
            e.value == 'none' || e.value == 'mouse_move' || e.value == 'scroll').toList()
        : GamepadActions.all.where((e) =>
            e.value != 'mouse_move' && e.value != 'scroll').toList();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(LogicalButton.label(logicalButton, _config.side)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final entry = actions[index];
                return RadioListTile<String>(
                  title: Text(entry.label),
                  value: entry.value,
                  groupValue: currentValue,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        layer[logicalButton] = v;
                        _saveConfig();
                      });
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTriggerActionPicker(bool isZl, {bool isLong = false}) {
    final currentValue = isLong
        ? (isZl ? _config.zlLongAction : _config.zrLongAction)
        : (isZl ? _config.zlAction : _config.zrAction);
    // Pre-filter: exclude stick-only actions for triggers
    final actions = GamepadActions.all
        .where((e) => e.value != 'mouse_move' && e.value != 'scroll')
        .toList();
    final titleKey = isLong
        ? (isZl ? 'ZL Long Press' : 'ZR Long Press')
        : (isZl ? 'ZL Action' : 'ZR Action');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(translate(titleKey)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final entry = actions[index];
                return RadioListTile<String>(
                  title: Text(entry.label),
                  value: entry.value,
                  groupValue: currentValue,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        if (isLong) {
                          if (isZl) {
                            _config.zlLongAction = v;
                          } else {
                            _config.zrLongAction = v;
                          }
                        } else {
                          if (isZl) {
                            _config.zlAction = v;
                          } else {
                            _config.zrAction = v;
                          }
                        }
                        _saveConfig();
                      });
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showBumperLongActionPicker(bool isLeft) {
    final currentValue = isLeft ? _config.lLongAction : _config.rLongAction;
    final actions = GamepadActions.all
        .where((e) => e.value != 'mouse_move' && e.value != 'scroll')
        .toList();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(translate(isLeft ? 'L Long Press' : 'R Long Press')),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final entry = actions[index];
                return RadioListTile<String>(
                  title: Text(entry.label),
                  value: entry.value,
                  groupValue: currentValue,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        if (isLeft) {
                          _config.lLongAction = v;
                        } else {
                          _config.rLongAction = v;
                        }
                        _saveConfig();
                      });
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showBumperActionPicker(bool isLeft) {
    final currentValue = isLeft ? _config.lAction : _config.rAction;
    final actions = GamepadActions.all
        .where((e) => e.value != 'mouse_move' && e.value != 'scroll')
        .toList();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(translate(isLeft ? 'L Quick Tap' : 'R Quick Tap')),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final entry = actions[index];
                return RadioListTile<String>(
                  title: Text(entry.label),
                  value: entry.value,
                  groupValue: currentValue,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        if (isLeft) {
                          _config.lAction = v;
                        } else {
                          _config.rAction = v;
                        }
                        _saveConfig();
                      });
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<SettingsTile> _buildLayerTiles(Map<String, String> layer) {
    final bumperIsModifier = (_config.side == JoyConSide.left)
        ? _config.lMode == TriggerMode.modifier
        : _config.rMode == TriggerMode.modifier;
    return LogicalButton.allButtons
        .where((btn) => !(bumperIsModifier && btn == LogicalButton.bumper))
        .map((btn) {
      final action = layer[btn] ?? 'none';
      return SettingsTile(
        title: Text(LogicalButton.label(btn, _config.side)),
        description: Text(GamepadActions.fullLabel(action)),
        onPressed: (_) => _showActionPicker(btn, layer),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = _config.side == JoyConSide.left;
    return Scaffold(
      appBar: AppBar(
        title: Text(translate('Button Mappings')),
      ),
      body: SettingsList(
        sections: [
          // Trigger & bumper configuration (filtered by side)
          SettingsSection(
            title: Text(translate('Triggers & Bumpers')),
            tiles: [
              // Trigger toggle for current side only
              if (isLeft) ...[
                SettingsTile.switchTile(
                  title: Text(translate('ZL as Layer Modifier')),
                  description: Text(_config.zlMode == TriggerMode.modifier
                      ? translate('Activates ZL layer when held')
                      : translate('Press sends action (no modifier layer)')),
                  leading: const Icon(Icons.keyboard_double_arrow_left),
                  initialValue: _config.zlMode == TriggerMode.modifier,
                  onToggle: (v) {
                    setState(() {
                      _config.zlMode =
                          v ? TriggerMode.modifier : TriggerMode.action;
                      if (v) {
                        _config.zlLongAction = 'none';
                      }
                      if (!v && _config.zlAction == 'none') {
                        _config.zlAction = 'VK_ESCAPE';
                      }
                      _saveConfig();
                    });
                  },
                ),
                if (_config.zlMode == TriggerMode.modifier) ...[
                  SettingsTile(
                    title: Text(translate('ZL Quick Tap')),
                    description: Text(_config.zlAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.zlAction)),
                    onPressed: (_) => _showTriggerActionPicker(true),
                  ),
                ],
                if (_config.zlMode == TriggerMode.action) ...[
                  SettingsTile(
                    title: Text(translate('ZL Action')),
                    description: Text(GamepadActions.fullLabel(_config.zlAction)),
                    onPressed: (_) => _showTriggerActionPicker(true),
                  ),
                  SettingsTile(
                    title: Text(translate('ZL Long Press')),
                    description: Text(_config.zlLongAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.zlLongAction)),
                    onPressed: (_) => _showTriggerActionPicker(true, isLong: true),
                  ),
                ],
              ],
              if (!isLeft) ...[
                SettingsTile.switchTile(
                  title: Text(translate('ZR as Layer Modifier')),
                  description: Text(_config.zrMode == TriggerMode.modifier
                      ? translate('Activates ZR layer when held')
                      : translate('Press sends action (no modifier layer)')),
                  leading: const Icon(Icons.keyboard_double_arrow_right),
                  initialValue: _config.zrMode == TriggerMode.modifier,
                  onToggle: (v) {
                    setState(() {
                      _config.zrMode =
                          v ? TriggerMode.modifier : TriggerMode.action;
                      if (v) {
                        _config.zrLongAction = 'none';
                      }
                      if (!v && _config.zrAction == 'none') {
                        _config.zrAction = 'VK_ESCAPE';
                      }
                      _saveConfig();
                    });
                  },
                ),
                if (_config.zrMode == TriggerMode.modifier) ...[
                  SettingsTile(
                    title: Text(translate('ZR Quick Tap')),
                    description: Text(_config.zrAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.zrAction)),
                    onPressed: (_) => _showTriggerActionPicker(false),
                  ),
                ],
                if (_config.zrMode == TriggerMode.action) ...[
                  SettingsTile(
                    title: Text(translate('ZR Action')),
                    description: Text(GamepadActions.fullLabel(_config.zrAction)),
                    onPressed: (_) => _showTriggerActionPicker(false),
                  ),
                  SettingsTile(
                    title: Text(translate('ZR Long Press')),
                    description: Text(_config.zrLongAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.zrLongAction)),
                    onPressed: (_) => _showTriggerActionPicker(false, isLong: true),
                  ),
                ],
              ],
              // Bumper modifier toggle for current side
              if (isLeft) ...[
                SettingsTile.switchTile(
                  title: Text(translate('L as Layer Modifier')),
                  description: Text(_config.lMode == TriggerMode.modifier
                      ? translate('Activates L layer when held')
                      : translate('Press sends action (no modifier layer)')),
                  leading: const Icon(Icons.arrow_back),
                  initialValue: _config.lMode == TriggerMode.modifier,
                  onToggle: (v) {
                    setState(() {
                      _config.lMode =
                          v ? TriggerMode.modifier : TriggerMode.action;
                      if (v) {
                        _config.lLongAction = 'none';
                      }
                      _saveConfig();
                    });
                  },
                ),
                if (_config.lMode == TriggerMode.modifier) ...[
                  SettingsTile(
                    title: Text(translate('L Quick Tap')),
                    description: Text(_config.lAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.lAction)),
                    onPressed: (_) => _showBumperActionPicker(true),
                  ),
                ],
                if (_config.lMode == TriggerMode.action) ...[
                  SettingsTile(
                    title: Text(translate('L Action')),
                    description: Text(GamepadActions.fullLabel(_config.lAction)),
                    onPressed: (_) => _showBumperActionPicker(true),
                  ),
                  SettingsTile(
                    title: Text(translate('L Long Press')),
                    description: Text(_config.lLongAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.lLongAction)),
                    onPressed: (_) => _showBumperLongActionPicker(true),
                  ),
                ],
              ],
              if (!isLeft) ...[
                SettingsTile.switchTile(
                  title: Text(translate('R as Layer Modifier')),
                  description: Text(_config.rMode == TriggerMode.modifier
                      ? translate('Activates R layer when held')
                      : translate('Press sends action (no modifier layer)')),
                  leading: const Icon(Icons.arrow_forward),
                  initialValue: _config.rMode == TriggerMode.modifier,
                  onToggle: (v) {
                    setState(() {
                      _config.rMode =
                          v ? TriggerMode.modifier : TriggerMode.action;
                      if (v) {
                        _config.rLongAction = 'none';
                      }
                      _saveConfig();
                    });
                  },
                ),
                if (_config.rMode == TriggerMode.modifier) ...[
                  SettingsTile(
                    title: Text(translate('R Quick Tap')),
                    description: Text(_config.rAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.rAction)),
                    onPressed: (_) => _showBumperActionPicker(false),
                  ),
                ],
                if (_config.rMode == TriggerMode.action) ...[
                  SettingsTile(
                    title: Text(translate('R Action')),
                    description: Text(GamepadActions.fullLabel(_config.rAction)),
                    onPressed: (_) => _showBumperActionPicker(false),
                  ),
                  SettingsTile(
                    title: Text(translate('R Long Press')),
                    description: Text(_config.rLongAction == 'none'
                        ? translate('Disabled')
                        : GamepadActions.fullLabel(_config.rLongAction)),
                    onPressed: (_) => _showBumperLongActionPicker(false),
                  ),
                ],
              ],
            ],
          ),
          // Normal layer (always shown)
          SettingsSection(
            title: Text(translate('Normal')),
            tiles: _buildLayerTiles(_config.normalLayer),
          ),
          // Trigger layer (side-filtered)
          if (isLeft && _config.zlMode == TriggerMode.modifier)
            SettingsSection(
              title: Text(translate('ZL Modifier Layer')),
              tiles: _buildLayerTiles(_config.zlLayer),
            ),
          if (!isLeft && _config.zrMode == TriggerMode.modifier)
            SettingsSection(
              title: Text(translate('ZR Modifier Layer')),
              tiles: _buildLayerTiles(_config.zrLayer),
            ),
          // Bumper layer (side-filtered)
          if (isLeft && _config.lMode == TriggerMode.modifier)
            SettingsSection(
              title: Text(translate('L Modifier Layer')),
              tiles: _buildLayerTiles(_config.lLayer),
            ),
          if (!isLeft && _config.rMode == TriggerMode.modifier)
            SettingsSection(
              title: Text(translate('R Modifier Layer')),
              tiles: _buildLayerTiles(_config.rLayer),
            ),
          // Presets
          SettingsSection(
            title: Text(translate('Presets')),
            tiles: [
              SettingsTile(
                title: Text(translate('Reset to Default')),
                leading: const Icon(Icons.restore),
                onPressed: (_) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(translate('Reset to Default')),
                      content: Text(translate(
                          'Reset all button mappings to default? This cannot be undone.')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(translate('Cancel')),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _config =
                                  GamepadConfig.defaultFor(_config.side);
                              _saveConfig();
                            });
                          },
                          child: Text(translate('Reset')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
