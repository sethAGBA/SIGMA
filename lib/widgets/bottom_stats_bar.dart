// lib/widgets/bottom_stats_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/notifiers/dashboard_notifier.dart';
import '../core/theme/app_colors.dart';

class BottomStatsBar extends StatelessWidget {
  const BottomStatsBar({super.key});

  /// Formate une valeur FCFA :
  /// ≥ 1 000 000 → 'X.XX M', ≥ 1 000 → 'X K', sinon entier.
  String _formatFcfa(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)} M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)} K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardNotifier>(
      builder: (context, notifier, _) {
        final data = notifier.cachedData;

        final encours = data != null ? _formatFcfa(data.encours) : '--';
        final collecte = data != null ? _formatFcfa(data.collecteJour) : '--';
        final par = data != null ? '${data.par30.toStringAsFixed(1)}%' : '--';

        final theme = Theme.of(context);

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border:
                Border(top: BorderSide(color: theme.dividerColor, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildStatChip(
                context,
                'Encours Total',
                encours,
                Icons.account_balance_wallet_rounded,
                AppColors.primary,
              ),
              _buildStatChip(
                context,
                'Collecte Jour',
                collecte,
                Icons.analytics_rounded,
                AppColors.secondary,
              ),
              _buildStatChip(
                context,
                'PAR > 30j',
                par,
                Icons.trending_up_rounded,
                AppColors.warning,
              ),
              const Spacer(),
              _buildSyncIndicator(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.success),
          SizedBox(width: 8),
          Text(
            'Synchronisé',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
