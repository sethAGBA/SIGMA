import 'package:flutter/foundation.dart';

@immutable
class CompteComptable {
  final String id;
  final String code;
  final String title;
  final String? parentId;
  final bool isArchived;

  const CompteComptable({required this.id, required this.code, required this.title, this.parentId, this.isArchived = false});

  factory CompteComptable.fromMap(Map<String, Object?> m) => CompteComptable(
  id: m['id'] as String,
  code: m['code'] as String? ?? '',
  title: m['title'] as String? ?? '',
  // Ensure parentId is always represented as a String or null regardless of how it was stored in the DB
  parentId: m['parentId'] == null ? null : m['parentId'].toString(),
  isArchived: (m['isArchived'] is int) ? (m['isArchived'] as int) == 1 : (m['isArchived'] as bool? ?? false),
      );

  Map<String, Object?> toMap() => {'id': id, 'code': code, 'title': title, 'parentId': parentId, 'isArchived': isArchived ? 1 : 0};
}