import 'package:flutter/foundation.dart';

@immutable
class EcritureComptable {
  final String id;
  final String pieceId;
  final String pieceNumber;
  final DateTime date;
  final String journalId;
  final String? reference;
  final String accountCode;
  final String label;
  final double debit;
  final double credit;
  final String? lettrageId;
  final int createdAt;

  const EcritureComptable({
    required this.id,
    required this.pieceId,
    required this.pieceNumber,
    required this.date,
    required this.journalId,
    this.reference,
    required this.accountCode,
    required this.label,
    required this.debit,
    required this.credit,
    this.lettrageId,
    required this.createdAt,
  });

  factory EcritureComptable.fromMap(Map<String, Object?> m) {
    return EcritureComptable(
      id: m['id'] as String,
      pieceId: m['pieceId'] as String? ?? '',
      pieceNumber: m['pieceNumber'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch((m['date'] as int?) ?? 0),
      journalId: m['journalId'] as String? ?? '',
      reference: m['reference'] as String?,
      accountCode: m['accountCode'] as String? ?? '',
      label: m['label'] as String? ?? '',
      debit: (m['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (m['credit'] as num?)?.toDouble() ?? 0.0,
      lettrageId: m['lettrageId'] as String?,
      createdAt: m['createdAt'] as int? ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'pieceId': pieceId,
      'pieceNumber': pieceNumber,
      'date': date.millisecondsSinceEpoch,
      'journalId': journalId,
      'reference': reference,
      'accountCode': accountCode,
      'label': label,
      'debit': debit,
      'credit': credit,
      'lettrageId': lettrageId,
      'createdAt': createdAt,
    };
  }

  EcritureComptable copyWith({
    String? id,
    String? pieceId,
    String? pieceNumber,
    DateTime? date,
    String? journalId,
    String? reference,
    String? accountCode,
    String? label,
    double? debit,
    double? credit,
    String? lettrageId,
    int? createdAt,
  }) {
    return EcritureComptable(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      pieceNumber: pieceNumber ?? this.pieceNumber,
      date: date ?? this.date,
      journalId: journalId ?? this.journalId,
      reference: reference ?? this.reference,
      accountCode: accountCode ?? this.accountCode,
      label: label ?? this.label,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      lettrageId: lettrageId ?? this.lettrageId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}