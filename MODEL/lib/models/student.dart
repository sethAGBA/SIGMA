class Student {
  final String id;
  final String studentNumber;
  final String name;
  final String photo; // path or url
  final String address;
  final String formation;
  final String paymentStatus;
  final String phone;
  final String email;
  final String dateNaissance; // JJ/MM/YYYY string
  final String lieuNaissance;
  final String idDocumentType; // New: Type of ID document (e.g., CNI, Passport)
  final String idNumber;       // New: ID document number
  final String participantTitle; // New: Title for the participant (e.g., Mr., Mme, Dr.)

  Student({
    required this.id,
    required this.studentNumber,
    required this.name,
    this.photo = '',
    this.address = '',
    this.formation = '',
  // default to unpaid
  this.paymentStatus = 'Impayé',
    this.phone = '',
    this.email = '',
  this.dateNaissance = '',
  this.lieuNaissance = '',
    this.idDocumentType = '', // Initialize new field
    this.idNumber = '',       // Initialize new field
    this.participantTitle = '', // Initialize new field
  });

  factory Student.fromMap(Map<String, Object?> m) => Student(
        id: (m['id'] as String?) ?? '',
        studentNumber: (m['studentNumber'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        photo: (m['photo'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        formation: (m['formation'] as String?) ?? '',
  paymentStatus: (m['paymentStatus'] as String?) ?? 'Impayé',
        phone: (m['phone'] as String?) ?? '',
  dateNaissance: (m['dateNaissance'] as String?) ?? '',
  lieuNaissance: (m['lieuNaissance'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        idDocumentType: (m['idDocumentType'] as String?) ?? '', // New field
        idNumber: (m['idNumber'] as String?) ?? '',             // New field
        participantTitle: (m['participantTitle'] as String?) ?? '', // New field
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'studentNumber': studentNumber,
        'name': name,
        'photo': photo,
        'address': address,
        'formation': formation,
        'paymentStatus': paymentStatus,
        'phone': phone,
  'dateNaissance': dateNaissance,
  'lieuNaissance': lieuNaissance,
        'email': email,
        'idDocumentType': idDocumentType, // New field
        'idNumber': idNumber,             // New field
        'participantTitle': participantTitle, // New field
      };
}


