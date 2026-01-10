import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
import '../widgets/bottom_stats_bar.dart';
import 'clients/client_list_page.dart';
import 'groupes/group_list_page.dart';
import '../widgets/dialogs/client_form_dialog.dart';
import 'dashboard/dashboard_page.dart';
import 'produits/product_list_page.dart';
import 'prets/loan_request_list_page.dart';
import 'prets/loan_list_page.dart';
import 'remboursements/daily_collection_page.dart';
import 'remboursements/repayment_history_page.dart';
import 'prets/global_schedule_page.dart';
import 'prets/restructuring_list_page.dart';
import 'epargne/savings_list_page.dart';
import 'epargne/global_savings_transactions_page.dart';
import 'caisse/cash_ledger_page.dart';
import 'caisse/cash_closing_list_page.dart';
import 'caisse/cash_transfer_list_page.dart';
import 'caisse/vault_management_page.dart';
import 'comptabilite/plan_comptable_page.dart';
import 'comptabilite/saisie_comptable_page.dart';
import 'comptabilite/grand_livre_page.dart';
import 'comptabilite/balance_generale_page.dart';
import 'comptabilite/etats_financiers/etats_financiers_page.dart';
import 'comptabilite/cloture_periode_page.dart';
import 'reporting/par_dashboard_page.dart';
import 'reporting/delinquent_loans_list_page.dart';
import 'reporting/recovery_actions_page.dart';
import 'reporting/executive_dashboard_page.dart';
import 'prets/provisions_page.dart';
import 'reporting/reports_catalog_page.dart';
import 'reporting/data_export_page.dart';
import 'configuration/general_configuration_page.dart';
import 'agencies/agency_list_page.dart';
import 'agents/agent_list_page.dart';
import 'agents/team_performance_page.dart';
import 'communications/sms_sending_page.dart';
import 'communications/notification_history_page.dart';
import 'communications/message_templates_page.dart';
import 'configuration/institution_configuration_page.dart';
import 'documents/document_library_page.dart';
import 'documents/contract_templates_page.dart';
import 'documents/attestations_page.dart';
import 'configuration/users_rights_page.dart';
import 'configuration/security_audit_page.dart';
import '../core/theme/app_colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0; // Default to Dashboard

  final List<Widget> _pages = [
    const DashboardPage(), // Index 0: Dashboard
    const ClientListPage(), // Index 1: Registre des clients
    const GroupListPage(), // Index 2: Groupes solidaires
    const Center(
      child: Text('Dialog Nouveau Client'),
    ), // Index 3: Placeholder (ouvert via Dialog)
    const LoanRequestListPage(), // Index 4: Demandes de prêt
    const LoanListPage(), // Index 5: Prêts en cours
    const GlobalSchedulePage(), // Index 6: Échéancier global
    const RestructuringListPage(), // Index 7: Restructurations
    const DailyCollectionPage(), // Index 8: Collecte du jour
    const RepaymentHistoryPage(), // Index 9: Historique paiements
    const DelinquentLoansListPage(), // Index 10: Retards & relances
    const SavingsListPage(), // Index 11: Comptes épargne
    const GlobalSavingsTransactionsPage(), // Index 12: Transactions épargne
    const ProductListPage(), // Index 13: Produits d'épargne
    const CashLedgerPage(), // Index 14: Opérations de caisse
    const CashClosingListPage(), // Index 15: Clôture journalière
    const CashTransferListPage(), // Index 16: Transferts inter-agences
    const VaultManagementPage(), // Index 17: Coffre-fort
    const PARDashboardPage(), // Index 18: Tableau PAR
    const DelinquentLoansListPage(), // Index 19: Créances en souffrance
    const RecoveryActionsPage(), // Index 20: Actions de recouvrement
    const ProvisionsPage(), // Index 21: Provisions
    const PlanComptablePage(), // Index 22: Plan comptable
    const SaisieComptablePage(), // Index 23: Journal des écritures
    const GrandLivrePage(), // Index 24: Grand livre
    const BalanceGeneralePage(), // Index 25: Balance
    const EtatsFinanciersPage(), // Index 26: États financiers
    const CloturePeriodePage(), // Index 27: Clôture de période
    const ExecutiveDashboardPage(), // Index 28: Tableau de bord direction
    const ReportsCatalogPage(), // Index 29: Rapports standards
    const DataExportPage(), // Index 30: Exports
    const AgencyListPage(), // Index 31: Réseau d'agences (Ex-32)
    const AgentListPage(), // Index 32: Gestion des agents
    const TeamPerformancePage(), // Index 33: Performance équipes
    const SmsSendingPage(), // Index 34: Envoi SMS
    const NotificationHistoryPage(), // Index 35: Historique notifications
    const MessageTemplatesPage(), // Index 36: Templates messages
    const DocumentLibraryPage(), // Index 37: Bibliothèque documents
    const ContractTemplatesPage(), // Index 38: Contrats types
    const AttestationsPage(), // Index 39: Attestations
    const InstitutionConfigurationPage(), // Index 40: Configuration Institution
    const GeneralConfigurationPage(), // Index 41: Configuration Comptable (Moved from 40)
    const ProductListPage(), // Index 42: Produits financiers (Ex-42)
    const UsersRightsPage(), // Index 43: Utilisateurs & droits
    const SecurityAuditPage(), // Index 44: Sauvegarde & sécurité
  ];

  final List<String> _titles = [
    'Tableau de Bord',
    'Registre des clients',
    'Groupes solidaires',
    'Nouveau client',
    'Demandes de prêt',
    'Prêts en cours',
    'Échéancier global',
    'Restructurations',
    'Collecte du jour',
    'Historique paiements',
    'Retards & relances',
    'Comptes épargne',
    'Transactions épargne',
    'Produits d\'épargne',
    'Opérations de caisse',
    'Clôture journalière',
    'Transferts inter-agences',
    'Coffre-fort',
    'Tableau PAR',
    'Créances en souffrance',
    'Actions de recouvrement',
    'Provisions',
    'Plan comptable',
    'Journal des écritures',
    'Grand livre',
    'Balance',
    'États financiers',
    'Clôture & fin de période',
    'Tableaux de bord (Reporting)',
    'Rapports standards',
    // 'Rapports personnalisés', // Supprimé
    'Exports',
    'Réseau d\'agences',
    'Gestion des agents',
    'Performance équipes',
    'Envoi SMS',
    'Historique notifications',
    'Templates messages',
    'Bibliothèque documents',
    'Contrats types',
    'Attestations',
    'Configuration Institution',
    'Configuration Comptable',
    'Produits financiers',
    'Utilisateurs & droits',
    'Sauvegarde & sécurité',
  ];

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (index == 3) {
                // Ouvrir le dialogue Nouveau Client au lieu de naviguer
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const ClientFormDialog(),
                );
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
                const BottomStatsBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _titles[_selectedIndex],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          _buildActionButton(context, Icons.search_rounded, 'Rechercher'),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            Icons.notifications_none_rounded,
            'Alertes',
            badge: '3',
          ),
          const SizedBox(width: 24),
          _buildUserProfile(context),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String tooltip, {
    String? badge,
  }) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Jean KOUASSI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Agent de Crédit (CI-04)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary,
              child: const Text(
                'JK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
