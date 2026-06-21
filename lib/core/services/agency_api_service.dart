// lib/core/services/agency_api_service.dart
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

import '../../models/agency_model.dart';
import '../../models/agent_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class AgencyApiService {
  static final AgencyApiService _instance = AgencyApiService._internal();
  factory AgencyApiService() => _instance;
  AgencyApiService._internal();

  // ── Liste des agences ─────────────────────────────────────────────────

  Future<List<Agency>> getAgencies() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/agencies');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final agencies = items
              .map((e) => Agency.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheAgencies(agencies);
          return agencies;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    return await DatabaseService().getAgencies();
  }

  // ── Détail d'une agence ───────────────────────────────────────────────

  Future<Agency?> getAgencyById(String id) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/agencies/$id');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final agency = Agency.fromMap(data as Map<String, dynamic>);
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheAgencies([agency]);
          return agency;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    return await DatabaseService().getAgencyById(id);
  }

  // ── Créer une agence ──────────────────────────────────────────────────

  Future<int> createAgency(Agency agency) async {
    // 1. SQLite local TOUJOURS (réponse UI immédiate)
    final localId = await DatabaseService().insertAgency(agency);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/agencies', agency.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/agencies',
          body: agency.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/agencies',
        body: agency.toMap(),
      );
    }

    return localId;
  }

  // ── Liste des agents ──────────────────────────────────────────────────
  //
  // [agencyId] optionnel : si fourni, filtre les agents de cette agence.

  Future<List<Agent>> getAgents({String? agencyId}) async {
    if (await SyncService().isOnline) {
      try {
        final path = agencyId != null
            ? '/agents?agency_id=$agencyId'
            : '/agents';
        final response = await ApiService().get(path);
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final agents = items
              .map((e) => Agent.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCacheAgents(agents);
          return agents;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    final allAgents = await DatabaseService().getAgents();
    if (agencyId != null) {
      return allAgents.where((a) => a.agencyId == agencyId).toList();
    }
    return allAgents;
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les agences reçues du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheAgencies(List<Agency> agencies) async {
    for (final agency in agencies) {
      try {
        final existing =
            await DatabaseService().getAgencyById(agency.id);
        if (existing == null) {
          await DatabaseService().insertAgency(agency);
        }
        // Pas d'upsert disponible — on laisse le cache existant si l'agence
        // est déjà présente pour éviter les conflits avec les opérations locales
      } catch (_) {}
    }
  }

  /// Met à jour le cache SQLite avec les agents reçus du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCacheAgents(List<Agent> agents) async {
    for (final agent in agents) {
      try {
        final existing =
            await DatabaseService().getAgentById(agent.id);
        if (existing == null) {
          await DatabaseService().insertAgent(agent);
        }
        // Pas d'upsert disponible — on laisse le cache existant si l'agent
        // est déjà présent pour éviter les conflits avec les opérations locales
      } catch (_) {}
    }
  }
}
