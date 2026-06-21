// lib/core/services/products_api_service.dart
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

import '../../models/produit_financier_model.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

class ProductsApiService {
  static final ProductsApiService _instance = ProductsApiService._internal();
  factory ProductsApiService() => _instance;
  ProductsApiService._internal();

  // ── Liste des produits financiers ─────────────────────────────────────

  Future<List<ProduitFinancier>> getProducts() async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/produits');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final items =
              data is List ? data : (data['items'] as List? ?? [data]);
          final products = items
              .map((e) => ProduitFinancier.fromMap(e as Map<String, dynamic>))
              .toList();
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCache(products);
          return products;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    return await DatabaseService().getProduits();
  }

  // ── Détail d'un produit ───────────────────────────────────────────────

  Future<ProduitFinancier?> getProductById(int id) async {
    if (await SyncService().isOnline) {
      try {
        final response = await ApiService().get('/produits/$id');
        final data = ApiService.decodeResponse(response);
        if (data != null) {
          final product =
              ProduitFinancier.fromMap(data as Map<String, dynamic>);
          // Mise à jour du cache en arrière-plan (fire-and-forget)
          _updateLocalCache([product]);
          return product;
        }
      } catch (_) {
        // Fallback silencieux vers SQLite
      }
    }
    // OFFLINE ou fallback → SQLite local
    final all = await DatabaseService().getProduits();
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Créer un produit financier ────────────────────────────────────────

  Future<int> createProduct(ProduitFinancier produit) async {
    // 1. SQLite local TOUJOURS (réponse UI immédiate)
    final localId = await DatabaseService().insertProduitFinancier(produit);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().post('/produits', produit.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'POST',
          path: '/produits',
          body: produit.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'POST',
        path: '/produits',
        body: produit.toMap(),
      );
    }

    return localId;
  }

  // ── Mettre à jour un produit financier ───────────────────────────────

  Future<void> updateProduct(ProduitFinancier produit) async {
    // 1. SQLite local TOUJOURS — insertProduitFinancier utilise ConflictAlgorithm.replace
    await DatabaseService().insertProduitFinancier(produit);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().put('/produits/${produit.id}', produit.toMap());
      } catch (_) {
        await SyncService().queueOperation(
          method: 'PUT',
          path: '/produits/${produit.id}',
          body: produit.toMap(),
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'PUT',
        path: '/produits/${produit.id}',
        body: produit.toMap(),
      );
    }
  }

  // ── Supprimer un produit financier ────────────────────────────────────

  Future<void> deleteProduct(int id) async {
    // 1. SQLite local TOUJOURS
    await DatabaseService().deleteProduit(id);

    // 2. Serveur si disponible, sinon file de sync
    if (await SyncService().isOnline) {
      try {
        await ApiService().delete('/produits/$id');
      } catch (_) {
        await SyncService().queueOperation(
          method: 'DELETE',
          path: '/produits/$id',
          body: {},
        );
      }
    } else {
      await SyncService().queueOperation(
        method: 'DELETE',
        path: '/produits/$id',
        body: {},
      );
    }
  }

  // ── Cache local ───────────────────────────────────────────────────────

  /// Met à jour le cache SQLite avec les produits reçus du serveur.
  /// Appelée sans await (fire-and-forget) depuis les méthodes de lecture.
  Future<void> _updateLocalCache(List<ProduitFinancier> products) async {
    for (final product in products) {
      try {
        // insertProduitFinancier utilise ConflictAlgorithm.replace → upsert naturel
        await DatabaseService().insertProduitFinancier(product);
      } catch (_) {}
    }
  }
}
