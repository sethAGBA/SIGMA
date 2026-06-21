// lib/core/services/cash_api_service.dart
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

import '../../models/cash_operation_model.dart';
import '../../models/cash_closing_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class CashApiService {
  static final CashApiService _instance = CashApiService._internal();
  factory CashApiService() => _instance;
  CashApiService._internal();

  // ── Liste des opérations de caisse (avec filtres locaux) ─────────────

  Future<List<Map<String, dynamic>>> getOperationsCaisse({
    String? type,
    String? agenceId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    if (await SyncService().isOnline) {
      try {
        final operations = await getOperations();
        final filtered = _filterOperations(
          operations,
          type: type,
          agenceId: agenceId,
          startDate: startDate,
          endDate: endDate,
          searchQuery: searchQuery,
        );
        final sliced = _applyLimitOffset(filtered, limit: limit, offset: offset);
        return sliced.map((o) => o.toMap()).toList();
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return DatabaseService().getOperationsCaisse(
      type: type,
      agenceId: agenceId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<CashClosing>> getCloturesFiltered({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (await SyncService().isOnline) {
      try {
        var clotures = await getClotures();
        if (startDate != null) {
          clotures = clotures
              .where((c) => !c.dateCloture.isBefore(startDate))
              .toList();
        }
        if (endDate != null) {
          final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          clotures = clotures.where((c) => !c.dateCloture.isAfter(end)).toList();
        }
        if (limit != null && clotures.length > limit) {
          clotures = clotures.sublist(0, limit);
        }
        return clotures;
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return DatabaseService().getCashClosings(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  List<CashOperation> _filterOperations(
    List<CashOperation> operations, {
    String? type,
    String? agenceId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    return operations.where((op) {
      if (type != null && op.type.value != type) return false;
      if (agenceId != null && op.agenceId != agenceId) return false;
      if (startDate != null && op.dateOperation.isBefore(startDate)) return false;
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (op.dateOperation.isAfter(end)) return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final ref = (op.referenceExterne ?? '').toLowerCase();
        final lib = op.libelle.toLowerCase();
        if (!ref.contains(q) && !lib.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<CashOperation> _applyLimitOffset(
    List<CashOperation> operations, {
    int? limit,
    int? offset,
  }) {
    var result = operations;
    if (offset != null && offset > 0) {
      if (offset >= result.length) return [];
      result = result.sublist(offset);
    }
    if (limit != null && result.length > limit) {
      result = result.sublist(0, limit);
    }
    return result;
  }

  // ── Liste des opérations de caisse ───────────────────────────────────

  Future<List<CashOperation>> getOperations() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/caisse/operations');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final operations = items
              .map((e) => CashOperation.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheOperations(operations);
          return operations;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    final rawMaps = await DatabaseService().getOperationsCaisse();
    return rawMaps
        .map((m) => CashOperation.fromMap(m))
        .toList();
  }

  // ── Solde de caisse ───────────────────────────────────────────────────

  Future<double> getSolde() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/caisse/solde');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          // Le serveur retourne un objet { "solde": <double> }
          if (data is Map<String, dynamic> && data.containsKey('solde')) {
            return (data['solde'] as num).toDouble();
          }
          if (data is num) {
            return data.toDouble();
          }
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → calcul depuis SQLite local
    return await DatabaseService().getCashBalance();
  }

  // ── Créer une opération de caisse ─────────────────────────────────────

  Future<int> createOperation(CashOperation op) async {
    // 1. SQLite local TOUJOURS (réponse UI immédiate)
    final localId =
        await DatabaseService().insertOperationCaisse(op.toMap());

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/caisse/operations', op.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/caisse/operations',
          body: op.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/caisse/operations',
        body: op.toMap(),
      );
    }

    return localId;
  }

  // ── Liste des clôtures de caisse ──────────────────────────────────────

  Future<List<CashClosing>> getClotures() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/caisse/clotures');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final clotures = items
              .map((e) => CashClosing.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheClotures(clotures);
          return clotures;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    return await DatabaseService().getCashClosings();
  }

  // ── Effectuer une clôture de caisse ───────────────────────────────────

  Future<int> clotureCaisse(CashClosing cloture) async {
    // 1. SQLite local TOUJOURS (réponse UI immédiate)
    final localId =
        await DatabaseService().insertCashClosing(cloture);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/caisse/clotures', cloture.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/caisse/clotures',
          body: cloture.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/caisse/clotures',
        body: cloture.toMap(),
      );
    }

    return localId;
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les opérations reçues du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheOperations(
      List<CashOperation> operations) async {
    for (final op in operations) {
      try {
        await DatabaseService().insertOperationCaisse(op.toMap());
      } catch (_) {
        // Conflit ignoré — le cache existant est préservé
      }
    }
  }

  /// Met à jour le cache SQLite avec les clôtures reçues du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheClotures(List<CashClosing> clotures) async {
    for (final cloture in clotures) {
      try {
        await DatabaseService().insertCashClosing(cloture);
      } catch (_) {
        // Conflit ignoré — le cache existant est préservé
      }
    }
  }
}
