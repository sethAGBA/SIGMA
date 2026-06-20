// lib/screens/caisse/cash_denomination_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

/// Coupures FCFA disponibles (de la plus grande à la plus petite)
const List<int> _kCoupures = [10000, 5000, 2000, 1000, 500, 200, 100];

class CashDenominationDialog extends StatefulWidget {
  /// Solde théorique calculé par la caisse, utilisé pour afficher l'écart.
  final double soldeTheorique;

  const CashDenominationDialog({super.key, required this.soldeTheorique});

  @override
  State<CashDenominationDialog> createState() => _CashDenominationDialogState();
}

class _CashDenominationDialogState extends State<CashDenominationDialog> {
  // Un contrôleur par coupure, dans le même ordre que [_kCoupures].
  late final List<TextEditingController> _controllers;

  final _currencyFmt = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _kCoupures.length,
      (_) => TextEditingController(),
    );
    // Écouter les changements pour recalculer le total en temps réel.
    for (final ctrl in _controllers) {
      ctrl.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers) {
      ctrl.removeListener(_onChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Sous-total pour la ligne [index] : quantité × valeur coupure.
  double _sousTotal(int index) {
    final qty = int.tryParse(_controllers[index].text) ?? 0;
    return qty * _kCoupures[index].toDouble();
  }

  /// Total de toutes les coupures physiquement comptées.
  double get _totalPhysique =>
      List.generate(_kCoupures.length, _sousTotal)
          .fold(0.0, (a, b) => a + b);

  /// Écart = total physique − solde théorique.
  double get _ecart => _totalPhysique - widget.soldeTheorique;

  // ── Construction ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildGrid(isDark),
            const SizedBox(height: 24),
            _buildTotalRow(isDark),
            const SizedBox(height: 12),
            _buildEcartBadge(),
            const SizedBox(height: 32),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  // ── En-tête ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.payments_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Décompte par coupures',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Saisir la quantité pour chaque coupure',
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

  // ── En-tête de la grille ─────────────────────────────────────────────────────

  Widget _buildGrid(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          _buildGridHeader(isDark),
          const Divider(height: 1),
          ...List.generate(_kCoupures.length, (i) {
            final isLast = i == _kCoupures.length - 1;
            return Column(
              children: [
                _buildGridRow(i, isDark),
                if (!isLast) Divider(height: 1, color: Colors.grey[200]),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGridHeader(bool isDark) {
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('COUPURE', style: headerStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('QUANTITÉ', style: headerStyle, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 4,
            child: Text('SOUS-TOTAL', style: headerStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildGridRow(int index, bool isDark) {
    final coupure = _kCoupures[index];
    final sousTotal = _sousTotal(index);
    final hasValue = sousTotal > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Valeur coupure
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currencyFmt.format(coupure),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Champ quantité
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _controllers[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkDivider : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkDivider : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Sous-total
          Expanded(
            flex: 4,
            child: Text(
              _currencyFmt.format(sousTotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: hasValue ? AppColors.secondary : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne total ──────────────────────────────────────────────────────────────

  Widget _buildTotalRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTAL PHYSIQUE',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            _currencyFmt.format(_totalPhysique),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge écart ──────────────────────────────────────────────────────────────

  Widget _buildEcartBadge() {
    final ecart = _ecart;

    // Couleur selon le signe de l'écart
    final Color color;
    final IconData icon;
    final String label;

    if (ecart == 0) {
      color = AppColors.success;
      icon = Icons.check_circle_outline_rounded;
      label = 'Aucun écart — solde physique conforme';
    } else if (ecart < 0) {
      color = AppColors.error;
      icon = Icons.warning_amber_rounded;
      label =
          'MANQUANT : ${_currencyFmt.format(ecart.abs())} (solde théorique : ${_currencyFmt.format(widget.soldeTheorique)})';
    } else {
      color = AppColors.warning;
      icon = Icons.info_outline_rounded;
      label =
          'EXCÉDENT : +${_currencyFmt.format(ecart)} (solde théorique : ${_currencyFmt.format(widget.soldeTheorique)})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context) {
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
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, _totalPhysique),
            icon: const Icon(Icons.check_rounded),
            label: const Text(
              'VALIDER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
