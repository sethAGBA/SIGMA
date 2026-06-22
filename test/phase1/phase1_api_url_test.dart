import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/api_service.dart';

void main() {
  group('ApiService._normalizeBaseUrl', () {
    test('ajoute /api/v1 si absent', () {
      expect(
        ApiService.normalizeBaseUrlForTesting('http://localhost:8000'),
        'http://localhost:8000/api/v1',
      );
    });

    test('conserve /api/v1 existant', () {
      expect(
        ApiService.normalizeBaseUrlForTesting('http://192.168.1.10:8000/api/v1'),
        'http://192.168.1.10:8000/api/v1',
      );
    });

    test('supprime le slash final avant normalisation', () {
      expect(
        ApiService.normalizeBaseUrlForTesting('http://localhost:8000/'),
        'http://localhost:8000/api/v1',
      );
    });
  });
}
