# Joy-Con Hardware Specifications & Keycodes

Hardware specifications for Nintendo Joy-Con (left or right, horizontal mode) as configurable mouse/keyboard controller for RustDesk Android.

> **Parent guide**: See `patches/apk/CLAUDE.md` for quick start, build instructions, and overview.
>
> **Status**: Implémenté et testé sur Samsung S10+ avec Joy-Con L (firmware Android 12). Joy-Con R supporté (mappings configurables). PR-ready après 4 audits de qualité code + audit post-configuration.

## Matériel Supporté

**Joy-Con Gauche ou Droit** en mode horizontal (tenu sur le côté, SL+SR face à soi pour sync). Un seul Joy-Con à la fois. Sélection dans **Settings → Gamepad → Joy-Con Side**.

### Keycodes Vérifiés (Samsung S10+)

| Bouton | KeyCode Android | Code | Vérifié |
|---|---|---|---|
| Stick analogique | `AXIS_X`, `AXIS_Y` | — | ✅ Testé |
| Stick click | `KEYCODE_BUTTON_THUMBL` | 106 | ✅ Testé |
| Face ↑ | `KEYCODE_DPAD_UP` | 19 | ✅ Testé |
| Face ↓ | `KEYCODE_DPAD_DOWN` | 20 | ✅ Testé |
| Face ← | `KEYCODE_DPAD_LEFT` | 21 | ✅ Testé |
| Face → | `KEYCODE_DPAD_RIGHT` | 22 | ✅ Testé |
| L (épaule) | `KEYCODE_BUTTON_L1` | 102 | ✅ Testé |
| ZL (gâchette) | `KEYCODE_BUTTON_L2` | 104 | ✅ Testé (digital, pas analog) |
| Minus (-) | `KEYCODE_BUTTON_SELECT` | 109 | ✅ Testé |
| Home | `KEYCODE_BUTTON_MODE` | 110 | ✅ Testé |
| SL | Variable | — | ⚠️ Ignoré |
| SR | Variable | — | ⚠️ Ignoré |
| Capture | Non standard | — | ❌ Ignoré |

**Note**: Les face buttons envoient bien `DPAD_*` (pas `BUTTON_A/B/X/Y`). Le code gère les deux cas via dual-mapping dans `_toLogicalButton()`, mais sur ce device seul `DPAD_*` est observé.

**Note ZL**: Le Joy-Con ZL est un bouton digital (KeyEvent 104), pas une gâchette analogique. Android envoie cependant `AXIS_LTRIGGER=0.0` dans chaque MotionEvent, ce qui peut écraser l'état du bouton. Résolu par le mécanisme de priorité `_zlFromKey`.

### Keycodes Joy-Con Droit (mode horizontal)

| Bouton | KeyCode Android | Code | Vérifié |
|---|---|---|---|
| Stick analogique | `AXIS_X`, `AXIS_Y` | — | ⚠️ À tester |
| Stick click | `KEYCODE_BUTTON_THUMBR` | 107 | ⚠️ À tester |
| Face ↑ | `KEYCODE_DPAD_UP` | 19 | ⚠️ À tester |
| Face ↓ | `KEYCODE_DPAD_DOWN` | 20 | ⚠️ À tester |
| Face ← | `KEYCODE_DPAD_LEFT` | 21 | ⚠️ À tester |
| Face → | `KEYCODE_DPAD_RIGHT` | 22 | ⚠️ À tester |
| R (épaule) | `KEYCODE_BUTTON_R1` | 103 | ⚠️ À tester |
| ZR (gâchette) | `KEYCODE_BUTTON_R2` | 105 | ⚠️ À tester |
| Plus (+) | `KEYCODE_BUTTON_START` | 108 | ⚠️ À tester |
| Home | `KEYCODE_BUTTON_MODE` | 110 | ⚠️ À tester |

**Note ZR**: Même mécanisme que ZL — bouton digital (KeyEvent 105), priorité `_zrFromKey` empêche `AXIS_RTRIGGER=0.0` de prendre le dessus.

## Mapping par Défaut

> **Note**: Les mappings sont maintenant entièrement configurables via **Settings → Gamepad → Button Mappings**. Les tableaux ci-dessous montrent les défauts pour Joy-Con L. Joy-Con R utilise ZR comme modificateur au lieu de ZL.

### Actions Normales

