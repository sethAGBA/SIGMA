enum CommunicationType { sms, email, push }

enum NotificationStatus { sent, failed, pending }

class MessageTemplate {
  final String id;
  final String title;
  final String content;
  final CommunicationType type;
  final DateTime createdAt;

  MessageTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MessageTemplate.fromMap(Map<String, dynamic> map) {
    return MessageTemplate(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      type: CommunicationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CommunicationType.sms,
      ),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class NotificationLog {
  final String id;
  final String? clientId;
  final String recipient;
  final String message;
  final NotificationStatus status;
  final DateTime timestamp;
  final CommunicationType type;

  NotificationLog({
    required this.id,
    this.clientId,
    required this.recipient,
    required this.message,
    required this.status,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'recipient': recipient,
      'message': message,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
    };
  }

  factory NotificationLog.fromMap(Map<String, dynamic> map) {
    return NotificationLog(
      id: map['id'],
      clientId: map['client_id'],
      recipient: map['recipient'],
      message: map['message'],
      status: NotificationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => NotificationStatus.pending,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      type: CommunicationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CommunicationType.sms,
      ),
    );
  }
}
