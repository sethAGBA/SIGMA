// lib/core/services/accounting_api_service.dart
//
// Stratégie "Server is Truth" :
//
// LECTURE connecté  → PostgreSQL (données partagées tous les postes)
//                   → Met à jour le cache SQLite local (fire-and-forget)
// LECTURE offline   → SQLite local (cache via AccountingService / DatabaseService)
//
// ÉCRITURE          → SQLite local TOUJOURS (réponse UI immédiate)
//                   → Serveur si disponible
//                   → Sinon → file de sync (SyncService)

import 'package:sqflite/sqflite.dart';

import '../../models/accounting_account_model.dart';
import '../../models/ecriture_comptable_model.dart';
import '../../models/journal_model.dart';
import '../../models/trial_balance_model.dart';
import 'accounting_service.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class AccountingApiService {
  static final AccountingApiService _instance =
      AccountingApiService._internal();
  factory AccountingApiService() => _instance;
  AccountingApiService._internal();

  // ── Plan comptable (comptes) ──────────────────────────────────────────

  Future<List<AccountingAccount>> getComptes() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/comptabilite/comptes');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final comptes = items
              .map((e) =>
                  AccountingAccount.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheComptes(comptes);
          return comptes;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local via AccountingService
    return await AccountingService().getAccountingAccounts();
  }

  // ── Journaux comptables ───────────────────────────────────────────────

  Future<List<Journal>> getJournaux() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/comptabilite/journaux');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final journaux = items
              .map((e) => Journal.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheJournaux(journaux);
          return journaux;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    return await AccountingService().getJournaux();
  }

  // ── Écritures comptables ──────────────────────────────────────────────

  /// [from] et [to] filtrent par date comptable (inclusif).
  Future<List<EcritureComptable>> getEcritures({
    DateTime? from,
    DateTime? to,
  }) async {
    if (await SyncService().isOnline) {
      try {
        // Construire les query params de date
        final queryParams = <String>[];
        if (from != null) {
          queryParams.add('from=${Uri.encodeComponent(from.toIso8601String())}');
        }
        if (to != null) {
          queryParams.add('to=${Uri.encodeComponent(to.toIso8601String())}');
        }
        final path = queryParams.isEmpty
            ? '/comptabilite/ecritures'
            : '/comptabilite/ecritures?${queryParams.join('&')}';

        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final ecritures = items
              .map((e) =>
                  EcritureComptable.fromMap(e as Map<String, dynamic>))
              .toList();
          // Pas de cache dédié pour la liste filtrée — AccountingService est
          // déjà la source locale canonique
          return ecritures;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local via AccountingService
    // AccountingService.createEcriture stocke les écritures localement ;
    // on relit la DB directement depuis DatabaseService pour avoir le filtre date.
    return await _getEcrituresLocales(from: from, to: to);
  }

  // ── Créer une écriture comptable ──────────────────────────────────────

  /// [lignes] est requis pour l'équilibre débit/crédit.
  /// Si [lignes] est omis ou vide, l'écriture est insérée sans lignes
  /// (utile pour des syncs partiels depuis le serveur).
  Future<void> createEcriture(
    EcritureComptable ecriture, {
    List<LigneEcriture> lignes = const [],
  }) async {
    // 1. SQLite local TOUJOURS (réponse UI immédiate)
    await AccountingService().createEcriture(ecriture, lignes);

    // 2. Serveur si disponible, sinon file de sync
    final payload = {
      ...ecriture.toMap(),
      'lignes': lignes.map((l) => l.toMap()).toList(),
    };

    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/comptabilite/ecritures', payload);
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/comptabilite/ecritures',
          body: payload,
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/comptabilite/ecritures',
        body: payload,
      );
    }
  }

  // ── Balance générale ──────────────────────────────────────────────────

  Future<TrialBalance> getBalance({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    if (await SyncService().isOnline) {
      try {
        final queryParams = <String>[];
        if (dateDebut != null) {
          queryParams.add(
            'from=${Uri.encodeComponent(dateDebut.toIso8601String())}',
          );
        }
        if (dateFin != null) {
          queryParams.add(
            'to=${Uri.encodeComponent(dateFin.toIso8601String())}',
          );
        }
        final path = queryParams.isEmpty
            ? '/comptabilite/balance'
            : '/comptabilite/balance?${queryParams.join('&')}';

        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null && data is Map<String, dynamic>) {
          // Le serveur retourne { entries: [...], totalDebits, totalCredits,
          // totalSoldesDebiteurs, totalSoldesCrediteurs }
          final rawEntries = data['entries'] as List? ?? [];
          final entries = rawEntries
              .map((e) =>
                  TrialBalanceEntry.fromMap(e as Map<String, dynamic>))
              .toList();
          return TrialBalance(
            entries: entries,
            totalDebits: (data['totalDebits'] as num?)?.toDouble() ?? 0.0,
            totalCredits: (data['totalCredits'] as num?)?.toDouble() ?? 0.0,
            totalSoldesDebiteurs:
                (data['totalSoldesDebiteurs'] as num?)?.toDouble() ?? 0.0,
            totalSoldesCrediteurs:
                (data['totalSoldesCrediteurs'] as num?)?.toDouble() ?? 0.0,
          );
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → calcul depuis SQLite local
    return await DatabaseService().getTrialBalance(
      dateDebut: dateDebut,
      dateFin: dateFin,
    );
  }

  // ── Helpers privés ────────────────────────────────────────────────────

  /// Lit les écritures depuis SQLite avec filtre optionnel de date.
  Future<List<EcritureComptable>> _getEcrituresLocales({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await DatabaseService().database;

    final where = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      where.add('date_comptable >= ?');
      args.add(from.toIso8601String().split('T')[0]);
    }
    if (to != null) {
      where.add('date_comptable <= ?');
      args.add(to.toIso8601String().split('T')[0]);
    }

    final maps = await db.query(
      'ecritures',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_comptable ASC',
    );

    return maps
        .map((m) => EcritureComptable.fromMap(m))
        .toList();
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les comptes reçus du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheComptes(
      List<AccountingAccount> comptes) async {
    for (final compte in comptes) {
      try {
        await AccountingService().addAccount(compte);
      } catch (_) {
        // Compte déjà présent ou conflit — cache existant préservé
      }
    }
  }

  /// Met à jour le cache SQLite avec les journaux reçus du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheJournaux(List<Journal> journaux) async {
    final db = await DatabaseService().database;
    for (final journal in journaux) {
      try {
        await db.insert(
          'journaux',
          journal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (_) {
        // Conflit ignoré — le cache existant est préservé
      }
    }
  }
}