| Input | Action |
|---|---|
| Stick | Mouvement souris (avec accélération) |
| ZL + Stick | Scroll (molette souris) |
| Stick click | Clic droit |
| L (épaule) | Clic gauche |
| ZL (gâchette) | **Modificateur** (maintenir pour combos/scroll) |
| ↑ | Flèche haut |
| ↓ | Flèche bas |
| ← | Flèche gauche |
| → | Flèche droite |
| Home (110) | Enter |
| Minus (109) | Backspace |

### Combos (ZL + bouton)

| Input | Action |
|---|---|
| ZL + Stick | Scroll molette (throttle ~15fps) |
| ZL + ↑ | Shift+Tab (navigation arrière) |
| ZL + ↓ | Escape |
| ZL + ← | Ctrl+Z (undo) |
| ZL + → | Ctrl+Shift+Z (redo) |

## Configuration

Intégrée dans **Settings → Mobile → Gamepad** (pas de fichier externe). Stockage via `bind.mainSetLocalOption()`.

| Option (clé) | Type | Défaut | Description |
|---|---|---|---|
| `gamepad-enabled` | `'Y'`/`''` | `''` | Active/désactive le support gamepad |
| `gamepad-mouse-speed` | `'0.5'`..`'3.0'` | `'1.5'` | Multiplicateur vitesse souris |
| `gamepad-rotate-axes` | `'Y'`/`''` | `''` | Inverse les axes X/Y du stick |
| `gamepad-show-overlay` | `'Y'`/`''` | `''` | Affiche l'overlay Joy-Con en session |
| `gamepad-side` | `''`/`'right'` | `''` | Côté Joy-Con (`''` = gauche) |
| `gamepad-mappings` | JSON string | `''` | Config complète (3 layers, trigger modes) |
| `show-voice-call-button` | `''`/`'N'` | `''` | Bouton flottant appel vocal (masqué si `'N'`) |

## Paramètres Techniques

### Deadzone

- Valeur: 0.15 (15% de la course du stick)
- Remapping: `[deadzone, 1.0]` → `[0.0, 1.0]` pour éviter les sauts de vitesse
- Raison: Les Joy-Con sont sujets au drift, 15% filtre les mouvements parasites

### Accélération Souris

Courbe puissance 2.5 pour mouvement précis à faible déflexion, rapide à pleine course:

```
speed = (baseSpeed + (maxSpeed - baseSpeed) × magnitude^accelPower) × mouseSpeed

Où:
  magnitude = √(x² + y²), clampé [0, 1]
  baseSpeed = 1.0 pixel/tick
  maxSpeed = 25.0 pixels/tick
  accelPower = 2.5
  mouseSpeed = 1.5 (configurable dans Settings)
  tickRate = ~60fps (16ms)
```

Inspiré de Steam Input / JoyShockMapper. Le power 2.5 (vs quadratique 2.0) crée une zone de précision plus large pour les petits mouvements, idéal pour cliquer sur des boutons UI.

| Déflexion | Speed (brut) | × mouseSpeed 1.5 | Pixels/seconde |
|---|---|---|---|
| 10% | ~1.0 px/tick | ~1.5 | ~94 px/s |
| 25% | ~1.1 px/tick | ~1.6 | ~100 px/s |
| 50% | ~2.4 px/tick | ~3.6 | ~225 px/s |
| 100% | 25 px/tick | 37.5 | ~2340 px/s |

### Timer-based Polling

Le mouvement souris utilise un Timer Dart à 60fps plutôt que d'envoyer sur chaque MotionEvent Android:
- Fréquence constante indépendante du device
- Mouvement fluide
- Cache les valeurs d'axes, poll à intervalle fixe

## Architecture

```
┌─────────────────┐
│   Joy-Con (BT)  │
└────────┬────────┘
         │ Bluetooth HID
         ▼
┌─────────────────────────────────────────────────┐
│              Android Activity                    │
│  ┌─────────────────────────────────────────┐    │
│  │ dispatchKeyEvent() / dispatchGeneric... │    │
│  └────────────────┬────────────────────────┘    │
│                   │                              │
│  ┌────────────────▼────────────────────────┐    │
│  │         GamepadHandler.kt               │    │
│  │  - Filter SOURCE_GAMEPAD/JOYSTICK       │    │
│  │  - Apply deadzone                       │    │
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
│  │         InputModel (existant)           │     │
│  │  - sendMouse(type, buttons, x, y)       │     │
│  │  - inputKey(name, down, press)          │     │
│  └────────────────┬───────────────────────┘     │
└───────────────────┼─────────────────────────────┘
                    │ RustDesk Protocol
                    ▼
┌─────────────────────────────────────────────────┐
│           Remote Desktop (Linux)                 │
│  - Reçoit événements souris/clavier             │
│  - Exécute sur le bureau distant                │
└─────────────────────────────────────────────────┘
```

