import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/api_service.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/user_model.dart';

import '../helpers/phase1_test_helpers.dart';
import '../helpers/test_user_factory.dart';

void main() {
  setUpAll(initPhase1TestBindings);

  setUp(() => resetPhase1SecureStorage());

  tearDown(tearDownPhase1Services);

  group('Property 1 — Stockage sécurisé post-login', () {
    test('100 itérations round-trip persistTokens', () async {
      final random = Random(42);
      const storage = FlutterSecureStorage();

      for (var i = 0; i < 100; i++) {
        resetPhase1SecureStorage();
        final access = randomToken(random);
        final refresh = randomToken(random);

        await ApiService().persistTokens(
          accessToken: access,
          refreshToken: refresh,
        );

        expect(await storage.read(key: ApiService.accessTokenKey), access);
        expect(await storage.read(key: ApiService.refreshTokenKey), refresh);
      }
    });
  });

  group('Property 3 — Nettoyage sécurisé au logout', () {
    test('100 itérations : logout efface les tokens JWT', () async {
      final random = Random(7);
      const storage = FlutterSecureStorage();

      for (var i = 0; i < 100; i++) {
        resetPhase1SecureStorage();
        final access = randomToken(random);
        final refresh = randomToken(random);
        await ApiService().persistTokens(
          accessToken: access,
          refreshToken: refresh,
        );

        AuthService().setCurrentUserForTesting(buildTestUser());
        await AuthService().logout();

        expect(await storage.read(key: ApiService.accessTokenKey), isNull);
        expect(await storage.read(key: ApiService.refreshTokenKey), isNull);
      }
    });
  });

  group('Property 2 — Restauration de session au démarrage', () {
    test('accessToken valide + session_user_id → isLoggedIn après init', () async {
      const userId = 'user-restore-1';
      final user = buildTestUser(username: 'restore_user');
      final db = await createPhase1TestDatabase();
      await seedTestUser(
        db,
        UserAccount(
          id: userId,
          agentId: user.agentId,
          username: user.username,
          passwordHash: user.passwordHash,
          role: user.role,
          isActive: true,
          createdAt: user.createdAt,
          permissions: user.permissions,
        ),
      );
      DatabaseService.setDatabaseForTesting(db);

      resetPhase1SecureStorage({
        ApiService.accessTokenKey: buildValidJwt(),
      });
      await resetPhase1Prefs({'session_user_id': userId});

      ApiService().isServerAvailableOverride = () async => true;

      await AuthService().init();

      expect(AuthService().isLoggedIn, isTrue);
      expect(AuthService().isOnlineMode, isTrue);
      expect(AuthService().currentUserId, userId);
    });
  });

  group('Property 5 — Chargement du token au démarrage ApiService', () {
    test('100 itérations : init charge le token pour Authorization', () async {
      final random = Random(99);

      for (var i = 0; i < 100; i++) {
        ApiService.resetForTesting();
        final token = randomToken(random);
        resetPhase1SecureStorage({ApiService.accessTokenKey: token});
        await resetPhase1Prefs();

        await ApiService().init();

        expect(ApiService().currentAccessToken, token);
        expect(
          ApiService().headersFor('/clients')['Authorization'],
          'Bearer $token',
        );
      }
    });
  });
}
