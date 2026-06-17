// lib/core/services/client_api_service.dart
//
// Couche d'accès aux données clients — stratégie OFFLINE-FIRST.
//
// LECTURE  : SQLite local en priorité (affichage immédiat),
//            puis sync API en arrière-plan si serveur disponible.
// ÉCRITURE : SQLite local TOUJOURS + API si disponible (double écriture).
//
// Le client voit toujours ses données locales, même sans serveur.
// Quand le serveur répond, les données locales sont enrichies.

import '../../models/client_model.dart';
import 'api_service.dart';
import 'database_service.dart';

class ClientApiService {
  static final ClientApiService _instance = ClientApiService._internal();
  factory ClientApiService() => _instance;
  ClientApiService._internal();

  // ── Liste des clients — OFFLINE-FIRST ─────────────────────────────────

  Future<List<Client>> searchClients({
    String? query,
    ClientStatus? status,
    String? riskLevel,
    int page = 1,
    int limit = 100,
  }) async {
    // 1. Toujours lire SQLite local en premier
    final localClients = await DatabaseService().searchClients(
      query: query,
      status: status,
      riskLevel: riskLevel,
    );

    // 2. Si serveur disponible, tenter de récupérer les données distantes
    //    et fusionner avec les données locales
    if (await ApiService().isServerAvailable()) {
      try {
        final remoteClients = await _searchClientsApi(
          query: query,
          status: status,
          riskLevel: riskLevel,
          page: page,
          limit: limit,
        );

        if (remoteClients.isNotEmpty) {
          // Sync: enregistrer les clients distants en local s'ils n'existent pas
          await _syncRemoteToLocal(remoteClients);
          // Retourner la liste locale mise à jour
          return await DatabaseService().searchClients(
            query: query,
            status: status,
            riskLevel: riskLevel,
          );
        }
      } catch (_) {
        // Silencieux — on garde les données locales
      }
    }

    return localClients;
  }

  Future<List<Client>> _searchClientsApi({
    String? query,
    ClientStatus? status,
    String? riskLevel,
    int page = 1,
    int limit = 100,
  }) async {
    String path = '/clients?page=$page&limit=$limit';
    if (query != null && query.isNotEmpty) path += '&search=$query';
    if (status != null) path += '&status=${status.label}';
    if (riskLevel != null) path += '&risk_level=$riskLevel';

    final response = await ApiService().get(path);
    final data = ApiService.decodeResponse(response);
    if (data == null) return [];

    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Client.fromMap(_normalizeMap(e))).toList();
  }

  /// Sync données distantes → SQLite local
  Future<void> _syncRemoteToLocal(List<Client> remoteClients) async {
    for (final remote in remoteClients) {
      try {
        final existing = await DatabaseService().getClientById(remote.id ?? 0);
        if (existing == null) {
          await DatabaseService().insertClient(remote);
        }
        // On ne met pas à jour — le local est la source de vérité pour l'instant
      } catch (_) {}
    }
  }

  // ── Détail client ──────────────────────────────────────────────────────

  Future<Client?> getClientById(int id) async {
    // Toujours SQLite local en premier
    final local = await DatabaseService().getClientById(id);
    if (local != null) return local;

    // Fallback API si pas trouvé localement
    if (await ApiService().isServerAvailable()) {
      final response = await ApiService().get('/clients/$id');
      final data = ApiService.decodeResponse(response);
      if (data != null) return Client.fromMap(_normalizeMap(data));
    }
    return null;
  }

  // ── Créer un client — double écriture ─────────────────────────────────

  Future<int> insertClient(Client client) async {
    // 1. Écriture locale TOUJOURS (source de vérité)
    final localId = await DatabaseService().insertClient(client);

    // 2. Écriture API en parallèle si disponible
    if (await ApiService().isServerAvailable()) {
      try {
        await ApiService().post('/clients', client.toMap());
      } catch (_) {
        // Silencieux — sera re-synchonisé plus tard
      }
    }

    return localId;
  }

  // ── Modifier un client — double écriture ─────────────────────────────

  Future<void> updateClient(Client client) async {
    // 1. Local TOUJOURS
    await DatabaseService().updateClient(client);

    // 2. API si disponible
    if (await ApiService().isServerAvailable()) {
      try {
        await ApiService().put('/clients/${client.id}', client.toMap());
      } catch (_) {}
    }
  }

  // ── Supprimer un client — double écriture ────────────────────────────

  Future<void> deleteClient(int id) async {
    // 1. Local TOUJOURS
    await DatabaseService().deleteClient(id);

    // 2. API si disponible
    if (await ApiService().isServerAvailable()) {
      try {
        await ApiService().delete('/clients/$id');
      } catch (_) {}
    }
  }

  // ── Vérifier doublon — toujours local ────────────────────────────────

  Future<bool> isDuplicate({
    String? telephone,
    String? numeroCNI,
    int? excludeId,
  }) async {
    return await DatabaseService().isDuplicateClient(
      telephone: telephone,
      numeroCNI: numeroCNI,
      excludeId: excludeId,
    );
  }

  // ── Membres d'un groupe ───────────────────────────────────────────────

  Future<List<Client>> getGroupMembers(int groupeId) async {
    return await DatabaseService().getGroupMembers(groupeId);
  }

  // ── Normalisation champs API ──────────────────────────────────────────

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> map) {
    return {
      ...map,
      'numero_client': map['numero_client'] ?? 'NC',
      'nom': map['nom'] ?? 'Inconnu',
      'prenoms': map['prenoms'] ?? '',
      'statut': map['statut'] ?? 'Actif',
      'score_credit': map['score_credit'] ?? 50,
      'niveau_risque': map['niveau_risque'] ?? 'Moyen',
    };
  }
}