## Appairage Joy-Con

1. Sur le Joy-Con gauche, appuyer sur le bouton SYNC (petit bouton sur le rail, entre SL et SR)
2. Les LEDs clignotent
3. Sur Android: **Paramètres → Bluetooth → Associer un appareil**
4. Sélectionner "Joy-Con (L)"
5. Attendre la connexion (LEDs fixes = connecté)

**Note**: En mode horizontal, le stick est orienté correctement automatiquement par Android.

## Limitations

- **SL/SR ignorés**: Détection variable selon firmware Android/Joy-Con
- **Capture ignoré**: Bouton non standard, rarement mappé
- **Un seul Joy-Con à la fois**: L ou R, pas dual Joy-Con simultané
- **Pas de vibration**: Feedback haptique non implémenté
- **Pas de gyroscope**: Motion controls non utilisés

## Dépannage

### Le Joy-Con ne se connecte pas
- Vérifier Bluetooth activé sur Android
- Réinitialiser Joy-Con: maintenir SYNC 5 secondes
- Supprimer l'appairage existant et réessayer

### Drift du stick (mouvement fantôme)
- Augmenter `gamepad_deadzone` dans les settings (0.2 ou 0.25)
- Le Joy-Con peut avoir besoin d'une calibration ou réparation

### Latence élevée
- Vérifier connexion Bluetooth stable
- Fermer autres apps utilisant Bluetooth
- Réduire `gamepad_mouse_speed` si le mouvement est saccadé

### Boutons ne répondent pas
- Vérifier que gamepad est activé dans Settings → Gamepad
- Tester avec app [KeyEvent Display](https://play.google.com/store/apps/details?id=aws.apps.keyeventdisplay) pour voir les keycodes reçus
- Certains boutons peuvent avoir des keycodes différents selon le firmware

## Fichiers Modifiés (RustDesk)

See `patches/apk/CLAUDE.md` for complete file list (12 files total: 6 new, 5 modified, 1 build system).

| Fichier | Modification |
|---|---|
| `flutter/android/.../GamepadHandler.kt` | **Nouveau** — Handler natif Android (+ AXIS_RTRIGGER) |
| `flutter/android/.../MainActivity.kt` | Ajout dispatch overrides + EventChannel |
| `flutter/lib/models/gamepad_config.dart` | **Nouveau** — Modèle de config (3 layers, actions, side) |
| `flutter/lib/models/gamepad_model.dart` | **Nouveau** — Dispatch config-driven, ZL/ZR, reloadConfig() |
| `flutter/lib/models/model.dart` | Ajout GamepadModel à FFI, CursorModel.moveByDelta() |
| `flutter/lib/mobile/pages/gamepad_mappings_page.dart` | **Nouveau** — Éditeur de mappings (trigger modes, 3 layers) |
| `flutter/lib/mobile/widgets/floating_joycon_overlay.dart` | **Nouveau** — Overlay Joy-Con L/R, labels config-driven |
| `flutter/lib/mobile/widgets/floating_voice_call.dart` | **Nouveau** — Bouton flottant appel vocal |
| `flutter/lib/mobile/pages/remote_page.dart` | Lifecycle, bouton vocal conditionnel, overlay |
| `flutter/lib/mobile/pages/settings_page.dart` | Sections Gamepad (6 options) + Voice Call (1 option) |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | Checkbox auto-accept appels vocaux |
| `flutter/pubspec.lock` | Dependency lock file updates |

## Références

- [Android KeyEvent](https://developer.android.com/reference/android/view/KeyEvent)
- [Android MotionEvent](https://developer.android.com/reference/android/view/MotionEvent)
- [Handle controller actions](https://developer.android.com/develop/ui/views/touch-and-input/game-controllers/controller-input)
- [Joy-Con Wikipedia](https://en.wikipedia.org/wiki/Joy-Con)
- [KeyEvent Display App](https://play.google.com/store/apps/details?id=aws.apps.keyeventdisplay)
- [Steam Input](https://partner.steamgames.com/doc/features/steam_controller)
- [JoyShockMapper](https://github.com/Electronicks/JoyShockMapper)
