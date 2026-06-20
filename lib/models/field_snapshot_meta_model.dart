// lib/models/field_snapshot_meta_model.dart

class FieldSnapshotMeta {
  final int? id;
  final String agentId;
  final String snapshotDate;
  final DateTime createdAt;
  final int clientCount;
  final int scheduleCount;
  final int requestCount;

  const FieldSnapshotMeta({
    this.id,
    required this.agentId,
    required this.snapshotDate,
    required this.createdAt,
    this.clientCount = 0,
    this.scheduleCount = 0,
    this.requestCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'agent_id': agentId,
      'snapshot_date': snapshotDate,
      'created_at': createdAt.toIso8601String(),
      'client_count': clientCount,
      'schedule_count': scheduleCount,
      'request_count': requestCount,
    };
  }

  factory FieldSnapshotMeta.fromMap(Map<String, dynamic> map) {
    return FieldSnapshotMeta(
      id: map['id'] as int?,
      agentId: map['agent_id'] as String,
      snapshotDate: map['snapshot_date'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      clientCount: (map['client_count'] as int?) ?? 0,
      scheduleCount: (map['schedule_count'] as int?) ?? 0,
      requestCount: (map['request_count'] as int?) ?? 0,
    );
  }
}
