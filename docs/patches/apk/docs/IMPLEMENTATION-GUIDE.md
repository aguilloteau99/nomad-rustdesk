# Gamepad Implementation Guide — File-by-File Code Walkthrough

Detailed technical guide to Joy-Con gamepad implementation for RustDesk Android.

> **Parent guide**: See `patches/apk/CLAUDE.md` for quick start and overview.
>
> **Status**: Implémenté, testé sur Samsung S10+, 11 corrections PR-quality appliquées.
> Ce document reflète le code final tel qu'il existe dans le patch `patches/apk/rustdesk-gamepad.patch` (~4149 lines, 15 fichiers).


## Prérequis

- RustDesk source cloné (`git clone https://github.com/rustdesk/rustdesk.git ~/rustdesk`)
- Flutter SDK installé
- Android SDK avec NDK
- JDK 17 (`/usr/lib/jvm/java-17-openjdk-amd64`)
- Joy-Con gauche pour tester

## Architecture

```
Joy-Con (BT) → Android Activity
                 ├─ dispatchKeyEvent()        → GamepadHandler.kt → EventChannel
                 └─ dispatchGenericMotionEvent()  → (button/axis events, +AXIS_RTRIGGER)
                                                        │
                                                        ▼
                                                  GamepadModel.dart
                                                  ├─ _onEvent() — route axis/button
                                                  ├─ _tickMouseMove() — 60fps Timer
                                                  │   ├─ config.getAction(stick, zl, zr) == 'scroll'
                                                  │   │     → _tickScroll()
                                                  │   └─ else → _sendRelativeMouseMove()
                                                  └─ _onButton() — config-driven dispatch
                                                      ├─ _toLogicalButton(keyCode) ← side-dependent
                                                      ├─ _config.getAction(logical, zlHeld, zrHeld)
                                                      └─ _executeAction(actionStr) ← parses combos
```

## Fichier 1: GamepadHandler.kt (Android Native)

**Chemin**: `flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/GamepadHandler.kt`

Rôle: Intercepte les événements Android gamepad, applique la deadzone, et les transmet à Dart via EventChannel.

