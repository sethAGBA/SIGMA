// lib/screens/reporting/reports_catalog_page.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'custom_report_page.dart';

class ReportItem {
  final String title;
  final String description;
  final IconData icon;

  ReportItem({
    required this.title,
    required this.description,
    this.icon = Icons.description_outlined,
  });
}

class ReportCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<ReportItem> reports;

  ReportCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.reports,
  });
}

class ReportsCatalogPage extends StatelessWidget {
  const ReportsCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = [
      ReportCategory(
        title: 'Rapports opérationnels',
        icon: Icons.assignment_rounded,
        color: Colors.blue,
        reports: [
          ReportItem(
            title: 'Rapport journalier d\'activité',
            description: 'Résumé des transactions et activités du jour.',
          ),
          ReportItem(
            title: 'Situation hebdomadaire',
            description: 'Évolution des indicateurs sur la semaine.',
          ),
          ReportItem(
            title: 'Rapport mensuel complet',
            description: 'Bilan de performance mensuel détaillé.',
          ),
          ReportItem(
            title: 'Rapport trimestriel direction',
            description: 'Synthèse stratégique pour le comité.',
          ),
          ReportItem(
            title: 'Rapport annuel',
            description: 'Audit et performance de l\'exercice complet.',
          ),
        ],
      ),
      ReportCategory(
        title: 'Rapports portefeuille',
        icon: Icons.pie_chart_rounded,
        color: Colors.orange,
        reports: [
          ReportItem(
            title: 'État du portefeuille',
            description: 'Volume, nombre de prêts et encours par agence.',
          ),
          ReportItem(
            title: 'Analyse PAR détaillée',
            description: 'Segmentation fine du risque par jours de retard.',
          ),
          ReportItem(
            title: 'Suivi remboursements',
            description: 'Taux de recouvrement et prévisions des flux.',
          ),
          ReportItem(
            title: 'Performances agents',
            description: 'Productivité et qualité de portefeuille par agent.',
          ),
          ReportItem(
            title: 'Analyse par produit',
            description: 'Rentabilité et volume par type de crédit.',
          ),
        ],
      ),
      ReportCategory(
        title: 'Rapports financiers',
        icon: Icons.account_balance_rounded,
        color: Colors.green,
        reports: [
          ReportItem(
            title: 'Situation comptable',
            description: 'Balance, Grand Livre et Journaux.',
          ),
          ReportItem(
            title: 'États financiers',
            description: 'Bilan et compte de résultat.',
          ),
          ReportItem(
            title: 'Analyse rentabilité',
            description: 'Calcul des marges et efficience opérationnelle.',
          ),
          ReportItem(
            title: 'Suivi budget',
            description: 'Comparaison réalisation vs prévisions.',
          ),
          ReportItem(
            title: 'Prévisions trésorerie',
            description: 'Flux de fonds et liquidités à venir.',
          ),
        ],
      ),
      ReportCategory(
        title: 'Rapports réglementaires',
        icon: Icons.gavel_rounded,
        color: Colors.purple,
        reports: [
          ReportItem(
            title: 'Déclaration autorité tutelle',
            description: 'Rapports périodiques conformes BCEAO/OHADA.',
          ),
          ReportItem(
            title: 'Statistiques centrale risques',
            description: 'Positions des clients par rapport au risque global.',
          ),
          ReportItem(
            title: 'Rapports audit',
            description: 'Contrôles internes et conformité procédures.',
          ),
          ReportItem(
            title: 'Conformité réglementaire',
            description: 'Vérification des ratios prudentiels.',
          ),
        ],
      ),
      ReportCategory(
        title: 'Rapports bailleurs',
        icon: Icons.handshake_rounded,
        color: Colors.teal,
        reports: [
          ReportItem(
            title: 'Indicateurs de performance',
            description: 'KPIs financiers et opérationnels pour investisseurs.',
          ),
          ReportItem(
            title: 'Impact social',
            description:
                'Mesure de l\'impact sur le niveau de vie des clients.',
          ),
          ReportItem(
            title: 'Utilisation fonds',
            description: 'Traçabilité de l\'emploi des ressources affectées.',
          ),
          ReportItem(
            title: 'Rapports narratifs',
            description: 'Évolutions qualitatives et témoignages de succès.',
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark, context),
            const SizedBox(height: 40),
            _buildGrid(categories, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.article_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rapports Standards',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Accédez à l\'ensemble des états périodiques, financiers et réglementaires.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const CustomReportPage(),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nouveau rapport personnalisé'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<ReportCategory> categories, bool isDark) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: categories
          .map((cat) => _buildCategoryCard(cat, isDark))
          .toList(),
    );
  }

  Widget _buildCategoryCard(ReportCategory category, bool isDark) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(category.icon, color: category.color, size: 28),
                const SizedBox(width: 16),
                Text(
                  category.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: category.reports
                  .map(
                    (report) =>
                        _buildReportListItem(report, category.color, isDark),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportListItem(ReportItem report, Color color, bool isDark) {
    return InkWell(
      onTap: () {
        // Logique de génération de rapport
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                report.icon,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    report.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}
