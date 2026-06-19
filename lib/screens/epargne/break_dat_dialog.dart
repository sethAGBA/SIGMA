// lib/screens/epargne/break_dat_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/savings_account_model.dart';
import '../../widgets/dialogs/pin_validation_dialog.dart';

class BreakDATDialog extends StatelessWidget {
  final SavingsAccount account;

  const BreakDATDialog({super.key, required this.account});

  double get _penalite {
    final taux = account.tauxPenaliteRuptureAnt ?? 0;
    return account.interetsAcquis * taux / 100;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final echeance = account.dateEcheanceTerme;

    return AlertDialog(
      title: const Text('Rupture anticipée DAT'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce compte est bloqué jusqu\'au ${echeance != null ? dateFormat.format(echeance) : '—'}.',
          ),
          const SizedBox(height: 12),
          Text('Intérêts acquis : ${account.interetsAcquis.toStringAsFixed(0)} FCFA'),
          Text(
            'Pénalité (${account.tauxPenaliteRuptureAnt ?? 0} %) : ${_penalite.toStringAsFixed(0)} FCFA',
          ),
          const SizedBox(height: 8),
          const Text(
            'La rupture nécessite la validation d\'un superviseur.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => const PinValidationDialog(),
            );
            if (context.mounted && ok == true) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Valider avec PIN superviseur'),
        ),
      ],
    );
  }

  static double calculerPenalite(SavingsAccount account) {
    final taux = account.tauxPenaliteRuptureAnt ?? 0;
    return account.interetsAcquis * taux / 100;
  }
}
