class Session {
  final String id;
  final String name; // new: session name/title
  final DateTime startDate;
  final DateTime endDate;
  final String room;
  // many-to-many: list of formateur ids assigned to this session
  final List<String> formateurIds;
  final int maxCapacity;
  final int currentEnrollments;
  final String status;

  Session({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.room,
    this.formateurIds = const [],
    required this.maxCapacity,
    this.currentEnrollments = 0,
    this.status = 'planned',
  });

  double get fillRate => maxCapacity > 0 ? (currentEnrollments / maxCapacity) * 100 : 0;

  Map<String, dynamic> toMap(String formationId) {
    return {
      'id': id,
      'formationId': formationId,
      'name': name,
      'start': startDate.millisecondsSinceEpoch,
      'end': endDate.millisecondsSinceEpoch,
        // keep legacy single-column for compatibility: store first assigned id or empty
        'formateurId': formateurIds.isNotEmpty ? formateurIds.first : '',
      'room': room,
      'maxCapacity': maxCapacity,
      'currentEnrollments': currentEnrollments,
      'status': status,
    };
  }

  factory Session.fromMap(Map<String, dynamic> m) {
    // support both 'name' and legacy lack of it
    return Session(
      id: m['id'] as String,
      name: m['name'] as String? ?? m['title'] as String? ?? '',
      startDate: DateTime.fromMillisecondsSinceEpoch((m['start'] ?? m['startDate']) as int),
      endDate: DateTime.fromMillisecondsSinceEpoch((m['end'] ?? m['endDate']) as int),
      room: m['room'] as String? ?? '',
      // try to read a serialized formateurIds or fall back to single formateurId
      formateurIds: (() {
        final raw = m['formateurIds'];
        if (raw is String && raw.isNotEmpty) {
          // expecting a comma-separated list when present
          return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
        if (raw is List) {
          return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        }
        if (m['formateurId'] != null && (m['formateurId'] as String).isNotEmpty) {
          return [(m['formateurId'] as String)];
        }
        return <String>[];
      })(),
      maxCapacity: (m['maxCapacity'] as num?)?.toInt() ?? 0,
      currentEnrollments: (m['currentEnrollments'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'planned',
    );
  }
}