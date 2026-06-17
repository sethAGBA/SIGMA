// lib/core/services/client_api_service.dart
//
// Couche d'accès aux données clients — hybride API/SQLite.
// Utilise l'API FastAPI si disponible, sinon SQLite local.

import '../../models/client_model.dart';
import 'api_service.dart';
import 'database_service.dart';

class ClientApiService {
  static final ClientApiService _instance = ClientApiService._internal();
  factory ClientApiService() => _instance;
  ClientApiService._internal();

  // ── Liste des clients ──────────────────────────────────────────────────

  Future<List<Client>> searchClients({
    String? query,
    ClientStatus? status,
    String? riskLevel,
    int page = 1,
    int limit = 100,
  }) async {
    if (await ApiService().isServerAvailable()) {
      return await _searchClientsApi(
        query: query,
        status: status,
        riskLevel: riskLevel,
        page: page,
        limit: limit,
      );
    }
    return await DatabaseService().searchClients(
      query: query,
      status: status,
      riskLevel: riskLevel,
    );
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
    return items.map((e) => Client.fromMap(_convertApiMap(e))).toList();
  }

  // ── Détail client ──────────────────────────────────────────────────────

  Future<Client?> getClientById(int id) async {
    if (await ApiService().isServerAvailable()) {
      final response = await ApiService().get('/clients/$id');
      final data = ApiService.decodeResponse(response);
      if (data == null) return null;
      return Client.fromMap(_convertApiMap(data));
    }
    return await DatabaseService().getClientById(id);
  }

  // ── Créer un client ────────────────────────────────────────────────────

  Future<int> insertClient(Client client) async {
    if (await ApiService().isServerAvailable()) {
      final response = await ApiService().post('/clients', client.toMap());
      final data = ApiService.decodeResponse(response);
      if (data != null) return data['id'] as int? ?? 0;
    }
    // Fallback SQLite
    return await DatabaseService().insertClient(client);
  }

  // ── Modifier un client ────────────────────────────────────────────────

  Future<void> updateClient(Client client) async {
    if (await ApiService().isServerAvailable()) {
      await ApiService().put('/clients/${client.id}', client.toMap());
      return;
    }
    await DatabaseService().updateClient(client);
  }

  // ── Supprimer un client ───────────────────────────────────────────────

  Future<void> deleteClient(int id) async {
    if (await ApiService().isServerAvailable()) {
      await ApiService().delete('/clients/$id');
      return;
    }
    await DatabaseService().deleteClient(id);
  }

  // ── Vérifier doublon ──────────────────────────────────────────────────

  Future<bool> isDuplicate({
    String? telephone,
    String? numeroCNI,
    int? excludeId,
  }) async {
    // Toujours vérifier en SQLite local (plus rapide pour la validation UI)
    return await DatabaseService().isDuplicateClient(
      telephone: telephone,
      numeroCNI: numeroCNI,
      excludeId: excludeId,
    );
  }

  // ── Membres d'un groupe ───────────────────────────────────────────────

  Future<List<Client>> getGroupMembers(int groupeId) async {
    if (await ApiService().isServerAvailable()) {
      final response = await ApiService().get('/clients?groupe_id=$groupeId');
      final data = ApiService.decodeResponse(response);
      if (data != null) {
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((e) => Client.fromMap(_convertApiMap(e))).toList();
      }
    }
    return await DatabaseService().getGroupMembers(groupeId);
  }

  // ── Conversion champs API → format SQLite Flutter ─────────────────────

  Map<String, dynamic> _convertApiMap(Map<String, dynamic> apiMap) {
    // L'API retourne des clés snake_case compatibles avec SQLite
    // On s'assure juste que les champs obligatoires sont présents
    return {
      ...apiMap,
      'numero_client': apiMap['numero_client'] ?? 'NC',
      'nom': apiMap['nom'] ?? 'Inconnu',
      'prenoms': apiMap['prenoms'] ?? '',
      'statut': apiMap['statut'] ?? 'Actif',
      'score_credit': apiMap['score_credit'] ?? 50,
      'niveau_risque': apiMap['niveau_risque'] ?? 'Moyen',
    };
  }
}
