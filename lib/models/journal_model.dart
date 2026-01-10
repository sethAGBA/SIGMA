class Journal {
  final int? id;
  final String code;
  final String libelle;

  Journal({this.id, required this.code, required this.libelle});

  Map<String, dynamic> toMap() {
    return {'id': id, 'code': code, 'libelle': libelle};
  }

  factory Journal.fromMap(Map<String, dynamic> map) {
    return Journal(id: map['id'], code: map['code'], libelle: map['libelle']);
  }
}
