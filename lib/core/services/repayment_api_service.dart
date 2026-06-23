// lib/core/services/repayment_api_service.dart
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

import 'package:flutter/foundation.dart';

import '../../models/repayment_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../models/repayment_list_result.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class RepaymentApiService {
  static final RepaymentApiService _instance = RepaymentApiService._internal();
  factory RepaymentApiService() => _instance;
  RepaymentApiService._internal();

  // Getters privés pour faciliter les tests (injection de dépendances)
  // ignore: unused_element
  ApiService get _api => ApiService();
  // ignore: unused_element
  DatabaseService get _db => DatabaseService();
  // ignore: unused_element
  SyncService get _sync => SyncService();

  // ── Échéances en attente ──────────────────────────────────────────────

  /// Retourne les échéances en retard/dues aujourd'hui.
  /// Online  → GET /prets/collecte/jour + cache fire-and-forget
  /// Offline → DatabaseService().getPendingSchedules(retardOnly: retardOnly)
  /// Cache vide en offline → RepaymentListResult(items: [], isIncomplete: true)
  Future<RepaymentListResult> getPendingSchedules({bool retardOnly = false}) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/prets/collecte/jour');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items = (data is List ? data : (data['items'] as List? ?? []));
          final schedules = items
              .map((e) => RepaymentSchedule.fromMap(e as Map<String, dynamic>))
              .toList();
          _updateLocalCacheSchedules(schedules); // fire-and-forget
          return RepaymentListResult(items: schedules, isIncomplete: false);
        }
      } catch (e) {
        debugPrint('RepaymentApiService.getPendingSchedules: $e');
      }
    }
    final local =
        await DatabaseService().getPendingSchedules(retardOnly: retardOnly);
    return RepaymentListResult(items: local, isIncomplete: local.isEmpty);
  }

  // ── Remboursements d'un prêt ──────────────────────────────────────────

  /// Online  → GET /remboursements?pret_id={pretId} + cache fire-and-forget
  /// Offline → DatabaseService().getRepayments(pretId)
  Future<List<Repayment>> getRepayments(int pretId) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/remboursements?pret_id=$pretId');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items = data is List ? data : (data['items'] as List? ?? [data]);
          final repayments = items
              .map((e) => Repayment.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheRepayments(repayments);
          return repayments;
        }
      } catch (e) {
        debugPrint('[RepaymentApiService.getRepayments] erreur API : $e');
      }
    }
    // OFFLINE ou fallback → SQLite local
    return await DatabaseService().getRepayments(pretId);
  }

  // ── Historique global ─────────────────────────────────────────────────

  /// Online  → GET /remboursements/history
  /// Offline → DatabaseService().getGlobalRepaymentHistory()
  /// Cache vide en offline → liste vide sans exception
  Future<List<Map<String, dynamic>>> getGlobalHistory() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/remboursements/history');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items = data is List ? data : (data['items'] as List? ?? [data]);
          return items.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('[RepaymentApiService.getGlobalHistory] erreur API : $e');
      }
    }
    // OFFLINE ou fallback → SQLite local ; cache vide → liste vide (pas d'exception)
    return await DatabaseService().getGlobalRepaymentHistory();
  }

  // ── Insérer un remboursement ──────────────────────────────────────────

  /// Écriture hybride : SQLite d'abord, puis API ou queue.
  /// Exception SQLite → propagée (ne pas appeler ApiService).
  /// Exception HTTP après SQLite réussi → queueOperation + retour succès.
  Future<int> insertRepayment(Repayment r) async {
    // 1. SQLite TOUJOURS — exception propagée si échec (Req 1.7)
    final localId = await DatabaseService().insertRepayment(r);

    // 2. Serveur si disponible, sinon file de sync (Req 1.8, 1.9, 1.10)
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/remboursements', r.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/remboursements',
          body: r.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/remboursements',
        body: r.toMap(),
      );
    }
    return localId;
  }

  // ── Statistiques de collecte ──────────────────────────────────────────

  /// Toujours local — jamais d'appel HTTP, quel que soit isOnline.
  Future<Map<String, dynamic>> getCollectionStats() async {
    return DatabaseService().getCollectionStats();
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les échéances reçues du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  // ignore: unused_element
  Future<void> _updateLocalCacheSchedules(List<RepaymentSchedule> items) async {
    for (final schedule in items) {
      try {
        await DatabaseService().insertRepaymentSchedule(schedule);
        // Pas d'upsert disponible — on tente l'insertion ; échec silencieux
        // si l'échéance est déjà présente (contrainte UNIQUE ou clé primaire)
      } catch (_) {
        // Exceptions ignorées silencieusement — fire-and-forget
      }
    }
  }

  /// Met à jour le cache SQLite avec les remboursements reçus du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  // ignore: unused_element
  Future<void> _updateLocalCacheRepayments(List<Repayment> items) async {
    for (final repayment in items) {
      try {
        await DatabaseService().insertRepayment(repayment);
      } catch (_) {
        // Exception ignorée silencieusement — ne doit pas affecter la valeur de retour
      }
    }
  }
}
