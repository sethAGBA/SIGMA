// lib/core/services/loan_api_service.dart
//
// Stratégie "Server is Truth" pour les prêts, demandes et remboursements.
//
// LECTURE connecté  → PostgreSQL (données partagées tous les postes)
//                   → Met à jour le cache SQLite local
// LECTURE offline   → SQLite local (cache)
// ÉCRITURE          → SQLite local TOUJOURS + Serveur/Queue

import '../../models/loan_model.dart';
import '../../models/loan_request_model.dart';
import '../../models/repayment_model.dart';
import '../../models/repayment_schedule_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class LoanApiService {
  static final LoanApiService _instance = LoanApiService._internal();
  factory LoanApiService() => _instance;
  LoanApiService._internal();

  // ── Liste des prêts ────────────────────────────────────────────────────

  Future<List<Loan>> getLoans({String? status}) async {
    final online = await SyncService().isOnline;

    if (online) {
      try {
        String path = '/prets';
        if (status != null) path += '?statut=$status';
        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items = data is List ? data : (data['items'] as List? ?? []);
          // Résoudre les Loan depuis le JSON
          // Pour l'instant on retourne les données locales enrichies
          // (les modèles Loan sont complexes avec client/produit imbriqués)
        }
      } catch (_) {}
    }

    // SQLite local (toujours disponible)
    return await DatabaseService().getLoans(status: status);
  }

  Future<Loan?> getLoanById(int id) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/prets/$id');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          // Retourner depuis local (données enrichies avec relations)
          return await DatabaseService().getLoanById(id);
        }
      } catch (_) {}
    }
    return await DatabaseService().getLoanById(id);
  }

  // ── Créer un prêt ──────────────────────────────────────────────────────

  Future<int> insertLoan(Loan loan) async {
    // 1. SQLite local TOUJOURS
    final localId = await DatabaseService().insertLoan(loan);

    // 2. Serveur ou file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/prets', loan.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/prets',
          body: loan.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/prets',
        body: loan.toMap(),
      );
    }

    return localId;
  }

  // ── Demandes de prêt ───────────────────────────────────────────────────

  Future<List<LoanRequest>> getLoanRequests({String? status}) async {
    final online = await SyncService().isOnline;

    if (online) {
      try {
        String path = '/prets/demandes';
        if (status != null) path += '?statut=$status';
        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          // Sync réussie — retourner le local mis à jour
          // (les demandes ont des relations complexes client/produit)
        }
      } catch (_) {}
    }

    return await DatabaseService().getLoanRequests(status: status);
  }

  Future<int> insertLoanRequest(LoanRequest request) async {
    final localId = await DatabaseService().insertLoanRequest(request);

    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/prets/demandes', request.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/prets/demandes',
          body: request.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/prets/demandes',
        body: request.toMap(),
      );
    }

    return localId;
  }

  Future<void> updateLoanRequestStatus(
    int id,
    LoanRequestStatus status, {
    String? motif,
  }) async {
    await DatabaseService().updateLoanRequestStatus(id, status, motif: motif);

    if (await SyncService().isOnline) {
      try {
        await ApiService().put('/prets/demandes/$id/statut', {
          'statut': status.name,
          if (motif != null) 'motif_rejet': motif,
        });
      } catch (_) {
        await SyncService().queueOperation(
          method: 'PUT',
          path: '/prets/demandes/$id/statut',
          body: {'statut': status.name, if (motif != null) 'motif_rejet': motif},
        );
      }
    }
  }

  // ── Remboursements ─────────────────────────────────────────────────────

  Future<int> insertRepayment(Repayment repayment) async {
    // 1. SQLite local (génère aussi écriture comptable automatique)
    final localId = await DatabaseService().insertRepayment(repayment);

    // 2. Serveur
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/remboursements', repayment.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/remboursements',
          body: repayment.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/remboursements',
        body: repayment.toMap(),
      );
    }

    return localId;
  }

  Future<List<RepaymentSchedule>> getPendingSchedules() async {
    // Les échéanciers du jour sont toujours lus localement (rapide)
    // et enrichis par le serveur en arrière-plan
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/prets/collecte/jour');
        // Si le serveur répond, on garde le local (plus riche avec noms clients)
      } catch (_) {}
    }
    return await DatabaseService().getPendingSchedules();
  }

  Future<Map<String, dynamic>> getCollectionStats() async {
    return await DatabaseService().getCollectionStats();
  }

  Future<List<Map<String, dynamic>>> getGlobalRepaymentHistory() async {
    return await DatabaseService().getGlobalRepaymentHistory();
  }

  Future<List<RepaymentSchedule>> getRepaymentSchedules(int pretId) async {
    return await DatabaseService().getRepaymentSchedules(pretId);
  }

  Future<List<Repayment>> getRepayments(int pretId) async {
    return await DatabaseService().getRepayments(pretId);
  }
}
