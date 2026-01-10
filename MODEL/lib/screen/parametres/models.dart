// Models


class DocumentTemplate {
  final String id;
  final String name;
  final String type;
  final String content;
  final DateTime lastModified;

  DocumentTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'content': content,
      'lastModified': lastModified.millisecondsSinceEpoch,
    };
  }

  factory DocumentTemplate.fromMap(Map<String, dynamic> map) {
    return DocumentTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      content: map['content'] as String,
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['lastModified'] as int),
    );
  }
}

class CompanyInfo {
  String name;
  String address;
  String phone;
  String email;
  String rccm;
  String nif;
  String website;
  String logoPath;
  bool autoBackup;
  String backupFrequency;
  int retentionDays;
  String exercice;
  String monnaie;
  String planComptable;
  String academic_year;
  double targetRevenue; // New field
  String directorName; // New field
  String location;     // New field

  CompanyInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.rccm,
    required this.nif,
    required this.website,
    required this.logoPath,
    this.autoBackup = false,
    this.backupFrequency = 'Quotidienne',
    this.retentionDays = 30,
    this.exercice = '',
    this.monnaie = 'FCFA',
    this.planComptable = 'SYSCOHADA',
    this.academic_year = '',
    this.targetRevenue = 0.0, // Initialize new field
    this.directorName = '',    // Initialize new field
    this.location = '',      // Initialize new field
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'rccm': rccm,
      'nif': nif,
      'website': website,
      'logoPath': logoPath,
      'autoBackup': autoBackup ? 1 : 0,
      'backupFrequency': backupFrequency,
      'retentionDays': retentionDays,
      'exercice': exercice,
      'monnaie': monnaie,
      'planComptable': planComptable,
      'academic_year': academic_year,
      'targetRevenue': targetRevenue, // Add to map
      'directorName': directorName,    // Add to map
      'location': location,          // Add to map
    };
  }

  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String,
      rccm: map['rccm'] as String,
      nif: map['nif'] as String,
      website: map['website'] as String,
      logoPath: map['logoPath'] as String,
      autoBackup: (map['autoBackup'] as int?) == 1,
      backupFrequency: map['backupFrequency'] as String? ?? 'Quotidienne',
      retentionDays: map['retentionDays'] as int? ?? 30,
      exercice: map['exercice'] as String? ?? '',
      monnaie: map['monnaie'] as String? ?? 'FCFA',
      planComptable: map['planComptable'] as String? ?? 'SYSCOHADA',
      academic_year: map['academic_year'] as String? ?? '',
    targetRevenue: (map['targetRevenue'] is num)
      ? (map['targetRevenue'] as num).toDouble()
      : double.tryParse((map['targetRevenue'] ?? '').toString()) ?? 0.0,
      directorName: map['directorName'] as String? ?? '',    // Parse new field
      location: map['location'] as String? ?? '',          // Parse new field
    );
  }
}