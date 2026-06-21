// lib/core/services/group_api_service.dart
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

import '../../models/groupe_solidaire_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class GroupApiService {
  static final GroupApiService _instance = GroupApiService._internal();
  factory GroupApiService() => _instance;
  GroupApiService._internal();

  // ── Liste des groupes ─────────────────────────────────────────────────

  Future<List<GroupeSolidaire>> getGroupes() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/groupes');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final groupes = items
              .map((e) =>
                  GroupeSolidaire.fromMap(e as Map<String, dynamic>))
              .toList();
          _updateLocalCache(groupes);
          return groupes;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return DatabaseService().getGroupes();
  }

  // ── Recherche de groupes ──────────────────────────────────────────────

  Future<List<GroupeSolidaire>> searchGroupes({
    String? query,
    GroupStatus? status,
  }) async {
    final all = await getGroupes();
    return all.where((g) {
      if (status != null && g.statut != status) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!g.nom.toLowerCase().contains(q) &&
            !g.code.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ── Détail d'un groupe ────────────────────────────────────────────────

  Future<GroupeSolidaire?> getGroupeById(int id) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/groupes/$id');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final groupe =
              GroupeSolidaire.fromMap(data as Map<String, dynamic>);
          _updateLocalCache([groupe]);
          return groupe;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return DatabaseService().getGroupeById(id);
  }

  // ── Créer un groupe ───────────────────────────────────────────────────

  Future<int> createGroupe(GroupeSolidaire groupe) async {
    final localId = await DatabaseService().insertGroupe(groupe);

    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/groupes', groupe.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/groupes',
          body: groupe.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/groupes',
        body: groupe.toMap(),
      );
    }

    return localId;
  }

  // ── Mettre à jour un groupe ───────────────────────────────────────────

  Future<void> updateGroupe(GroupeSolidaire groupe) async {
    await DatabaseService().updateGroupe(groupe);

    if (await SyncService().isOnline) {
      try {
        await ApiService().put('/groupes/${groupe.id}', groupe.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'PUT',
          path: '/groupes/${groupe.id}',
          body: groupe.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'PUT',
        path: '/groupes/${groupe.id}',
        body: groupe.toMap(),
      );
    }
  }

  // ── Cache local ───────────────────────────────────────────────────────

  Future<void> _updateLocalCache(List<GroupeSolidaire> groupes) async {
    for (final groupe in groupes) {
      try {
        await DatabaseService().insertGroupe(groupe);
      } catch (_) {}
    }
  }
}
