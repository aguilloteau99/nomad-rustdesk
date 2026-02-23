# Audit Trail — Patch vs Documentation Verification

Audit des docs comparé à ce qui existe réellement sur Android avec les Joy-Con.

> **Parent guide**: See `patches/apk/CLAUDE.md` for quick start and overview.
>
> **Status**: Audit pré-implémentation, puis résolution post-tests sur Samsung S10+ (Android 12).
> Tous les items ⚠️ ont été vérifiés et résolus. Patch final: 3407 lines, 12 files.


## Résumé

| Aspect | Status | Résolution |
|---|---|---|
| Architecture EventChannel | ✅ Validé | Pattern standard, fonctionne parfaitement |
| dispatchKeyEvent/dispatchGenericMotionEvent | ✅ Validé | Approche correcte |
| Keycodes DPAD_* | ✅ **Vérifié** | Joy-Con L envoie DPAD_* sur Samsung S10+ |
| Keycodes BUTTON_A/B/X/Y fallback | ✅ **Implémenté** | Dual-mapping dans `_toDirection()` |
| Keycodes L1/L2 | ✅ **Vérifié** | L1=102, ZL=104 (digital, pas analog) |
| AXIS_X/AXIS_Y pour stick | ✅ Validé | Standard Android, confirmé |
| AXIS_LTRIGGER conflit | ✅ **Résolu** | `_zlFromKey` priority flag |
| Deadzone 0.15 | ✅ Raisonnable | Pas de drift observé sur S10+ |
| SL/SR ignorés | ✅ Prudent | Correct — détection non fiable |
| Timer 60fps pour mouse | ✅ Validé | Mouvement fluide confirmé |
| Home (110) / Minus (109) | ✅ **Vérifié** | Home=Enter, Minus=Backspace |

## Critiques Détaillées

### 1. ✅ KEYCODES FACE BUTTONS — RÉSOLU

**Problème original**: La doc assumait `KEYCODE_DPAD_UP/DOWN/LEFT/RIGHT`. Le Pro Controller keylayout suggérait `BUTTON_A/B/X/Y`.

**Résultat test (Samsung S10+)**: Les face buttons envoient `DPAD_*` (19-22), pas `BUTTON_*`.

**Solution implémentée**: Dual-mapping dans `_toDirection()` accepte les deux:
```dart
case _kDpadUp:      // 19
case _kButtonX:     // 99
  return 'up';
```

Fonctionne quel que soit le device (DPAD_* ou BUTTON_*).

---

### 2. ✅ PRODUCT ID — NON-ISSUE

**Problème original**: Le Joy-Con peut avoir différents Product IDs selon le mode.

**Résultat**: L'implémentation ne dépend pas du Product ID. On filtre par `SOURCE_GAMEPAD | SOURCE_JOYSTICK`, ce qui fonctionne indépendamment du device ID.

---

### 3. ✅ ARCHITECTURE EVENTCHANNEL — VALIDÉE

Fonctionne comme prévu. Pattern identique à `flutter_gamepad`, `gamepads` (Flame).

---

### 4. ✅ STICK CLICK (THUMBL) — VÉRIFIÉ

**Résultat test**: `KEYCODE_BUTTON_THUMBL` (106) fonctionne pour le click du stick. Mappé à right click.

---

### 5. ✅ DEADZONE 0.15 — CONFIRMÉ

Pas de drift observé sur le Joy-Con L testé. La valeur 0.15 est suffisante.

---

### 6. ✅ SL/SR IGNORÉS — CONFIRMÉ

Décision correcte. Pas de keycodes fiables observés.

---

### 7. ✅ MINUS/HOME BUTTONS — CORRIGÉ

**Problème original**: La doc initiale mappait Minus (109) → Enter.

**Résultat test**:
- Minus (109, `BUTTON_SELECT`) = bouton physique "-" → mappé à **Backspace** (VK_BACK)
- Home (110, `BUTTON_MODE`) = bouton physique Home → mappé à **Enter** (VK_RETURN)

L'utilisateur a corrigé cette erreur lors des tests.

---

### 8. ✅ ZL TRIGGER — RÉSOLU (CRITIQUE)

**Problème original**: ZL peut être KeyEvent OU MotionEvent (AXIS_LTRIGGER).

**Résultat test**: Le Joy-Con ZL est un bouton **digital** (pas analogique). Il envoie:
- `KeyEvent BUTTON_L2` (104) avec action down/up → correct
- `AXIS_LTRIGGER = 0.0` dans **chaque** MotionEvent → problème!

**Bug découvert**: Le code Kotlin envoie `ltrigger: 0.0` dans chaque axis event. Côté Dart, `ltrigger < 0.1` remettait `_zlHeld = false`, écrasant l'état du KeyEvent.

