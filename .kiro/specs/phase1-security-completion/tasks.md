# Plan d'implémentation — Phase 1 Sécurité (Complément)

## Tasks

- [ ] 1. Ajouter `sessionTimeoutMinutes` dans `AuthService`
  - Ajouter `int _sessionTimeoutMinutes = 15` et `bool _sessionTimeoutEnabled = true`
  - Dans `init()`, lire `session_timeout_minutes` depuis `SharedPreferences`
  - Ajouter `Future<void> setSessionTimeout(int minutes)` avec validation [1, 480]
  - Exposer `int get sessionTimeoutMinutes`
  - _Exigences : 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

- [ ] 2. Créer `SessionManager`
  - Créer `lib/core/services/session_manager.dart` singleton
  - `void start(BuildContext context)` : démarre `_inactivityTimer` (durée = `AuthService().sessionTimeoutMinutes * 60s`) et `_warningTimer` (durée - 60s)
  - `void resetTimer(BuildContext context)` : annule et recrée les deux timers
  - `void stop()` : annule les deux timers, reset `_warningShown`
  - `_warningTimer` callback : si `!_warningShown` → afficher `WarningDialog` via `navigatorKey`
  - `_inactivityTimer` callback : fermer dialog si ouvert → `AuthService().logout()` → `Navigator.pushAndRemoveUntil(LoginPage)`
  - Utiliser un `GlobalKey<NavigatorState>` défini dans `main.dart` pour accéder au contexte
  - _Exigences : 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.6, 4.1, 4.2, 4.3, 4.4_

- [ ] 3. Créer le `WarningDialog`
  - Widget `StatelessWidget` affichant "Votre session expire dans 1 minute. Touchez l'écran pour rester connecté."
  - Bouton "Rester connecté" → `SessionManager().resetTimer(context)` + `Navigator.pop`
  - _Exigences : 3.2, 3.3, 3.4_

- [ ] 4. Intégrer `SessionManager` dans `MainLayout` et `main.dart`
  - Ajouter `static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>()` dans `main.dart`
  - Passer `navigatorKey` au `MaterialApp`
  - Dans `MainLayout`, envelopper le `Scaffold` dans `GestureDetector(behavior: HitTestBehavior.translucent, onTap: ..., onPanUpdate: ...)` qui appelle `SessionManager().resetTimer(context)`
  - Appeler `SessionManager().start(context)` dans `initState` de `_MainLayoutState`
  - Appeler `SessionManager().stop()` dans `dispose` de `_MainLayoutState`
  - Dans `AuthService.logout()`, appeler `SessionManager().stop()`
  - Dans `AuthService.init()`, si session persistée valide → appeler `SessionManager().start(navigatorKey.currentContext!)`
  - _Exigences : 2.1, 2.4, 2.5, 4.2_

- [ ] 5. Ajouter `flutter_secure_storage` dans `pubspec.yaml` et créer `KeyDerivationService`
  - Ajouter `flutter_secure_storage: ^9.2.2` dans `pubspec.yaml`
  - Créer `lib/core/services/key_derivation_service.dart`
  - `Future<String> getOrCreateKey(String username)` : lit/crée le sel dans `FlutterSecureStorage`, dérive la clé via SHA-256 sur `"$username:$salt"` (simplifié, pas de PBKDF2 pour éviter `pointycastle`), encode en hex
  - Ce service est préparé pour le chiffrement mobile futur — sur Windows il retourne la clé sans l'appliquer
  - _Exigences : 5.1, 5.2, 5.3, 5.4, 5.5, 8.2_

- [ ] 6. Valider avec `flutter analyze`
  - Vérifier 0 erreurs sur les nouveaux fichiers
  - Vérifier que le hot-restart fonctionne correctement

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2", "3"] },
    { "wave": 3, "tasks": ["4"] },
    { "wave": 4, "tasks": ["5"] },
    { "wave": 5, "tasks": ["6"] }
  ]
}
```
