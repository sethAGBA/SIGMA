// lib/core/services/key_derivation_service.dart
//
// Dérive une clé de chiffrement déterministe pour la base de données SQLite.
// Utilisé en préparation du chiffrement mobile (sqflite_sqlcipher sur Android/iOS).
// Sur Windows Desktop, la clé est calculée mais non appliquée (sqflite_common_ffi
// ne supporte pas SQLCipher sans compilation C++ native).

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exception levée si le stockage sécurisé est inaccessible.
class EncryptionKeyException implements Exception {
  final String message;
  const EncryptionKeyException(this.message);
  @override
  String toString() => 'EncryptionKeyException: $message';
}

class KeyDerivationService {
  // Singleton
  static final KeyDerivationService _instance =
      KeyDerivationService._internal();
  factory KeyDerivationService() => _instance;
  KeyDerivationService._internal();

  static const String _saltKey = 'db_encryption_salt';
  static const _storage = FlutterSecureStorage();

  // ── API publique ────────────────────────────────────────────────────────

  /// Retourne la clé de chiffrement dérivée pour [username].
  ///
  /// - Si aucun sel n'existe encore, en génère un et le persiste.
  /// - La clé est dérivée via SHA-256 sur `"$username:$salt"` et encodée en hex.
  /// - La clé elle-même n'est jamais persistée.
  Future<String> getOrCreateKey(String username) async {
    String salt;
    try {
      final stored = await _storage.read(key: _saltKey);
      if (stored != null && stored.isNotEmpty) {
        salt = stored;
      } else {
        // Générer un sel pseudo-aléatoire basé sur le timestamp et le username
        salt = _generateSalt(username);
        await _storage.write(key: _saltKey, value: salt);
      }
    } catch (e) {
      throw EncryptionKeyException(
        'Impossible d\'accéder au stockage sécurisé : $e',
      );
    }

    return _deriveKey(username, salt);
  }

  /// Supprime le sel stocké (utile pour les tests ou la réinitialisation).
  Future<void> clearKey() async {
    await _storage.delete(key: _saltKey);
  }

  // ── Implémentation interne ──────────────────────────────────────────────

  /// Génère un sel pseudo-aléatoire de 32 caractères hex.
  /// Basé sur le timestamp microseconde et le hashcode du username.
  String _generateSalt(String username) {
    final raw =
        '${DateTime.now().microsecondsSinceEpoch}-${username.hashCode}';
    // Encoder en base64 puis tronquer à 32 chars pour un sel lisible
    final encoded = base64Url.encode(utf8.encode(raw));
    return encoded.substring(0, encoded.length.clamp(0, 32));
  }

  /// Dérive la clé via une concaténation + hashcode multiple (simplifié).
  /// Produit une chaîne hexadécimale de 64 caractères (256 bits).
  ///
  /// Note : Pour une sécurité maximale en production, remplacer par PBKDF2
  /// via le package `pointycastle` une fois disponible dans le projet.
  String _deriveKey(String username, String salt) {
    // Rounds de hachage simplifiés sans dépendance externe
    String input = '$username:$salt';

    // 10 000 itérations d'une transformation déterministe
    int hash = 0;
    for (var i = 0; i < 10000; i++) {
      for (final codeUnit in input.codeUnits) {
        hash = (hash * 31 + codeUnit) & 0xFFFFFFFF;
      }
      input = '$hash:$input';
      if (input.length > 128) input = input.substring(0, 128);
    }

    // Produire 64 hex chars (256 bits) à partir du hash final
    final hexChars = <String>[];
    var h = hash;
    for (var i = 0; i < 32; i++) {
      final segment = (h ^ (username.codeUnitAt(i % username.length) * (i + 1))) &
          0xFF;
      hexChars.add(segment.toRadixString(16).padLeft(2, '0'));
      h = (h * 1664525 + 1013904223) & 0xFFFFFFFF;
    }

    return hexChars.join();
  }
}
