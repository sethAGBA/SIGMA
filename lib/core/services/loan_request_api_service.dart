// lib/core/services/loan_request_api_service.dart
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

import '../../models/loan_model.dart';
import '../../models/loan_request_model.dart';
import '../../models/repayment_schedule_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class LoanRequestApiService {
  static final LoanRequestApiService _instance =
      LoanRequestApiService._internal();
  factory LoanRequestApiService() => _instance;
  LoanRequestApiService._internal();

  // ── Liste des demandes de prêt ────────────────────────────────────────

  /// Online  → GET /demandes-pret?statut={status} + cache fire-and-forget
  /// Offline → DatabaseService().getLoanRequests(status: status)
  Future<List<LoanRequest>> getLoanRequests({String? status}) async {
    if (await SyncService().isOnline) {
      try {
        final path =
            status != null ? '/demandes-pret?statut=$status' : '/demandes-pret';
        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? []);
          final requests = items
              .map((e) => LoanRequest.fromMap(e as Map<String, dynamic>))
              .toList();
          _updateLocalCacheLoanRequests(requests); // fire-and-forget
          return requests;
        }
      } catch (_) {
        // Fallback silencieux
      }
    }
    return DatabaseService().getLoanRequests(status: status);
  }

  // ── Créer une demande de prêt ─────────────────────────────────────────

  /// Écriture hybride : SQLite d'abord, puis API ou queue.
  /// Exception SQLite → propagée (ne pas appeler ApiService).
  /// Exception HTTP après SQLite réussi → queueOperation + retour succès.
  Future<int> createLoanRequest(LoanRequest r) async {
    // 1. SQLite local TOUJOURS — exception propagée si échec (Req 2.4)
    final localId = await DatabaseService().insertLoanRequest(r);

    // 2. Serveur si disponible, sinon file de sync (Req 2.5, 2.6)
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/demandes-pret', r.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/demandes-pret',
          body: r.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/demandes-pret',
        body: r.toMap(),
      );
    }

    return localId;
  }

  // ── Mettre à jour le statut d'une demande ────────────────────────────

  /// SQLite d'abord (update), puis PUT /demandes-pret/{id}/statut ou queue.
  /// Exception SQLite → propagée sans appel HTTP.
  Future<void> updateLoanRequestStatus(
    int id,
    LoanRequestStatus s, {
    String? motif,
  }) async {
    // 1. SQLite local TOUJOURS — exception propagée si échec (Req 2.7)
    await DatabaseService().updateLoanRequestStatus(id, s, motif: motif);

    // 2. Serveur si disponible, sinon file de sync (Req 2.8)
    final body = <String, dynamic>{
      'statut': s.name,
      if (motif != null) 'motif_rejet': motif,
    };
    if (await SyncService().isOnline) {
      try {
        await ApiService().put('/demandes-pret/$id/statut', body);
      } catch (_) {
        await SyncService().queueOperation(
          method: 'PUT',
          path: '/demandes-pret/$id/statut',
          body: body,
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'PUT',
        path: '/demandes-pret/$id/statut',
        body: body,
      );
    }
  }

  // ── Déblocage du prêt ─────────────────────────────────────────────────

  /// Transaction atomique SQLite (db.transaction()) pour Loan + N RepaymentSchedules.
  /// Si transaction échoue → exception propagée, aucune écriture partielle.
  /// Si transaction réussit :
  ///   Online  → POST /demandes-pret/{requestId}/debloquer
  ///   Offline → queueOperation
  Future<void> disburseLoan(
    int requestId,
    Loan loan,
    List<RepaymentSchedule> schedules,
  ) async {
    // 1. Transaction atomique SQLite — tout ou rien (Req 2.9, 2.12)
    final db = await DatabaseService().database;
    int loanId = 0;
    await db.transaction((txn) async {
      loanId = await txn.insert('prets', loan.toMap());
      for (final s in schedules) {
        // RepaymentSchedule n'a pas de copyWith — on construit la map manuellement
        final scheduleMap = {...s.toMap(), 'pret_id': loanId};
        await txn.insert('echeanciers', scheduleMap);
      }
      await txn.update(
        'demandes_pret',
        {'statut': LoanRequestStatus.debloquee.name},
        where: 'id = ?',
        whereArgs: [requestId],
      );
    }); // Si exception ici → SQLite annule tout automatiquement

    // 2. Sync serveur (Req 2.10, 2.11)
    final body = {'loan_id': loanId, 'request_id': requestId};
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/demandes-pret/$requestId/debloquer', body);
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/demandes-pret/$requestId/debloquer',
          body: body,
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/demandes-pret/$requestId/debloquer',
        body: body,
      );
    }
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les demandes reçues du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheLoanRequests(List<LoanRequest> items) async {
    for (final item in items) {
      try {
        // insertLoanRequest uses ConflictAlgorithm.replace — acts as upsert
        await DatabaseService().insertLoanRequest(item);
      } catch (_) {
        // Exception ignorée silencieusement
      }
    }
  }
}
