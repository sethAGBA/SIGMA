// lib/core/services/sync_service.dart
//
// Stratégie de synchronisation : "Server is Truth"
//
// Quand le serveur est DISPONIBLE :
//   → Lire depuis PostgreSQL (données partagées par tous les postes)
//   → Mettre à jour le cache SQLite local
//
// Quand le serveur est INDISPONIBLE :
//   → Lire depuis SQLite local (cache)
//   → Mettre en file les opérations d'écriture pour sync ultérieure
//
// Écriture :
//   → Toujours dans SQLite local D'ABORD (réponse immédiate UI)
//   → Puis envoi au serveur si disponible
//   → Si pas disponible → file de sync en attente

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  static const String _pendingOpsKey = 'pending_sync_operations';

  // ── Vérification disponibilité ────────────────────────────────────────

  Future<bool> get isOnline => ApiService().isServerAvailable();

  // ── File d'attente de sync ────────────────────────────────────────────

  /// Ajoute une opération dans la file si le serveur est indisponible.
  Future<void> queueOperation({
    required String method,   // POST, PUT, DELETE
    required String path,     // ex: /clients/42
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_pendingOpsKey);
    final List<dynamic> ops = existing != null ? jsonDecode(existing) : [];

    ops.add({
      'method': method,
      'path': path,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_pendingOpsKey, jsonEncode(ops));
  }

  /// Retourne le nombre d'opérations en attente de sync.
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_pendingOpsKey);
    if (existing == null) return 0;
    return (jsonDecode(existing) as List).length;
  }

  /// Envoie toutes les opérations en attente au serveur.
  /// À appeler au démarrage de l'app ou quand la connexion revient.
  Future<SyncResult> flushPendingOperations() async {
    if (!await isOnline) {
      return SyncResult(success: false, synced: 0, failed: 0);
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_pendingOpsKey);
    if (existing == null) return SyncResult(success: true, synced: 0, failed: 0);

    final List<dynamic> ops = jsonDecode(existing);
    int synced = 0;
    int failed = 0;
    final List<dynamic> remaining = [];

    for (final op in ops) {
      try {
        final method = op['method'] as String;
        final path = op['path'] as String;
        final body = op['body'] as Map<String, dynamic>?;

        bool ok = false;
        switch (method) {
          case 'POST':
            final resp = await ApiService().post(path, body ?? {});
            ok = ApiService.isSuccess(resp);
            break;
          case 'PUT':
            final resp = await ApiService().put(path, body ?? {});
            ok = ApiService.isSuccess(resp);
            break;
          case 'DELETE':
            final resp = await ApiService().delete(path);
            ok = ApiService.isSuccess(resp);
            break;
        }

        if (ok) {
          synced++;
        } else {
          failed++;
          remaining.add(op);
        }
      } catch (_) {
        failed++;
        remaining.add(op);
      }
    }

    // Garder seulement les ops qui ont échoué
    if (remaining.isEmpty) {
      await prefs.remove(_pendingOpsKey);
    } else {
      await prefs.setString(_pendingOpsKey, jsonEncode(remaining));
    }

    return SyncResult(success: failed == 0, synced: synced, failed: failed);
  }
}

class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  SyncResult({required this.success, required this.synced, required this.failed});
}