**Solution**: `_zlFromKey` priority flag. Quand ZL est pressé via KeyEvent, `_zlFromKey = true` empêche AXIS_LTRIGGER de modifier `_zlHeld`. Quand ZL est relâché via KeyEvent, `_zlFromKey = false` restaure la détection analogique pour les devices qui n'envoient pas de KeyEvent.

---

### 9. ✅ TIMER-BASED POLLING — CONFIRMÉ

Mouvement fluide. Le Timer 60fps avec accumulateur fractionnaire donne un mouvement précis même à faible vitesse.

---

### 10. ⏳ GESTION DÉCONNEXION/RECONNEXION — DIFFÉRÉ V2

Pas implémenté. Le `onError`/`onDone` du stream gère la déconnexion proprement (appelle `stop()`). Reconnexion nécessite un redémarrage de la session remote. Suffisant pour V1.

---

### 11. ✅ ORIENTATION STICK EN HORIZONTAL — RÉSOLU

**Résultat test**: Sur Samsung S10+, Android **ne corrige PAS** automatiquement les axes.

**Solution**: Option `gamepad-rotate-axes` dans Settings qui applique une rotation 90° CCW:
```dart
if (_rotateAxes) {
  final tmp = x;
  x = -y;
  y = tmp;
}
```

Sur le device testé, la rotation **n'était pas nécessaire** (stick correct sans rotation). L'option est disponible pour les devices qui en ont besoin.

---

## Corrections PR Quality (Post-Audit)

Après implémentation, 4 agents de revue automatisés ont identifié 11 corrections supplémentaires:

| # | Correction | Sévérité |
|---|---|---|
| 1 | `y * 120` → `y` (double-multiplication scroll Windows) | Critique |
| 2 | `onError` → `stop()` (Timer leak) | Critique |
| 3 | Retirer `modify()` (bleed modificateurs clavier) | Critique |
| 4 | Retirer `debugPrint` per-event | High |
| 5 | Reset scroll state sur ZL false→true | High |
| 6 | Null `eventSink` sur ISE catch Kotlin | High |
| 7 | `parent.target == null` → `stop()` | High |
| 8 | `ffi.ffiModel.keyboard` (safe, pas de force-unwrap) | Medium |
| 9 | `ConnType.viewCamera` guard | Medium |
| 10 | `onDestroy` cleanup gamepad handler | Medium |
| 11 | Retirer `deviceId` inutilisé du Kotlin | Low |

Toutes appliquées dans le patch final.

## Projets Similaires Analysés

| Projet | Plateforme | Approche | Notes |
|---|---|---|---|
| [flutter_gamepad](https://github.com/RainwayApp/flutter_gamepad) | Flutter/Android | EventChannel + dispatch overrides | Archivé 2023, mais pattern valide |
| [gamepads](https://github.com/flame-engine/gamepads) | Flutter multi-platform | GamepadsCompatibleActivity | En beta, même approche |
| [BetterJoy](https://github.com/Davidobot/BetterJoy) | Windows | HID direct | Problèmes SL/SR documentés |
| [joycon-toolkit](https://github.com/mumumusuc/joycon-toolkit) | Android/Linux | Dart + native | Avertissement "peut endommager Joy-Con" |
| [OneController](https://github.com/Magisk-Modules-Repo/OneController) | Android (root) | Keylayout files | Source fiable pour scancodes |
| [Steam Input](https://partner.steamgames.com/doc/features/steam_controller) | Multi-platform | Configurateur avancé | Inspiration courbe accélération (power 2.5) |
| [JoyShockMapper](https://github.com/Electronicks/JoyShockMapper) | Windows | HID direct | Inspiration accélération stick-to-mouse |

## Sources

- [Android Handle controller actions](https://developer.android.com/develop/ui/views/touch-and-input/game-controllers/controller-input)
- [flutter_gamepad GamepadStreamHandler.kt](https://github.com/RainwayApp/flutter_gamepad/blob/master/android/src/main/kotlin/com/example/flutter_gamepad/GamepadStreamHandler.kt)
- [gamepads Flutter package](https://pub.dev/packages/gamepads)
- [OneController keylayout](https://github.com/Magisk-Modules-Repo/OneController/blob/master/system/usr/keylayout/Vendor_057e_Product_2009.kl)
- [BetterJoy SL/SR issues](https://github.com/Davidobot/BetterJoy/issues/740)
- [Device Hunt Joy-Con L](https://devicehunt.com/view/type/usb/vendor/057E/device/2006)
- [KeyEvent Display App](https://play.google.com/store/apps/details?id=aws.apps.keyeventdisplay)
