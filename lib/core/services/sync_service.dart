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
//   → Si pas disponible → file de sync en attente (table sync_queue)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'database_service.dart';
import '../../models/sync_queue_entry.dart';
import '../../models/sync_conflict_model.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // ── Vérification disponibilité ────────────────────────────────────────

  Future<bool> get isOnline => ApiService().isServerAvailable();

  // ── Priorité selon le chemin ──────────────────────────────────────────

  /// Retourne la priorité d'une opération en fonction du chemin d'API.
  /// 1 = haute priorité, 5 = basse priorité.
  int _priorityFromPath(String path) {
    if (path.contains('/remboursements')) return 1;
    if (path.contains('/caisse')) return 2;
    if (path.contains('/prets')) return 3;
    if (path.contains('/clients') || path.contains('/groupes')) return 4;
    return 5;
  }

  // ── File d'attente de sync ────────────────────────────────────────────

  /// Ajoute une opération dans la table sync_queue.
  Future<void> queueOperation({
    required String method, // POST, PUT, DELETE
    required String path, // ex: /clients/42
    Map<String, dynamic>? body,
    int? priority,
  }) async {
    final now = DateTime.now();
    final entry = SyncQueueEntry(
      id: SyncQueueEntry.generateId(method, path),
      method: method,
      path: path,
      body: body,
      status: 'pending',
      priority: priority ?? _priorityFromPath(path),
      createdAt: now,
      updatedAt: now,
      attemptCount: 0,
    );
    await DatabaseService().insertSyncQueueEntry(entry);
  }

  /// Retourne le nombre d'opérations en statut 'pending' ou 'in_progress'.
  Future<int> getPendingCount() async {
    return DatabaseService().countPendingSyncEntries();
  }

  /// Retourne toutes les entrées de la file (pending, in_progress, failed, conflict),
  /// triées par priorité ASC puis created_at ASC.
  Future<List<SyncQueueEntry>> getAllEntries() async {
    return DatabaseService().getAllSyncEntries();
  }

  Future<List<SyncConflict>> getPendingConflicts() async {
    return DatabaseService().getPendingSyncConflicts();
  }

  Future<void> resolveConflict(String conflictId, {required bool keepLocal}) async {
    final conflicts = await DatabaseService().getPendingSyncConflicts();
    final conflict = conflicts.firstWhere(
      (c) => c.id == conflictId,
      orElse: () => throw StateError('SyncConflict $conflictId introuvable'),
    );

    final entries = await DatabaseService().getAllSyncEntries();
    SyncQueueEntry? entry;
    for (final e in entries) {
      if (e.id == conflict.syncQueueId) {
        entry = e;
        break;
      }
    }

    if (keepLocal && entry != null) {
      http.Response? response;
      switch (entry.method) {
        case 'POST':
          response = await ApiService().post(entry.path, entry.body ?? {});
          break;
        case 'PUT':
          response = await ApiService().put(entry.path, entry.body ?? {});
          break;
        default:
          break;
      }
      if (ApiService.isSuccess(response)) {
        await DatabaseService().updateSyncQueueEntry(
          entry.copyWith(status: 'success', updatedAt: DateTime.now()),
        );
      }
    } else if (!keepLocal) {
      // Server wins — marquer la file comme success (cache mis à jour manuellement si besoin)
      if (entry != null) {
        await DatabaseService().updateSyncQueueEntry(
          entry.copyWith(status: 'success', updatedAt: DateTime.now()),
        );
      }
    }

    await DatabaseService().updateSyncConflict(
      conflict.copyWith(
        resolution: keepLocal ? 'keep_local' : 'keep_server',
      ),
    );
  }

  /// Supprime une entrée de la file par son identifiant.
  Future<void> deleteEntry(String id) async {
    await DatabaseService().deleteSyncQueueEntry(id);
  }

  /// Remet une entrée en statut 'pending' avec attempt_count remis à 0.
  Future<void> retryEntry(String id) async {
    final entries = await DatabaseService().getAllSyncEntries();
    final entry = entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('SyncQueueEntry $id introuvable'),
    );
    final updated = entry.copyWith(
      status: 'pending',
      attemptCount: 0,
      updatedAt: DateTime.now(),
      clearLastError: true,
    );
    await DatabaseService().updateSyncQueueEntry(updated);
  }

  // ── Flush ─────────────────────────────────────────────────────────────

  /// Envoie toutes les opérations en attente au serveur.
  /// À appeler au démarrage de l'app ou quand la connexion revient.
  ///
  /// Logique d'escalade des erreurs :
  ///   - Succès 2xx   → status='success'
  ///   - Erreur 4xx   → status='failed' immédiatement (requête invalide, pas de retry)
  ///   - Erreur 5xx / timeout / null → attempts++ ; si >= 3 → 'failed', sinon 'pending'
  ///   - Exception Dart → même traitement que 5xx
  Future<SyncResult> flushPendingOperations() async {
    if (!await isOnline) {
      return SyncResult(success: false, synced: 0, failed: 0);
    }

    final pending = await DatabaseService().getPendingSyncEntries();
    if (pending.isEmpty) {
      return SyncResult(success: true, synced: 0, failed: 0);
    }

    int synced = 0;
    int failed = 0;
    const int maxAttempts = 3;

    for (final entry in pending) {
      // a. Marquer en cours
      await DatabaseService().updateSyncQueueEntry(
        entry.copyWith(status: 'in_progress', updatedAt: DateTime.now()),
      );

      try {
        // b. Appeler l'API selon la méthode HTTP
        http.Response? response;
        switch (entry.method) {
          case 'POST':
            response = await ApiService().post(entry.path, entry.body ?? {});
            break;
          case 'PUT':
            response = await ApiService().put(entry.path, entry.body ?? {});
            break;
          case 'DELETE':
            response = await ApiService().delete(entry.path);
            break;
          default:
            // Méthode inconnue → traiter comme erreur immédiate
            response = null;
        }

        if (ApiService.isSuccess(response)) {
          // c. Succès 2xx → marquer success
          await DatabaseService().updateSyncQueueEntry(
            entry.copyWith(status: 'success', updatedAt: DateTime.now()),
          );
          synced++;
        } else if (response != null && response.statusCode == 409) {
          final conflict = _buildConflictFromResponse(entry, response);
          await DatabaseService().insertSyncConflict(conflict);
          await DatabaseService().updateSyncQueueEntry(
            entry.copyWith(
              status: 'conflict',
              updatedAt: DateTime.now(),
              lastError: response.body,
            ),
          );

          if (_shouldAutoResolveKeepLocal(conflict)) {
            await resolveConflict(conflict.id, keepLocal: true);
            synced++;
          } else {
            failed++;
          }
        } else if (response != null &&
            response.statusCode >= 400 &&
            response.statusCode < 500) {
          // d. Erreur 4xx → failed immédiatement, pas de retry
          await DatabaseService().updateSyncQueueEntry(
            entry.copyWith(
              status: 'failed',
              attemptCount: maxAttempts,
              updatedAt: DateTime.now(),
              lastError: response.body,
            ),
          );
          failed++;
        } else {
          // e. Erreur 5xx ou réponse null (timeout / réseau) → escalade progressive
          final newAttempts = entry.attemptCount + 1;
          final errorMsg = response != null
              ? 'Erreur serveur ${response.statusCode}: ${response.body}'
              : 'Aucune réponse du serveur (timeout ou réseau)';

          if (newAttempts >= maxAttempts) {
            await DatabaseService().updateSyncQueueEntry(
              entry.copyWith(
                status: 'failed',
                attemptCount: maxAttempts,
                updatedAt: DateTime.now(),
                lastError: errorMsg,
              ),
            );
            failed++;
          } else {
            // Remettre en pending pour le prochain flush
            await DatabaseService().updateSyncQueueEntry(
              entry.copyWith(
                status: 'pending',
                attemptCount: newAttempts,
                updatedAt: DateTime.now(),
                lastError: errorMsg,
              ),
            );
          }
        }
      } catch (e) {
        // f. Exception Dart (SocketException, TimeoutException, etc.)
        // → même traitement que erreur 5xx
        final newAttempts = entry.attemptCount + 1;
        final errorMsg = e.toString();

        if (newAttempts >= maxAttempts) {
          await DatabaseService().updateSyncQueueEntry(
            entry.copyWith(
              status: 'failed',
              attemptCount: maxAttempts,
              updatedAt: DateTime.now(),
              lastError: errorMsg,
            ),
          );
          failed++;
        } else {
          await DatabaseService().updateSyncQueueEntry(
            entry.copyWith(
              status: 'pending',
              attemptCount: newAttempts,
              updatedAt: DateTime.now(),
              lastError: errorMsg,
            ),
          );
        }
      }
    }

    return SyncResult(success: failed == 0, synced: synced, failed: failed);
  }

  SyncConflict _buildConflictFromResponse(
    SyncQueueEntry entry,
    http.Response response,
  ) {
    Map<String, dynamic> serverPayload = {};
    DateTime? serverUpdatedAt;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        serverPayload = Map<String, dynamic>.from(
          (decoded['server_payload'] as Map<String, dynamic>?) ?? decoded,
        );
        final rawDate = decoded['server_updated_at'] as String?;
        if (rawDate != null) serverUpdatedAt = DateTime.tryParse(rawDate);
      }
    } catch (_) {}

    final localUpdatedRaw = entry.body?['date_modification'] ??
        entry.body?['updated_at'] ??
        entry.updatedAt.toIso8601String();

    return SyncConflict(
      id: 'conflict-${entry.id}',
      syncQueueId: entry.id,
      entityType: _entityTypeFromPath(entry.path),
      entityId: _entityIdFromPath(entry.path),
      localPayload: entry.body ?? {},
      serverPayload: serverPayload,
      localUpdatedAt: DateTime.tryParse(localUpdatedRaw.toString()) ??
          entry.updatedAt,
      serverUpdatedAt: serverUpdatedAt,
      createdAt: DateTime.now(),
    );
  }

  String _entityTypeFromPath(String path) {
    if (path.contains('/remboursements')) return 'remboursement';
    if (path.contains('/clients')) return 'client';
    return 'autre';
  }

  String? _entityIdFromPath(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final last = parts.last;
    return int.tryParse(last) != null ? last : null;
  }

  bool _shouldAutoResolveKeepLocal(SyncConflict conflict) {
    final local = conflict.localUpdatedAt;
    final server = conflict.serverUpdatedAt;
    if (local == null || server == null) return false;
    return local.isAfter(server);
  }
}

class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  SyncResult({
    required this.success,
    required this.synced,
    required this.failed,
  });
}
