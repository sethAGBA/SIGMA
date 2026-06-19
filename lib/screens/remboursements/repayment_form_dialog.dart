// lib/screens/remboursements/repayment_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/loan_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../models/repayment_model.dart';
import 'payment_receipt_dialog.dart';

class RepaymentFormDialog extends StatefulWidget {
  final Loan loan;
  final RepaymentSchedule? schedule;

  const RepaymentFormDialog({super.key, required this.loan, this.schedule});

  @override
  State<RepaymentFormDialog> createState() => _RepaymentFormDialogState();
}

class _RepaymentFormDialogState extends State<RepaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  RepaymentMode _selectedMode = RepaymentMode.especes;
  bool _isLoading = false;

  double _partCapital = 0;
  double _partInterets = 0;
  double _partPenalites = 0;
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      // Pré-remplir avec le montant de l'échéance + pénalités éventuelles
      final penalties = widget.loan.calculatePenalties();
      final total = widget.schedule!.totalDu + penalties;
      _amountController.text = total.toStringAsFixed(0);
      _calculateSplit(total);
    }
  }

  void _calculateSplit(double amount) {
    setState(() {
      _totalAmount = amount;
      double remaining = amount;

      // 1. Pénalités d'abord
      final penaltiesDue = widget.loan.calculatePenalties();
      _partPenalites = remaining >= penaltiesDue ? penaltiesDue : remaining;
      remaining -= _partPenalites;

      // 2. Intérêts ensuite
      final interetsDus = widget.schedule?.interetsDus ?? 0;
      _partInterets = remaining >= interetsDus ? interetsDus : remaining;
      remaining -= _partInterets;

      // 3. Capital enfin
      _partCapital = remaining;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repayment = Repayment(
        pretId: widget.loan.id!,
        echeanceId: widget.schedule?.id,
        montantTotal: _totalAmount,
        partCapital: _partCapital,
        partInterets: _partInterets,
        partPenalites: _partPenalites,
        datePaiement: DateTime.now(),
        modePaiement: _selectedMode,
        numeroRecu:
            'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        agentCollecteur: AuthService().currentUsername.isNotEmpty
            ? AuthService().currentUsername
            : 'Inconnu', // utilisateur de session
        commentaire: _commentController.text,
      );

      await DatabaseService().insertRepayment(repayment);

      if (mounted) {
        // Remplacer Navigator.pop par l'affichage du reçu
        Navigator.pop(context, true); // Fermer le formulaire

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              PaymentReceiptDialog(repayment: repayment, loan: widget.loan),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'FCFA',
      decimalDigits: 0,
      locale: 'fr_FR',
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enregistrer un paiement',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Infos Prêt
              _buildInfoSection(currencyFormat),

              const SizedBox(height: 24),

              // Saisie Montant
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant encaissé',
                  suffixText: 'FCFA',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                onChanged: (val) {
                  final amount = double.tryParse(val) ?? 0;
                  _calculateSplit(amount);
                },
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Entrez un montant';
                  if ((double.tryParse(val) ?? 0) <= 0)
                    return 'Montant invalide';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Répartition
              _buildBreakdownSection(currencyFormat),

              const SizedBox(height: 24),

              // Mode de paiement
              const Text(
                'Mode de paiement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RepaymentMode>(
                value: _selectedMode,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: RepaymentMode.values.map((mode) {
                  return DropdownMenuItem(value: mode, child: Text(mode.label));
                }).toList(),
                onChanged: (val) => setState(() => _selectedMode = val!),
              ),

              const SizedBox(height: 16),

              // Commentaire
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire / Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              // Bouton
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'CONFIRMER LE PAIEMENT',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          _buildInfoRow('Client', widget.loan.client?.nomComplet ?? 'Inconnu'),
          _buildInfoRow('Prêt', widget.loan.numeroPret),
          if (widget.schedule != null)
            _buildInfoRow(
              'Échéance n°',
              widget.schedule!.numeroEcheance.toString(),
            ),
          const Divider(),
          _buildInfoRow(
            'Solde actuel',
            format.format(widget.loan.soldeRestant),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Répartition du paiement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildSplitRow('Pénalités', _partPenalites, format, Colors.red),
          _buildSplitRow('Intérêts', _partInterets, format, Colors.orange),
          _buildSplitRow('Capital', _partCapital, format, Colors.green),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitRow(
    String label,
    double amount,
    NumberFormat format,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            format.format(amount),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
