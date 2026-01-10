enum DocumentCategory { contrat, formulaire, garantie, recu, attestation }

class DocumentItem {
  final String title;
  final DocumentCategory category;
  final String description;
  final String? templatePath;

  DocumentItem({
    required this.title,
    required this.category,
    this.description = '',
    this.templatePath,
  });
}
