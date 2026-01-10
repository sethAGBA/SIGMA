import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/document_model.dart';

class AttestationsPage extends StatelessWidget {
  const AttestationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DocumentItem> items = [
      DocumentItem(
        title: 'Attestation de non-engagement',
        category: DocumentCategory.attestation,
      ),
      DocumentItem(
        title: 'Attestation de solde',
        category: DocumentCategory.attestation,
      ),
      DocumentItem(
        title: 'Attestation de fin de prêt',
        category: DocumentCategory.attestation,
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
              'Attestations Officielles',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Générez des attestations pour vos clients et partenaires.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildSection('ATTESTATIONS', items, Icons.verified_rounded),
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
                  Icons.picture_as_pdf_rounded,
                  size: 18,
                  color: Colors.red,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Impression de ${item.title}...')),
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
