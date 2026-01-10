class Inscription {
  final String id;
  final String studentId;
  final String formationId;
  final String? sessionId; // New field
  final DateTime inscriptionDate;
  final String status;
  final double? finalGrade;
  final String? certificatePath;
  final double? discountPercent;
  final String? appreciation;

  // To hold related data
  final String? formationTitle;

  Inscription({
    required this.id,
    required this.studentId,
    required this.formationId,
    this.sessionId, // New field
    required this.inscriptionDate,
    required this.status,
    this.finalGrade,
    this.certificatePath,
    this.discountPercent,
    this.appreciation,
    this.formationTitle,
  });

  factory Inscription.fromMap(Map<String, dynamic> map) {
    return Inscription(
      id: map['id'] as String,
      studentId: map['studentId'] as String,
      formationId: map['formationId'] as String,
      sessionId: map['sessionId'] as String?, // New field
      inscriptionDate: DateTime.fromMillisecondsSinceEpoch(map['inscriptionDate'] as int),
      status: map['status'] as String,
      finalGrade: map['finalGrade'] as double?,
      certificatePath: map['certificatePath'] as String?,
      discountPercent: (map['discountPercent'] as num?)?.toDouble(),
      appreciation: map['appreciation'] as String?,
      formationTitle: map['formationTitle'] as String?, // Joined from formations table
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'formationId': formationId,
      'sessionId': sessionId, // New field
      'inscriptionDate': inscriptionDate.millisecondsSinceEpoch,
      'status': status,
      'finalGrade': finalGrade,
      'certificatePath': certificatePath,
      'discountPercent': discountPercent,
      'appreciation': appreciation,
    };
  }
}
