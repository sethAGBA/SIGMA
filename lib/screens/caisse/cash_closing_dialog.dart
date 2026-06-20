// lib/screens/caisse/cash_closing_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/cash_closing_model.dart';
import 'cash_denomination_dialog.dart';

class CashClosingDialog extends StatefulWidget {
  const CashClosingDialog({super.key});

  @override
  State<CashClosingDialog> createState() => _CashClosingDialogState();
}

class _CashClosingDialogState extends State<CashClosingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _physicalBalanceController = TextEditingController();
  final _observationsController = TextEditingController();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  bool _isLoading = true;
  double _soldeInitial = 0.0;
  double _theoreticalBalance = 0;
  double _totalEntrees = 0;
  double _totalSorties = 0;
  double _physicalBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseService();
    final totals = await db.getDailyTotals(startDate: DateTime.now());
    final balance = await db.getCashBalance();
    final lastClosing = await db.getLastCashClosing();

    setState(() {
      _soldeInitial = lastClosing?.soldePhysique ?? 0.0;
      _totalEntrees = totals['entrees']!;
      _totalSorties = totals['sorties']!;
      _theoreticalBalance = balance;
      _isLoading = false;
    });
  }

  double get _ecart => _physicalBalance - _theoreticalBalance;

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildFinancialSummary(isDark),
                    const SizedBox(height: 24),
                    _buildClosingForm(isDark),
                    const SizedBox(height: 32),
                    _buildActions(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.lock_clock_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clôture Journalière',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Arrêté de caisse et vérification des soldes',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildFinancialSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          _summaryRow('Solde initial (veille)', _soldeInitial, Colors.grey),
          const SizedBox(height: 12),
          _summaryRow('Entrées du jour', _totalEntrees, Colors.green),
          const SizedBox(height: 12),
          _summaryRow('Sorties du jour', _totalSorties, Colors.orange),
          const Divider(height: 24),
          _summaryRow(
            'SOLDE THÉORIQUE',
            _theoreticalBalance,
            AppColors.primary,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? null : Colors.grey,
          ),
        ),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildClosingForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPTAGE PHYSIQUE',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: Colors.grey,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _physicalBalanceController,
                decoration: InputDecoration(
                  labelText: 'Solde Physique (Montant compté)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: 'FCFA',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                onChanged: (value) {
                  setState(() {
                    _physicalBalance = double.tryParse(value) ?? 0;
                  });
                },
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Champ requis' : null,
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: _ouvrirDecompte,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text(
                  'Décompte\npar coupures',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.3),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDiscrepancyBadge(),
        const SizedBox(height: 24),
        TextFormField(
          controller: _observationsController,
          decoration: InputDecoration(
            labelText: 'Observations / Justificatifs d\'écart',
            alignLabelWithHint: true,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  /// Ouvre le dialog de décompte par coupures et pré-remplit le champ solde
  /// physique avec le résultat si l'utilisateur valide.
  Future<void> _ouvrirDecompte() async {
    final total = await showDialog<double>(
      context: context,
      builder: (_) => CashDenominationDialog(soldeTheorique: _theoreticalBalance),
    );
    if (total != null && mounted) {
      setState(() {
        _physicalBalance = total;
        _physicalBalanceController.text = total.toStringAsFixed(0);
      });
    }
  }

  Widget _buildDiscrepancyBadge() {
    final ecart = _ecart;
    if (ecart == 0) return const SizedBox.shrink();

    final isShortage = ecart < 0; // Manquant
    final color = isShortage ? Colors.red : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isShortage
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isShortage
                  ? 'MAUVAIS : Manquant de ${currencyFormat.format(ecart.abs())}'
                  : 'SURPLUS : Excédent de ${currencyFormat.format(ecart)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ANNULER'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'VALIDER LA CLÔTURE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Guard : utilisateur connecté requis
    if (AuthService().currentUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun utilisateur connecté. Veuillez vous reconnecter.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final closing = CashClosing(
        dateCloture: DateTime.now(),
        agentCloture: AuthService().currentUsername,
        soldeInitial: _soldeInitial,
        totalEntrees: _totalEntrees,
        totalSorties: _totalSorties,
        soldeTheorique: _theoreticalBalance,
        soldePhysique: _physicalBalance,
        ecart: _ecart,
        observations: _observationsController.text,
      );

      await DatabaseService().insertCashClosing(closing);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caisse clôturée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
