class Journal {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? type;

  Journal({required this.id, required this.code, required this.name, this.description, this.type});

  factory Journal.fromMap(Map<String, Object?> m) => Journal(
        id: m['id'] as String,
        code: m['code'] as String? ?? '',
        name: m['name'] as String? ?? '',
        description: m['description'] as String?,
        type: m['type'] as String?,
      );

  Map<String, Object?> toMap() => {'id': id, 'code': code, 'name': name, 'description': description, 'type': type};
}
