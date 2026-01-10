import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/document_model.dart';

class ContractTemplatesPage extends StatelessWidget {
  const ContractTemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DocumentItem> contracts = [
      DocumentItem(
        title: 'Contrat de prêt individuel',
        category: DocumentCategory.contrat,
      ),
      DocumentItem(
        title: 'Contrat de prêt groupe',
        category: DocumentCategory.contrat,
      ),
      DocumentItem(
        title: 'Contrat d\'épargne',
        category: DocumentCategory.contrat,
      ),
      DocumentItem(
        title: 'Acte de caution solidaire',
        category: DocumentCategory.contrat,
      ),
      DocumentItem(
        title: 'Engagement personnel caution',
        category: DocumentCategory.contrat,
      ),
      DocumentItem(
        title: 'Reconnaissance de dette',
        category: DocumentCategory.contrat,
      ),
      DocumentItem(
        title: 'Avenant modification contrat',
        category: DocumentCategory.contrat,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contrats Types',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Modèles de contrats et engagements légaux pour l\'institution.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildSection(
                    'MODÈLES DE CONTRATS',
                    contracts,
                    Icons.description_rounded,
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
                  Icons.print_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Génération de ${item.title}...')),
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
