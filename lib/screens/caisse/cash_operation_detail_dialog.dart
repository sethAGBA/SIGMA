// lib/screens/caisse/cash_operation_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class CashOperationDetailDialog extends StatelessWidget {
  final Map<String, dynamic> operation;

  const CashOperationDetailDialog({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(
      symbol: 'FCFA',
      decimalDigits: 0,
      locale: 'fr_FR',
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    final isEntree = operation['type_operation'] == 'ENTREE';
    final montant = (operation['montant'] as num).toDouble();
    final date = DateTime.parse(operation['date_operation']);
    final categorie = operation['categorie'] ?? 'AUTRE';

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isEntree, montant, currencyFormat, date, dateFormat),
            const SizedBox(height: 32),
            _buildDetailRow(
              'Type Opération',
              isEntree ? 'ENCAISSEMENT' : 'DÉCAISSEMENT',
              isBold: true,
            ),
            _buildDetailRow('Catégorie', categorie),
            const Divider(height: 24),
            _buildDetailRow('Libellé', operation['libelle'] ?? '-'),
            _buildDetailRow(
              'Référence Externe',
              operation['reference_externe'] ?? '-',
            ),
            const Divider(height: 24),
            _buildDetailRow(
              'Client / Bénéficiaire',
              operation['reference_externe'] != null
                  ? 'Voir réf.'
                  : 'Non spécifié',
            ),
            _buildDetailRow(
              'Agent Opérateur',
              operation['agent_operation'] ?? 'Système',
            ),
            _buildDetailRow(
              'Mode Paiement',
              operation['mode_paiement'] ?? 'ESPECES',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('FERMER'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isEntree,
    double montant,
    NumberFormat currency,
    DateTime date,
    DateFormat dateFmt,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEntree
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEntree
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: isEntree ? Colors.green : Colors.orange,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isEntree ? 'REÇU ENCAISSEMENT' : 'REÇU DÉCAISSEMENT',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          currency.format(montant),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isEntree ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        Text(dateFmt.format(date), style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
