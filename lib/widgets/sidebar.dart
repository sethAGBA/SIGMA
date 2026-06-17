// lib/widgets/sidebar.dart

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/theme_service.dart';
import '../core/services/auth_service.dart';
import '../models/user_model.dart';
import '../screens/auth/login_page.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildNavItem(
                  context,
                  0,
                  Icons.dashboard_rounded,
                  'Tableau de Bord',
                ),

                _buildSectionTitle(context, 'GESTION CLIENTS'),
                _buildNavItem(
                  context,
                  1,
                  Icons.people_rounded,
                  'Registre des clients',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  2,
                  Icons.groups_rounded,
                  'Groupes solidaires',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  3,
                  Icons.person_add_rounded,
                  'Nouveau client',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'PORTEFEUILLE CRÉDIT'),
                _buildNavItem(
                  context,
                  4,
                  Icons.request_page_rounded,
                  'Demandes de prêt',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  5,
                  Icons.account_balance_wallet_rounded,
                  'Prêts en cours',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  6,
                  Icons.calendar_month_rounded,
                  'Échéancier global',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  7,
                  Icons.sync_rounded,
                  'Restructurations',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'REMBOURSEMENTS'),
                _buildNavItem(
                  context,
                  8,
                  Icons.payments_rounded,
                  'Collecte du jour',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  9,
                  Icons.history_rounded,
                  'Historique paiements',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  10,
                  Icons.warning_rounded,
                  'Retards & relances',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'ÉPARGNE'),
                _buildNavItem(
                  context,
                  11,
                  Icons.savings_rounded,
                  'Comptes épargne',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  12,
                  Icons.swap_horiz_rounded,
                  'Transactions épargne',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  13,
                  Icons.category_rounded,
                  'Produits d\'épargne',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'CAISSE & TRÉSORERIE'),
                _buildNavItem(
                  context,
                  14,
                  Icons.point_of_sale_rounded,
                  'Opérations de caisse',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  15,
                  Icons.lock_clock_rounded,
                  'Clôture journalière',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  16,
                  Icons.compare_arrows_rounded,
                  'Transferts inter-agences',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  17,
                  Icons.shield,
                  'Coffre-fort',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'QUALITÉ PORTEFEUILLE'),
                _buildNavItem(
                  context,
                  18,
                  Icons.analytics_rounded,
                  'Tableau PAR',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  19,
                  Icons.error_outline_rounded,
                  'Créances en souffrance',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  20,
                  Icons.gavel_rounded,
                  'Actions de recouvrement',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  21,
                  Icons.shield_rounded,
                  'Provisions',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'COMPTABILITÉ'),
                _buildNavItem(
                  context,
                  22,
                  Icons.account_tree_rounded,
                  'Plan comptable',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  23,
                  Icons.book_rounded,
                  'Journal des écritures',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  24,
                  Icons.library_books_rounded,
                  'Grand livre',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  25,
                  Icons.balance_rounded,
                  'Balance',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  26,
                  Icons.description_rounded,
                  'États financiers',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  27,
                  Icons.lock_reset_rounded,
                  'Clôture & fin de période',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'REPORTING'),
                _buildNavItem(
                  context,
                  28,
                  Icons.pie_chart_rounded,
                  'Tableaux de bord',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  29,
                  Icons.article_rounded,
                  'Rapports standards',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  30,
                  Icons.download_rounded,
                  'Exports',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'AGENCES & ÉQUIPES'),
                _buildNavItem(
                  context,
                  31,
                  Icons.store_rounded,
                  'Réseau d\'agences',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  32,
                  Icons.badge_rounded,
                  'Gestion des agents',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  33,
                  Icons.trending_up_rounded,
                  'Performance équipes',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'COMMUNICATIONS'),
                _buildNavItem(
                  context,
                  34,
                  Icons.sms_rounded,
                  'Envoi SMS',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  35,
                  Icons.notifications_rounded,
                  'Historique notifications',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  36,
                  Icons.message_rounded,
                  'Templates messages',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'DOCUMENTS'),
                _buildNavItem(
                  context,
                  37,
                  Icons.folder_rounded,
                  'Bibliothèque documents',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  38,
                  Icons.description_rounded,
                  'Contrats types',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  39,
                  Icons.verified_rounded,
                  'Attestations',
                  isSubItem: true,
                ),

                _buildSectionTitle(context, 'PARAMÈTRES'),
                _buildNavItem(
                  context,
                  40,
                  Icons.settings_rounded,
                  'Configuration Institution',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  41,
                  Icons.account_tree_rounded,
                  'Configuration Comptable',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  42,
                  Icons.inventory_rounded,
                  'Produits financiers',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  43,
                  Icons.admin_panel_settings_rounded,
                  'Utilisateurs & droits',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  44,
                  Icons.backup_rounded,
                  'Sauvegarde & sécurité',
                  isSubItem: true,
                ),
                _buildNavItem(
                  context,
                  45,
                  Icons.dns_rounded,
                  'Serveur & Connexion',
                  isSubItem: true,
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildThemeToggle(context),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final auth = AuthService();
    final user = auth.currentUser;

    // Initiales et nom depuis la session
    final initials = auth.userInitials;
    final username = user?.username ?? 'Utilisateur';
    final roleLabel = user?.role.label ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIGMA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Micro-Finance Manager',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor, width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label, {
    bool isSubItem = false,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;

    return Padding(
      padding: EdgeInsets.only(bottom: 4.0, left: isSubItem ? 8.0 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isSubItem ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.08)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withOpacity(
                          isSubItem ? 0.7 : 1,
                        ),
                  size: isSubItem ? 18 : 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isSubItem ? 13 : 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : (isSubItem ? FontWeight.w400 : FontWeight.w500),
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withOpacity(
                              isSubItem ? 0.8 : 1,
                            ),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final themeService = ThemeService();
    final isDark = themeService.isDarkMode;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () => themeService.toggleTheme(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? Colors.amber : Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDark ? 'Mode Sombre' : 'Mode Clair',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isDark,
                  onChanged: (_) => themeService.toggleTheme(),
                  activeColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: _buildFooterAction(
              context,
              Icons.logout_rounded,
              'Déconnexion',
              isDestructive: true,
              onTap: () => _handleLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  Widget _buildFooterAction(
    BuildContext context,
    IconData icon,
    String label, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final color = isDestructive
        ? AppColors.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
