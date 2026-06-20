// lib/models/sync_conflict_model.dart

import 'dart:convert';

class SyncConflict {
  final String id;
  final String syncQueueId;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverPayload;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;
  final String resolution;
  final DateTime createdAt;

  const SyncConflict({
    required this.id,
    required this.syncQueueId,
    required this.entityType,
    this.entityId,
    required this.localPayload,
    required this.serverPayload,
    this.localUpdatedAt,
    this.serverUpdatedAt,
    this.resolution = 'pending',
    required this.createdAt,
  });

  bool get isPending => resolution == 'pending';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_queue_id': syncQueueId,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_payload': jsonEncode(localPayload),
      'server_payload': jsonEncode(serverPayload),
      'local_updated_at': localUpdatedAt?.toIso8601String(),
      'server_updated_at': serverUpdatedAt?.toIso8601String(),
      'resolution': resolution,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncConflict.fromMap(Map<String, dynamic> map) {
    return SyncConflict(
      id: map['id'] as String,
      syncQueueId: map['sync_queue_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      localPayload: _parseJsonMap(map['local_payload']),
      serverPayload: _parseJsonMap(map['server_payload']),
      localUpdatedAt: map['local_updated_at'] != null
          ? DateTime.tryParse(map['local_updated_at'] as String)
          : null,
      serverUpdatedAt: map['server_updated_at'] != null
          ? DateTime.tryParse(map['server_updated_at'] as String)
          : null,
      resolution: (map['resolution'] as String?) ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static Map<String, dynamic> _parseJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  SyncConflict copyWith({
    String? resolution,
  }) {
    return SyncConflict(
      id: id,
      syncQueueId: syncQueueId,
      entityType: entityType,
      entityId: entityId,
      localPayload: localPayload,
      serverPayload: serverPayload,
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: serverUpdatedAt,
      resolution: resolution ?? this.resolution,
      createdAt: createdAt,
    );
  }
}
