// lib/core/services/savings_api_service.dart
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

import '../../models/savings_account_model.dart';
import '../../models/savings_transaction_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class SavingsApiService {
  static final SavingsApiService _instance = SavingsApiService._internal();
  factory SavingsApiService() => _instance;
  SavingsApiService._internal();

  // ── Liste des comptes épargne ─────────────────────────────────────────

  Future<List<SavingsAccount>> getComptes() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/epargne/comptes');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final comptes =
              items.map((e) => SavingsAccount.fromMap(e as Map<String, dynamic>)).toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheComptes(comptes);
          return comptes;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    return await DatabaseService().getSavingsAccounts();
  }

  // ── Détail d'un compte ────────────────────────────────────────────────

  Future<SavingsAccount?> getCompteById(int id) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/epargne/comptes/$id');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final compte =
              SavingsAccount.fromMap(data as Map<String, dynamic>);
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheComptes([compte]);
          return compte;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return await DatabaseService().getSavingsAccountById(id);
  }

  // ── Ouvrir un compte épargne ──────────────────────────────────────────

  Future<int> ouvrirCompte(SavingsAccount compte) async {
    // 1. SQLite local TOUJOURS (réponse UI immédiate)
    final localId = await DatabaseService().insertSavingsAccount(compte);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/epargne/comptes', compte.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/epargne/comptes',
          body: compte.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/epargne/comptes',
        body: compte.toMap(),
      );
    }

    return localId;
  }

  // ── Effectuer une transaction ─────────────────────────────────────────

  Future<void> effectuerTransaction(SavingsTransaction tx) async {
    // 1. SQLite local TOUJOURS (met à jour le solde et créé l'écriture comptable)
    await DatabaseService().insertSavingsTransaction(tx);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/epargne/transactions', tx.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/epargne/transactions',
          body: tx.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/epargne/transactions',
        body: tx.toMap(),
      );
    }
  }

  // ── Transactions d'un compte ──────────────────────────────────────────

  Future<List<SavingsTransaction>> getTransactions(int compteId) async {
    if (await SyncService().isOnline) {
      try {
        final response =
            await ApiService().get('/epargne/transactions?compte_id=$compteId');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final transactions = items
              .map((e) => SavingsTransaction.fromMap(e as Map<String, dynamic>))
              .toList();
          // Pas de cache dédié pour les transactions — SQLite est déjà la source
          return transactions;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return await DatabaseService().getSavingsTransactions(compteId);
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les comptes reçus du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheComptes(List<SavingsAccount> comptes) async {
    for (final compte in comptes) {
      try {
        final existing =
            await DatabaseService().getSavingsAccountById(compte.id ?? 0);
        if (existing == null) {
          await DatabaseService().insertSavingsAccount(compte);
        }
        // Pas d'upsert disponible — on laisse le cache existant si le compte
        // est déjà présent pour éviter les conflits avec les opérations locales
      } catch (_) {}
    }
  }
}
