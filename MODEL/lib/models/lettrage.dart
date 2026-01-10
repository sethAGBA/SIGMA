class Lettrage {
  final String id;
  final String label;
  final int createdAt;

  Lettrage({required this.id, required this.label, required this.createdAt});

  factory Lettrage.fromMap(Map<String, Object?> m) => Lettrage(
        id: m['id'] as String,
        label: m['label'] as String? ?? '',
        createdAt: m['createdAt'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {'id': id, 'label': label, 'createdAt': createdAt};
}
