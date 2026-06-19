# Document de Conception — Phase 1 Sécurité (Complément)

## Vue d'ensemble

Deux fonctionnalités à implémenter : le timeout de session par inactivité et le chiffrement SQLite via `sqflite_sqlcipher`.

---

## 1. Timeout de session

### Architecture

```
MainLayout (GestureDetector racine)
    ↓ onTap / onPanUpdate / etc.
SessionManager (singleton)
    ├── InactivityTimer (dart:async Timer)
    ├── WarningTimer (60s avant expiration)
    └── AuthService.logout() → LoginPage
```

### `SessionManager` (nouveau fichier : `lib/core/services/session_manager.dart`)

```dart
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;

  Timer? _inactivityTimer;
  Timer? _warningTimer;
  bool _warningShown = false;

  void start(BuildContext context) { ... }
  void resetTimer(BuildContext context) { ... }
  void stop() { ... }
  void _showWarning(BuildContext context) { ... }
  void _logout(BuildContext context) { ... }
}
```

### Intégration dans `MainLayout`

Envelopper le `Scaffold` dans un `GestureDetector` avec `behavior: HitTestBehavior.translucent` qui appelle `SessionManager().resetTimer(context)` sur chaque interaction.

### `AuthService` — ajout de `sessionTimeoutMinutes`

- Nouvelle propriété `int _sessionTimeoutMinutes = 15`
- Chargée depuis `SharedPreferences` dans `init()`
- Méthode `setSessionTimeout(int minutes)` avec validation [1, 480]

---

## 2. Chiffrement SQLite

### Décision d'implémentation

> **Note importante** : `sqflite_sqlcipher` présente des complications connues sur Windows Desktop (FFI). Pour cette raison, l'implémentation utilisera une approche conditionnelle :
> - **Windows/Linux/macOS** : conserver `sqflite_common_ffi` (pas de chiffrement natif SQLCipher sur desktop Windows sans compilation C++) — chiffrement via AES au niveau applicatif des données sensibles
> - **Android/iOS** : utiliser `sqflite_sqlcipher`

Après analyse, le package `sqflite_sqlcipher` ne supporte pas nativement Windows Desktop sans setup C++ complexe. L'approche retenue pour ce projet (Windows-first) est :

**Chiffrement de la base via mot de passe PRAGMA** avec `sqflite_common_ffi` + SQLite SEE (payant) ou alternative : utiliser `drift` avec SQLCipher.

**Décision finale** : Implémenter le chiffrement uniquement sur mobile (Android/iOS) via `sqflite_sqlcipher`, et sur Windows conserver `sqflite_common_ffi` avec une note dans la documentation. Le timeout de session reste la priorité principale.

### `KeyDerivationService` (nouveau fichier : `lib/core/services/key_derivation_service.dart`)

```dart
class KeyDerivationService {
  Future<String> getOrCreateKey(String username) async { ... }
  String _deriveKey(String username, String salt) { ... }
}
```

Utilise `flutter_secure_storage` pour le sel, PBKDF2 via `pointycastle` ou dérivation simplifiée via SHA-256 (selon packages disponibles).

---

## Fichiers modifiés / créés

| Fichier | Action |
|---|---|
| `lib/core/services/session_manager.dart` | Nouveau |
| `lib/core/services/auth_service.dart` | Modifié (sessionTimeoutMinutes) |
| `lib/screens/main_layout.dart` | Modifié (GestureDetector + SessionManager) |
| `pubspec.yaml` | Modifié (flutter_secure_storage) |

---

## Propriétés de correction

- **P1** : `SessionManager` démarre exactement 1 timer à la fois
- **P2** : Toute interaction reset le timer (idempotent)
- **P3** : La déconnexion auto navigue vers LoginPage et vide la pile
- **P4** : Le WarningDialog n'est affiché qu'une seule fois par cycle
