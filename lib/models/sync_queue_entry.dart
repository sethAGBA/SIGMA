// lib/models/sync_queue_entry.dart

import 'dart:convert';

/// Représente une opération HTTP en attente de synchronisation vers le serveur.
///
/// Cycle de vie du statut :
///   pending → in_progress → success | failed
class SyncQueueEntry {
  final String id;

  /// Méthode HTTP : 'POST', 'PUT' ou 'DELETE'
  final String method;

  /// Chemin de l'API cible, ex : '/clients/42'
  final String path;

  /// Corps de la requête (null pour DELETE)
  final Map<String, dynamic>? body;

  /// Statut actuel : 'pending', 'in_progress', 'success', 'failed'
  final String status;

  /// Priorité : 1 = haute, 4 = basse
  final int priority;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Nombre de tentatives d'envoi déjà effectuées
  final int attemptCount;

  /// Dernière erreur rencontrée lors d'une tentative, null si aucune
  final String? lastError;

  const SyncQueueEntry({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    this.status = 'pending',
    this.priority = 4,
    required this.createdAt,
    required this.updatedAt,
    this.attemptCount = 0,
    this.lastError,
  });

  // ── Sérialisation SQLite ───────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'method': method,
      'path': path,
      'body': body != null ? jsonEncode(body) : null,
      'status': status,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'attempt_count': attemptCount,
      'last_error': lastError,
    };
  }

  factory SyncQueueEntry.fromMap(Map<String, dynamic> map) {
    final bodyRaw = map['body'];
    Map<String, dynamic>? parsedBody;
    if (bodyRaw is String && bodyRaw.isNotEmpty) {
      try {
        parsedBody = jsonDecode(bodyRaw) as Map<String, dynamic>;
      } catch (_) {
        parsedBody = null;
      }
    } else if (bodyRaw is Map<String, dynamic>) {
      parsedBody = bodyRaw;
    }

    return SyncQueueEntry(
      id: map['id'] as String,
      method: map['method'] as String,
      path: map['path'] as String,
      body: parsedBody,
      status: (map['status'] as String?) ?? 'pending',
      priority: (map['priority'] as int?) ?? 4,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      attemptCount: (map['attempt_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  // ── Copie avec modifications ───────────────────────────────────────────

  SyncQueueEntry copyWith({
    String? id,
    String? method,
    String? path,
    Map<String, dynamic>? body,
    bool clearBody = false,
    String? status,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? attemptCount,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncQueueEntry(
      id: id ?? this.id,
      method: method ?? this.method,
      path: path ?? this.path,
      body: clearBody ? null : (body ?? this.body),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  // ── Génération d'ID sans package uuid ────────────────────────────────

  /// Génère un identifiant pseudo-unique basé sur le temps et les paramètres.
  static String generateId(String method, String path) {
    return '${DateTime.now().microsecondsSinceEpoch}-${method.hashCode.abs()}-${path.hashCode.abs()}';
  }

  @override
  String toString() {
    return 'SyncQueueEntry(id: $id, method: $method, path: $path, '
        'status: $status, priority: $priority, attemptCount: $attemptCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncQueueEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
