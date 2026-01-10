enum AuditSeverity { low, medium, high, critical }

class AuditLog {
  final String id;
  final String? userId; // Can be null for system actions or failed logins
  final String username;
  final String action;
  final String details;
  final DateTime timestamp;
  final AuditSeverity severity;
  final String? ipAddress;

  AuditLog({
    required this.id,
    this.userId,
    required this.username,
    required this.action,
    required this.details,
    required this.timestamp,
    this.severity = AuditSeverity.low,
    this.ipAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'ip_address': ipAddress,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'],
      userId: map['user_id'],
      username: map['username'] ?? 'Système',
      action: map['action'] ?? '',
      details: map['details'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      severity: AuditSeverity.values.firstWhere(
        (s) => s.name == map['severity'],
        orElse: () => AuditSeverity.low,
      ),
      ipAddress: map['ip_address'],
    );
  }
}
