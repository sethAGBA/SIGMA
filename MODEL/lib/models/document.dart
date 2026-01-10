class Document {
  final String id;
  final String formationId;
  final String studentId;
  final String title;
  final String category;
  final String fileName;
  final String path;
  final String mimeType;
  final int size;
  final int uploadedAtMs;
  final int isArchived;
  final String certificateNumber;
  final String validationUrl;
  final String qrcodeData;

  Document({
    required this.id,
  required this.formationId,
  this.studentId = '',
    this.title = '',
    this.category = '',
    required this.fileName,
    required this.path,
    this.mimeType = '',
    this.size = 0,
  this.certificateNumber = '',
  this.validationUrl = '',
  this.qrcodeData = '',
    int? uploadedAtMs,
    this.isArchived = 0,
  }) : uploadedAtMs = uploadedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, Object?> toMap() => {
        'id': id,
        'formationId': formationId,
  'studentId': studentId,
  'title': title,
  'category': category,
        'fileName': fileName,
        'path': path,
        'mimeType': mimeType,
        'size': size,
    'certificateNumber': certificateNumber,
    'validationUrl': validationUrl,
    'qrcodeData': qrcodeData,
        'uploadedAt': uploadedAtMs,
        'isArchived': isArchived,
      };

  factory Document.fromMap(Map<String, dynamic> m) => Document(
        id: m['id'] as String,
        formationId: m['formationId'] as String? ?? '',
  studentId: m['studentId'] as String? ?? '',
  title: m['title'] as String? ?? '',
  category: m['category'] as String? ?? '',
        fileName: m['fileName'] as String? ?? '',
        path: m['path'] as String? ?? '',
        mimeType: m['mimeType'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
  certificateNumber: m['certificateNumber'] as String? ?? '',
  validationUrl: m['validationUrl'] as String? ?? '',
  qrcodeData: m['qrcodeData'] as String? ?? '',
        uploadedAtMs: (m['uploadedAt'] as num?)?.toInt(),
        isArchived: (m['isArchived'] as num?)?.toInt() ?? 0,
      );
}
