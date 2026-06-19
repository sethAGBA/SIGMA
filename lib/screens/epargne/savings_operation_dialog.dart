// lib/screens/epargne/savings_operation_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/audit_field_utils.dart';
import '../../models/savings_account_model.dart';
import '../../models/savings_transaction_model.dart';
import '../../models/produit_financier_model.dart';
import 'break_dat_dialog.dart';

class SavingsOperationDialog extends StatefulWidget {
  final SavingsAccount account;
  final SavingsTransactionType initialType;

  const SavingsOperationDialog({
    super.key,
    required this.account,
    this.initialType = SavingsTransactionType.depot,
  });

  @override
  State<SavingsOperationDialog> createState() => _SavingsOperationDialogState();
}

class _SavingsOperationDialogState extends State<SavingsOperationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  final _pieceController = TextEditingController();

  late SavingsTransactionType _type;
  bool _isLoading = false;
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
    if (amount <= 0) return;

    double debitAmount = amount;
    if (_type == SavingsTransactionType.retrait) {
      final produit = widget.account.produit;
      final echeance = widget.account.dateEcheanceTerme;
      final isDatBloque = produit?.savingsCategory == SavingsCategory.bloquee;
      if (isDatBloque &&
          echeance != null &&
          DateTime.now().isBefore(echeance)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => BreakDATDialog(account: widget.account),
        );
        if (confirmed != true) return;

        final penalite = BreakDATDialog.calculerPenalite(widget.account);
        debitAmount = amount + penalite;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pénalité rupture DAT : ${currencyFormat.format(penalite)}',
              ),
            ),
          );
        }
      }

      if (debitAmount > widget.account.solde) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solde insuffisant pour ce retrait')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final newBalance = _type == SavingsTransactionType.depot
        ? widget.account.solde + amount
        : widget.account.solde - debitAmount;

    final transaction = SavingsTransaction(
      compteId: widget.account.id!,
      type: _type,
      montant: _type == SavingsTransactionType.depot ? amount : debitAmount,
      soldeApres: newBalance,
      dateOperation: DateTime.now(),
      agentOperation: auditFieldValue(AuthService().currentUsername),
      numeroPiece: _pieceController.text,
      commentaire: _commentController.text,
    );

    try {
      await DatabaseService().insertSavingsTransaction(transaction);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _type == SavingsTransactionType.depot
                        ? 'Dépôt d\'Épargne'
                        : 'Retrait d\'Épargne',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _statusBadge(_type),
                ],
              ),
              const SizedBox(height: 16),
              _buildAccountSummary(isDark),
              const SizedBox(height: 24),

              // Montant
              const Text(
                'Montant de l\'opération',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  suffixText: 'FCFA',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Montant requis';
                  final amt =
                      double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0;
                  if (amt <= 0) return 'Montant invalide';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // N° Pièce
              const Text(
                'N° Pièce / Référence',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pieceController,
                decoration: InputDecoration(
                  hintText: 'Ex: DEP-12345',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Commentaire
              const Text(
                'Commentaire (Optionnel)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Détails supplémentaires...',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ANNULER'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _type == SavingsTransactionType.depot
                          ? Colors.green
                          : Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _type == SavingsTransactionType.depot
                                ? 'CONFIRMER LE DÉPÔT'
                                : 'CONFIRMER LE RETRAIT',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _summaryRow(
            'Client',
            '${widget.account.client?.nom} ${widget.account.client?.prenoms}',
          ),
          const SizedBox(height: 4),
          _summaryRow('N° Compte', widget.account.numeroCompte),
          const Divider(height: 24),
          _summaryRow(
            'Solde Actuel',
            currencyFormat.format(widget.account.solde),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 14,
            color: isBold ? AppColors.secondary : null,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(SavingsTransactionType type) {
    final color = type == SavingsTransactionType.depot
        ? Colors.green
        : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