Points clés du code final:
- `@Volatile` sur `eventSink` (thread-safety entre UI thread et Flutter engine thread)
- `isGamepad()` vérifie `SOURCE_GAMEPAD` ET `SOURCE_JOYSTICK` (bitwise AND)
- `applyDeadzone()` remappe `[deadzone, 1.0]` → `[0.0, 1.0]` pour éviter le saut discontinu
- `AXIS_LTRIGGER` et `AXIS_RTRIGGER` inclus dans les events axis (pour les devices qui reportent ZL/ZR en analogique)
- ISE catch → `eventSink = null` (prévient la boucle d'erreurs quand le sink Flutter est fermé)
- `deviceId` retiré des maps (inutilisé côté Dart)

### Protocol EventChannel

```
// Button event
{"type": "button", "keyCode": 102, "action": "down"}

// Axis event (60Hz)
{"type": "axis", "x": 0.45, "y": -0.82, "ltrigger": 0.0, "rtrigger": 0.0}
```

## Fichier 2: MainActivity.kt (Modifications)

**Chemin**: `flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainActivity.kt`

Ajouts:
1. **Membre**: `private var gamepadHandler: GamepadHandler? = null`
2. **configureFlutterEngine**: Création du `GamepadHandler` + setup `EventChannel` avec `StreamHandler`
3. **dispatchKeyEvent override**: Route vers `gamepadHandler?.handleKeyEvent(event)`, fallback `super`
4. **dispatchGenericMotionEvent override**: Route vers `gamepadHandler?.handleMotionEvent(event)`, fallback `super`
5. **onDestroy**: `gamepadHandler?.setEventSink(null)` avant `super.onDestroy()`

## Fichier 3: GamepadModel.dart (Flutter)

**Chemin**: `flutter/lib/models/gamepad_model.dart`

### Structure

```dart
class GamepadModel {
  final WeakReference<FFI> parent;  // WeakRef pour ne pas empêcher le GC

  // EventChannel stream + Timer 60fps
  StreamSubscription? _subscription;
  Timer? _moveTimer;

  // État du stick (mis à jour par _onEvent, lu par _tickMouseMove)
  double _axisX, _axisY;

  // Accumulateurs fractionnaires (préserve les sous-pixels entre ticks)
  double _deltaRemainderX, _deltaRemainderY;

  // Scroll (ZL + stick)
  double _scrollRemainderY;
  int _scrollTickCounter;

  // ZL modifier (dual-source: KeyEvent priorisé sur AXIS_LTRIGGER)
  bool _zlHeld, _zlFromKey;

  // ZR modifier (dual-source: KeyEvent priorisé sur AXIS_RTRIGGER)
  bool _zrHeld, _zrFromKey;

  // Config-driven mappings (loaded from local option 'gamepad-mappings')
  GamepadConfig _config;

  // Public getter for overlay
  GamepadConfig get config => _config;

  // Hot-reload from settings page
  void reloadConfig() { _loadConfig(); }
}
```

### Cycle de vie

1. `start()` — appelé par `remote_page.dart:initState()` si `gamepad-enabled == 'Y'`
   - Cache les settings (`_mouseSpeed`, `_rotateAxes`)
   - Démarre le stream EventChannel
   - Démarre le Timer 60fps
2. `stop()` — appelé par `dispose()`, `mobileReset()`, `FFI.close()`, `onError`, `onDone`
   - Cancel subscription + timer
   - Reset tout l'état à zéro
3. Timer `_tickMouseMove()` — toutes les 16ms
   - `parent.target == null` → `stop()` (prévient leak si FFI est GC'd)
   - `ffi.ffiModel.keyboard` check (safe, pas de force-unwrap)
   - `ConnType.viewCamera` guard (skip en mode caméra)
   - ZL held → `_tickScroll()` (throttle ~15fps)
   - Sinon → calcul accélération + `_sendRelativeMouseMove()`

### Accélération souris

```
speed = (baseSpeed + (maxSpeed - baseSpeed) × magnitude^accelPower) × mouseSpeed

baseSpeed = 1.0, maxSpeed = 25.0, accelPower = 2.5, mouseSpeed = 1.5 (configurable)
```

Power 2.5 (inspiré Steam Input) crée une large zone de précision pour les petits mouvements.

### Scroll (ZL + stick)

- Throttle à ~15fps (`_scrollTickCounter % 4 != 0`)
- Valeur brute envoyée (`'y': '$y'`) — le serveur Windows multiplie par `WHEEL_DELTA=120`
- Reset `_scrollRemainderY` et `_scrollTickCounter` quand ZL passe false→true

### Envoi souris — pas de `modify()`

Les events gamepad utilisent `json.encode({...})` directement, sans `inputModel.modify()`. Raison: `modify()` injecte l'état des modificateurs clavier (Ctrl/Shift/Alt/Command) dans le message. Si l'utilisateur a Shift au clavier en même temps que le stick, ça provoquerait Shift+mouse move.

### Overlay curseur local

`ffi.cursorModel.moveByDelta(dx, dy)` — méthode ajoutée à `CursorModel` dans `model.dart`. Nécessaire car `move_relative` ne génère pas de retour de position du serveur (contrairement aux mouvements absolus).

### ZL/ZR dual-source avec priorité KeyEvent

Le Joy-Con ZL est un bouton digital (KeyEvent 104), mais Android envoie aussi `AXIS_LTRIGGER=0.0` dans chaque MotionEvent. Sans protection, l'axis event (60Hz) écraserait l'état du bouton. Même mécanisme pour ZR (KeyEvent 105 / `AXIS_RTRIGGER`).

Solution: `_zlFromKey` / `_zrFromKey` flags
- KeyEvent `BUTTON_L2 down` → `_zlHeld=true`, `_zlFromKey=true`
- KeyEvent `BUTTON_L2 up` → `_zlHeld=false`, `_zlFromKey=false`
- MotionEvent `AXIS_LTRIGGER` → ignoré si `_zlFromKey==true`
- Identique pour ZR avec `_zrFromKey`

### Button mapping (config-driven)

Le dispatch utilise maintenant `GamepadConfig` avec 3 layers. La méthode `_toLogicalButton()` convertit les keycodes physiques en noms logiques indépendants du côté:

```
_toLogicalButton(keyCode):
  DPAD_UP (19) / BUTTON_X (99)    → 'dpad_up'
  DPAD_DOWN (20) / BUTTON_B (97)  → 'dpad_down'
  DPAD_LEFT (21) / BUTTON_Y (100) → 'dpad_left'
  DPAD_RIGHT (22) / BUTTON_A (96) → 'dpad_right'
  L1 (102) [Joy-Con L]            → 'bumper'
  R1 (103) [Joy-Con R]            → 'bumper'
  THUMBL (106) [Joy-Con L]        → 'thumbstick'
  THUMBR (107) [Joy-Con R]        → 'thumbstick'
  SELECT (109)                    → 'menu_minus'
  START (108) / MODE (110)        → 'menu_home'

_config.getAction(logical, zlHeld, zrHeld):
  1. Si zrHeld et zrMode==modifier → cherche dans zrLayer
  2. Si zlHeld et zlMode==modifier → cherche dans zlLayer
  3. Sinon → normalLayer
  4. Fallback: 'none'

_executeAction(actionStr):
  'mouse_left/right/middle/double' → inputModel.tap(...)
  'VK_*'                           → inputModel.inputKey(...)
  'ctrl+shift+VK_Z'               → save/restore modifiers + inputKey
  'none' / ''                      → noop
```

### Trigger handling (_handleTrigger)

Les triggers ZL/ZR peuvent être en mode **modifier** (active un layer) ou **action** (envoie une action sur press):

```dart
if (config.zlMode == TriggerMode.action && isDown) {
  _executeAction(inputModel, config.zlAction);
}
// Sinon: toggle _zlHeld pour les layers
```

### Modifier save/restore dans `_executeAction`

```dart
final savedCtrl = inputModel.ctrl;
final savedShift = inputModel.shift;
try {
  inputModel.ctrl = true;  // set modifier
  inputModel.inputKey('VK_Z');  // send key
} finally {
  inputModel.ctrl = savedCtrl;  // restore
  inputModel.shift = savedShift;
}
```

Safe en Dart single-threaded: le Timer ne peut pas interrompre un callback synchrone.

## Fichier 4: model.dart (Modifications)

**Chemin**: `flutter/lib/models/model.dart`

1. `import 'package:flutter_hbb/models/gamepad_model.dart';`
2. `late final GamepadModel gamepadModel;` dans classe `FFI`
3. Init: `gamepadModel = GamepadModel(WeakReference(this));`
4. `gamepadModel.stop()` dans `mobileReset()` et `close()`
5. Ajout méthode `moveByDelta(double dx, double dy)` dans `CursorModel`:
   ```dart
   void moveByDelta(double dx, double dy) {
     _x += dx;
     _y += dy;
     notifyListeners();
   }
   ```

## Fichier 5: remote_page.dart (Modifications)

**Chemin**: `flutter/lib/mobile/pages/remote_page.dart`

- `initState()`: `if (bind.mainGetLocalOption(key: 'gamepad-enabled') == 'Y') gFFI.gamepadModel.start();`
- `dispose()`: `gFFI.gamepadModel.stop();`

## Fichier 6: settings_page.dart (Modifications)

**Chemin**: `flutter/lib/mobile/pages/settings_page.dart`

Section "Gamepad" avec 6 options:
- **Enable Joy-Con** (switch) — `gamepad-enabled` → `'Y'`/`''`
- **Mouse Speed** (slider dialog) — `gamepad-mouse-speed` → `'0.5'`..`'3.0'` (défaut `'1.5'`)
- **Rotate Stick Axes** (switch) — `gamepad-rotate-axes` → `'Y'`/`''`
- **Show Button Overlay** (switch) — `gamepad-show-overlay` → `'Y'`/`''`
- **Joy-Con Side** (dialog) — `gamepad-side` → `''`/`'right'` (reset mappings avec confirmation)
- **Button Mappings** (navigation) → `GamepadMappingsPage` (éditeur complet, 3 layers)

Section "Voice Call" avec 1 option:
- **Show voice call button** (switch) — `show-voice-call-button` → `''`/`'N'` (local option)

Note: l'auto-accept est configuré uniquement côté desktop (Settings > General > Other) car la logique tourne server-side dans `connection.rs`.

## Fichier 7: gamepad_config.dart (Nouveau)

**Chemin**: `flutter/lib/models/gamepad_config.dart`

Modèle de données pour les mappings configurables:

- `enum JoyConSide { left, right }` — côté Joy-Con
- `enum TriggerMode { modifier, action }` — mode trigger
- `class GamepadAction` — parse `"ctrl+shift+VK_Z"` en modifiers + VK
- `class GamepadActions` — liste prédéfinie de 30+ actions avec labels UI + labels courts overlay
- `class LogicalButton` — 9 noms logiques (`stick`, `dpad_up`, `bumper`, etc.)
- `class GamepadConfig` — config complète:
  - `side`, `zlMode`, `zrMode`, `zlAction`, `zrAction`
  - `normalLayer`, `zlLayer`, `zrLayer` (Map<String, String>)
  - `getAction(logical, {zlHeld, zrHeld})` — lookup 3-layer
  - `toJsonString()` / `fromJsonString()` — persistence JSON
  - `defaultLeft()` / `defaultRight()` — presets par défaut

## Fichier 8: gamepad_mappings_page.dart (Nouveau)

**Chemin**: `flutter/lib/mobile/pages/gamepad_mappings_page.dart`

Éditeur complet de mappings:
- Sections: Trigger Modes, Normal layer, ZL Modifier Layer, ZR Modifier Layer, Presets
- Trigger modes: `SettingsTile.switchTile()` toggle modifier↔action
- Chaque bouton: tile → dialog avec RadioListTile de toutes les actions
- Reset to Default: avec dialog de confirmation
- Sauvegarde immédiate via `_saveConfig()` → `gFFI.gamepadModel.reloadConfig()`

## Fichier 9: desktop_setting_page.dart (Modifications)

**Chemin**: `flutter/lib/desktop/pages/desktop_setting_page.dart`

### Changements

1. **Auto-accept voice calls**: Ajout dans `other()` → `_OptionCheckBox(context, 'Auto-accept voice calls', 'voice-call-auto-accept')`

2. **Nomad settings tab**: Nouvel onglet "Nomad" dans SettingsTabKey enum + `_Nomad` widget
   - License key field + Activate button
   - Server URL field (default: `https://nomadrust.dev`)
   - Status display (active/expired/inactive)
   - Deactivate button
   - Show QR toggle → renders `QrActivationWidget`

3. **HTTP activation**: POSTs to the configured server URL for license activation

4. **Storage**: Uses `NomadSecureStorage` helper (wraps `bind.mainSetLocalOption()`)

## Fichier 10: secure_storage.dart (Nouveau)

**Chemin**: `flutter/lib/common/utils/secure_storage.dart`

Utilitaire pour stocker les données de licence Nomad via LocalConfig.

### API
- `saveLicenseData(key, token, expiresAt)` — Sauvegarde les 3 valeurs
- `getLicenseKey()` → String
- `getLicenseToken()` → String
- `getExpiresAt()` → String
- `getServerUrl()` → String (default: `https://nomadrust.dev`)
- `setServerUrl(url)` — Configure le endpoint
- `clearLicense()` — Efface toutes les données (deactivation)

### Keys LocalConfig
- `nomad-license-key`
- `nomad-license-token`
- `nomad-expires-at`
- `nomad-server-url`

**Note**: Utilise `bind.mainSetLocalOption()` / `bind.mainGetLocalOption()` (synchrone, pas de Future). Prêt pour migration Android Keystore via `flutter_secure_storage` (à ajouter au pubspec.yaml).

## Fichier 11: qr_activation.dart (Nouveau)

**Chemin**: `flutter/lib/common/widgets/qr_activation.dart`

Widget QR code pour activation mobile.

### Props
- `licenseKey` — Clé de licence (format `N0MD-XXXX-XXXX-XXXX`)
- `serverUrl` — URL du serveur

### Format QR
```
nomad-activate://{LICENSE_KEY}@{DOMAIN}
```
Exemple: `nomad-activate://N0MD-XXXX-XXXX-XXXX@nomadrust.dev`

### Rendu
- Si `licenseKey.isEmpty` → placeholder gris "Activate a license key first"
- Sinon:
  - QR code 280x280 (noir sur blanc, eye shape: square)
  - License key affiché en monospace (selectable)
  - Instructions: "Scan with your phone to activate Nomad" + fallback manual entry

### Dépendances
Utilise `qr_flutter: ^4.1.0` (déjà dans pubspec.yaml)

## Build & Test

```bash
# Build debug APK (JDK 17 obligatoire)
cd ~/rustdesk/flutter && JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug

# Install
adb install -r ~/rustdesk/flutter/build/app/outputs/flutter-apk/app-debug.apk

# Régénérer le patch
cd ~/rustdesk && git diff -- flutter/ > docs/patches/apk/rustdesk-gamepad.patch
```

## Design Decisions

### Pourquoi `WeakReference<FFI>` ?
Empêche le GamepadModel de maintenir la session FFI en vie. Si la session est fermée, le GC peut récupérer l'objet FFI, et le Timer détecte `parent.target == null` puis appelle `stop()`.

### Pourquoi pas `ChangeNotifier` ?
Le GamepadModel n'a pas d'état observable par l'UI. C'est un pur producteur d'input. Pas besoin de `notifyListeners()`.

### Pourquoi Timer 60fps au lieu d'envoyer sur chaque MotionEvent ?
- Fréquence constante indépendante du device (MotionEvent = 30-120Hz variable)
- Le stick est un axe continu: on cache la dernière valeur et poll à intervalle fixe
- Permet de throttle le scroll séparément (~15fps)

### Pourquoi `bind.sessionSendMouse` direct au lieu de `InputModel.sendMobileRelativeMouseMove` ?
Le gamepad a besoin de:
1. Pas de `modify()` (isolation des modificateurs clavier)
2. `moveByDelta()` pour l'overlay curseur local
3. Pas de check `relativeMouseMode` (toujours relatif)

Duplication partielle avec `sendMobileRelativeMouseMove` — refactorable dans un helper commun pour V2.
