// lib/widgets/sidebar_config.dart
//
// Structure déclarative de la Sidebar — Phase 1 RBAC.

import 'package:flutter/material.dart';
import '../models/sidebar_module.dart';

class SidebarEntry {
  final int index;
  final IconData icon;
  final String label;
  final SidebarModule module;
  final bool isSubItem;

  const SidebarEntry({
    required this.index,
    required this.icon,
    required this.label,
    required this.module,
    this.isSubItem = true,
  });
}

class SidebarSection {
  final String? title;
  final List<SidebarEntry> entries;

  const SidebarSection({this.title, required this.entries});
}

/// Entrée dashboard (sans titre de section).
const SidebarEntry kDashboardEntry = SidebarEntry(
  index: 0,
  icon: Icons.dashboard_rounded,
  label: 'Tableau de Bord',
  module: SidebarModule.dashboard,
  isSubItem: false,
);

const List<SidebarSection> kAllSidebarSections = [
  SidebarSection(
    title: 'GESTION CLIENTS',
    entries: [
      SidebarEntry(
        index: 1,
        icon: Icons.people_rounded,
        label: 'Registre des clients',
        module: SidebarModule.clients,
      ),
      SidebarEntry(
        index: 2,
        icon: Icons.groups_rounded,
        label: 'Groupes solidaires',
        module: SidebarModule.groupesSolidaires,
      ),
      SidebarEntry(
        index: 3,
        icon: Icons.person_add_rounded,
        label: 'Nouveau client',
        module: SidebarModule.clients,
      ),
    ],
  ),
  SidebarSection(
    title: 'PORTEFEUILLE CRÉDIT',
    entries: [
      SidebarEntry(
        index: 4,
        icon: Icons.request_page_rounded,
        label: 'Demandes de prêt',
        module: SidebarModule.prets,
      ),
      SidebarEntry(
        index: 5,
        icon: Icons.account_balance_wallet_rounded,
        label: 'Prêts en cours',
        module: SidebarModule.prets,
      ),
      SidebarEntry(
        index: 6,
        icon: Icons.calendar_month_rounded,
        label: 'Échéancier global',
        module: SidebarModule.prets,
      ),
      SidebarEntry(
        index: 7,
        icon: Icons.sync_rounded,
        label: 'Restructurations',
        module: SidebarModule.prets,
      ),
    ],
  ),
  SidebarSection(
    title: 'REMBOURSEMENTS',
    entries: [
      SidebarEntry(
        index: 8,
        icon: Icons.payments_rounded,
        label: 'Collecte du jour',
        module: SidebarModule.remboursements,
      ),
      SidebarEntry(
        index: 9,
        icon: Icons.history_rounded,
        label: 'Historique paiements',
        module: SidebarModule.remboursements,
      ),
      SidebarEntry(
        index: 10,
        icon: Icons.warning_rounded,
        label: 'Retards & relances',
        module: SidebarModule.remboursements,
      ),
    ],
  ),
  SidebarSection(
    title: 'ÉPARGNE',
    entries: [
      SidebarEntry(
        index: 11,
        icon: Icons.savings_rounded,
        label: 'Comptes épargne',
        module: SidebarModule.epargne,
      ),
      SidebarEntry(
        index: 12,
        icon: Icons.swap_horiz_rounded,
        label: 'Transactions épargne',
        module: SidebarModule.epargne,
      ),
      SidebarEntry(
        index: 13,
        icon: Icons.category_rounded,
        label: 'Produits d\'épargne',
        module: SidebarModule.epargne,
      ),
    ],
  ),
  SidebarSection(
    title: 'CAISSE & TRÉSORERIE',
    entries: [
      SidebarEntry(
        index: 14,
        icon: Icons.point_of_sale_rounded,
        label: 'Opérations de caisse',
        module: SidebarModule.caisse,
      ),
      SidebarEntry(
        index: 15,
        icon: Icons.lock_clock_rounded,
        label: 'Clôture journalière',
        module: SidebarModule.caisse,
      ),
      SidebarEntry(
        index: 16,
        icon: Icons.compare_arrows_rounded,
        label: 'Transferts inter-agences',
        module: SidebarModule.caisse,
      ),
      SidebarEntry(
        index: 17,
        icon: Icons.shield,
        label: 'Coffre-fort',
        module: SidebarModule.caisse,
      ),
    ],
  ),
  SidebarSection(
    title: 'QUALITÉ PORTEFEUILLE',
    entries: [
      SidebarEntry(
        index: 18,
        icon: Icons.analytics_rounded,
        label: 'Tableau PAR',
        module: SidebarModule.reporting,
      ),
      SidebarEntry(
        index: 19,
        icon: Icons.error_outline_rounded,
        label: 'Créances en souffrance',
        module: SidebarModule.reporting,
      ),
      SidebarEntry(
        index: 20,
        icon: Icons.gavel_rounded,
        label: 'Actions de recouvrement',
        module: SidebarModule.reporting,
      ),
      SidebarEntry(
        index: 21,
        icon: Icons.shield_rounded,
        label: 'Provisions',
        module: SidebarModule.reporting,
      ),
    ],
  ),
  SidebarSection(
    title: 'COMPTABILITÉ',
    entries: [
      SidebarEntry(
        index: 22,
        icon: Icons.account_tree_rounded,
        label: 'Plan comptable',
        module: SidebarModule.comptabilite,
      ),
      SidebarEntry(
        index: 23,
        icon: Icons.book_rounded,
        label: 'Journal des écritures',
        module: SidebarModule.comptabilite,
      ),
      SidebarEntry(
        index: 24,
        icon: Icons.library_books_rounded,
        label: 'Grand livre',
        module: SidebarModule.comptabilite,
      ),
      SidebarEntry(
        index: 25,
        icon: Icons.balance_rounded,
        label: 'Balance',
        module: SidebarModule.comptabilite,
      ),
      SidebarEntry(
        index: 26,
        icon: Icons.description_rounded,
        label: 'États financiers',
        module: SidebarModule.comptabilite,
      ),
      SidebarEntry(
        index: 27,
        icon: Icons.lock_reset_rounded,
        label: 'Clôture & fin de période',
        module: SidebarModule.comptabilite,
      ),
    ],
  ),
  SidebarSection(
    title: 'REPORTING',
    entries: [
      SidebarEntry(
        index: 28,
        icon: Icons.pie_chart_rounded,
        label: 'Tableaux de bord',
        module: SidebarModule.reporting,
      ),
      SidebarEntry(
        index: 29,
        icon: Icons.article_rounded,
        label: 'Rapports standards',
        module: SidebarModule.reporting,
      ),
      SidebarEntry(
        index: 30,
        icon: Icons.download_rounded,
        label: 'Exports',
        module: SidebarModule.reporting,
      ),
    ],
  ),
  SidebarSection(
    title: 'AGENCES & ÉQUIPES',
    entries: [
      SidebarEntry(
        index: 31,
        icon: Icons.store_rounded,
        label: 'Réseau d\'agences',
        module: SidebarModule.agencesAgents,
      ),
      SidebarEntry(
        index: 32,
        icon: Icons.badge_rounded,
        label: 'Gestion des agents',
        module: SidebarModule.agencesAgents,
      ),
      SidebarEntry(
        index: 33,
        icon: Icons.trending_up_rounded,
        label: 'Performance équipes',
        module: SidebarModule.agencesAgents,
      ),
    ],
  ),
  SidebarSection(
    title: 'COMMUNICATIONS',
    entries: [
      SidebarEntry(
        index: 34,
        icon: Icons.sms_rounded,
        label: 'Envoi SMS',
        module: SidebarModule.communications,
      ),
      SidebarEntry(
        index: 35,
        icon: Icons.notifications_rounded,
        label: 'Historique notifications',
        module: SidebarModule.communications,
      ),
      SidebarEntry(
        index: 36,
        icon: Icons.message_rounded,
        label: 'Templates messages',
        module: SidebarModule.communications,
      ),
    ],
  ),
  SidebarSection(
    title: 'DOCUMENTS',
    entries: [
      SidebarEntry(
        index: 37,
        icon: Icons.folder_rounded,
        label: 'Bibliothèque documents',
        module: SidebarModule.documents,
      ),
      SidebarEntry(
        index: 38,
        icon: Icons.description_rounded,
        label: 'Contrats types',
        module: SidebarModule.documents,
      ),
      SidebarEntry(
        index: 39,
        icon: Icons.verified_rounded,
        label: 'Attestations',
        module: SidebarModule.documents,
      ),
    ],
  ),
  SidebarSection(
    title: 'PARAMÈTRES',
    entries: [
      SidebarEntry(
        index: 40,
        icon: Icons.settings_rounded,
        label: 'Configuration Institution',
        module: SidebarModule.configuration,
      ),
      SidebarEntry(
        index: 41,
        icon: Icons.account_tree_rounded,
        label: 'Configuration Comptable',
        module: SidebarModule.configuration,
      ),
      SidebarEntry(
        index: 42,
        icon: Icons.inventory_rounded,
        label: 'Produits financiers',
        module: SidebarModule.configuration,
      ),
      SidebarEntry(
        index: 43,
        icon: Icons.admin_panel_settings_rounded,
        label: 'Utilisateurs & droits',
        module: SidebarModule.utilisateursDroits,
      ),
      SidebarEntry(
        index: 44,
        icon: Icons.backup_rounded,
        label: 'Sauvegarde & sécurité',
        module: SidebarModule.securiteAudit,
      ),
      SidebarEntry(
        index: 45,
        icon: Icons.dns_rounded,
        label: 'Serveur & Connexion',
        module: SidebarModule.serveurConnexion,
      ),
    ],
  ),
];
