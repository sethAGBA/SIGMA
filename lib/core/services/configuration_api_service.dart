// lib/core/services/configuration_api_service.dart
//
// Stratégie "Server is Truth" :
//
// LECTURE connecté  → PostgreSQL (données partagées tous les postes)
//                   → Met à jour le cache SQLite local (fire-and-forget)
// LECTURE offline   → SQLite local (cache)
//
// ÉCRITURE          → SQLite local TOUJOURS (réponse UI immédiate)
//                   → Serveur si disponible
//                   → Sinon → file de sync (SyncService)

import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class ConfigurationApiService {
  static final ConfigurationApiService _instance =
      ConfigurationApiService._internal();
  factory ConfigurationApiService() => _instance;
  ConfigurationApiService._internal();

  // ── Lecture de toute la configuration ───────────────────────────────

  Future<Map<String, String>> getConfiguration() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/configuration');
        final data = ApiService.decodeResponse(response);
        if (data != null && data is Map) {
          final map = data.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
          _updateLocalCache(map);
          return map;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return _getLocalConfigurationMap();
  }

  // ── Mise à jour d'une clé ─────────────────────────────────────────────

  Future<void> updateConfiguration(String key, String value) async {
    await DatabaseService().updateConfiguration(key, value);

    if (await SyncService().isOnline) {
      try {
        await ApiService().put('/configuration', {key: value});
      } catch (_) {
        await SyncService().queueOperation(
          method: 'PUT',
          path: '/configuration',
          body: {key: value},
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'PUT',
        path: '/configuration',
        body: {key: value},
      );
    }
  }

  // ── Cache local ───────────────────────────────────────────────────────

  Future<Map<String, String>> _getLocalConfigurationMap() async {
    final db = await DatabaseService().database;
    final maps = await db.query('configurations');
    return {
      for (final m in maps)
        m['key'] as String: (m['value'] as String?) ?? '',
    };
  }

  Future<void> _updateLocalCache(Map<String, String> config) async {
    for (final entry in config.entries) {
      try {
        await DatabaseService().updateConfiguration(entry.key, entry.value);
      } catch (_) {}
    }
  }
}
