import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/api_service.dart';

import '../helpers/phase1_test_helpers.dart';

void main() {
  setUpAll(initPhase1TestBindings);
  setUp(() => resetPhase1SecureStorage());
  tearDown(tearDownPhase1Services);

  group('Phase 1 — ApiService headersFor (Property 4)', () {
    test('token présent → Authorization sur endpoint protégé', () {
      final api = ApiService();
      api.setToken('test-access-token');
      final headers = api.headersFor('/clients');
      expect(headers['Authorization'], 'Bearer test-access-token');
    });

    test('token absent → pas de Authorization', () {
      final headers = ApiService().headersFor('/clients');
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('/auth/login et /auth/refresh exclus de Authorization', () {
      final api = ApiService();
      api.setToken('test-access-token');
      expect(api.headersFor('/auth/login').containsKey('Authorization'), isFalse);
      expect(api.headersFor('/auth/refresh').containsKey('Authorization'), isFalse);
    });
  });

  group('Phase 1 — ApiService isJwtExpired', () {
    String buildJwt({required int expEpochSeconds}) {
      final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
      final payload = base64Url.encode(
        utf8.encode('{"exp":$expEpochSeconds}'),
      );
      return '$header.$payload.sig';
    }

    test('JWT expiré → true', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final token = buildJwt(expEpochSeconds: past.millisecondsSinceEpoch ~/ 1000);
      expect(ApiService.isJwtExpired(token), isTrue);
    });

    test('JWT valide → false', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      final token = buildJwt(expEpochSeconds: future.millisecondsSinceEpoch ~/ 1000);
      expect(ApiService.isJwtExpired(token), isFalse);
    });

    test('JWT malformé → true', () {
      expect(ApiService.isJwtExpired('not-a-jwt'), isTrue);
    });
  });

  group('Property 6 — Unicité du refresh par cycle', () {
    test('N appels concurrents → un seul tryRefresh', () async {
      var refreshCalls = 0;
      final api = ApiService();
      api.setToken('old-token');
      api.tryRefreshOverride = () async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        api.setToken('new-token');
        return true;
      };

      final results = await Future.wait(
        List.generate(5, (_) => api.handleUnauthorizedForTesting()),
      );

      expect(refreshCalls, 1);
      expect(results.every((r) => r), isTrue);
    });
  });

  group('Property 7 — Rejeu avec nouveau token après refresh', () {
    test('refresh réussi → Authorization utilise le nouveau token', () async {
      final api = ApiService();
      api.setToken('expired-token');
      api.tryRefreshOverride = () async {
        api.setToken('fresh-token-after-refresh');
        return true;
      };

      final refreshed = await api.handleUnauthorizedForTesting();
      expect(refreshed, isTrue);
      expect(
        api.headersFor('/clients')['Authorization'],
        'Bearer fresh-token-after-refresh',
      );
    });
  });
}
