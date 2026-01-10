import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/document_model.dart';

class DocumentLibraryPage extends StatelessWidget {
  const DocumentLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DocumentItem> sections = [
      // Formulaires
      DocumentItem(
        title: 'Demande de prêt',
        category: DocumentCategory.formulaire,
      ),
      DocumentItem(
        title: 'Fiche de renseignements client',
        category: DocumentCategory.formulaire,
      ),
      DocumentItem(
        title: 'Demande d\'ouverture compte',
        category: DocumentCategory.formulaire,
      ),
      DocumentItem(
        title: 'Demande de retrait épargne',
        category: DocumentCategory.formulaire,
      ),
      DocumentItem(
        title: 'Bordereau versement',
        category: DocumentCategory.formulaire,
      ),
      DocumentItem(
        title: 'Réclamation client',
        category: DocumentCategory.formulaire,
      ),

      // Documents garanties
      DocumentItem(
        title: 'Acte de nantissement',
        category: DocumentCategory.garantie,
      ),
      DocumentItem(
        title: 'Attestation propriété',
        category: DocumentCategory.garantie,
      ),
      DocumentItem(
        title: 'Procuration vente bien',
        category: DocumentCategory.garantie,
      ),
      DocumentItem(
        title: 'Photos biens en garantie',
        category: DocumentCategory.garantie,
      ),

      // Reçus et bordereaux
      DocumentItem(
        title: 'Reçu de remboursement',
        category: DocumentCategory.recu,
      ),
      DocumentItem(
        title: 'Reçu de dépôt épargne',
        category: DocumentCategory.recu,
      ),
      DocumentItem(
        title: 'Bordereau décaissement',
        category: DocumentCategory.recu,
      ),
      DocumentItem(title: 'Reçu de déblocage', category: DocumentCategory.recu),
      DocumentItem(title: 'Relevé de compte', category: DocumentCategory.recu),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bibliothèque Documentaire',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Gérez les formulaires, garanties et reçus officiels.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildSection(
                    'FORMULAIRES',
                    sections
                        .where((d) => d.category == DocumentCategory.formulaire)
                        .toList(),
                    Icons.assignment_rounded,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'DOCUMENTS GARANTIES',
                    sections
                        .where((d) => d.category == DocumentCategory.garantie)
                        .toList(),
                    Icons.security_rounded,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'REÇUS & BORDEREAUX',
                    sections
                        .where((d) => d.category == DocumentCategory.recu)
                        .toList(),
                    Icons.receipt_long_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<DocumentItem> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 3.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                onTap: () {
                  // Action simulated
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ouverture de ${item.title}...')),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
