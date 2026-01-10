// lib/screens/comptabilite/etats_financiers/etats_financiers_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/financial_statements_service.dart';
import '../../../models/financial_statements/bilan_model.dart';
import '../../../models/financial_statements/compte_resultat_model.dart';
import '../../../models/financial_statements/flux_tresorerie_model.dart';
import '../../../core/theme/app_colors.dart';

class EtatsFinanciersPage extends StatefulWidget {
  const EtatsFinanciersPage({super.key});

  @override
  State<EtatsFinanciersPage> createState() => _EtatsFinanciersPageState();
}

class _EtatsFinanciersPageState extends State<EtatsFinanciersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FinancialStatementsService _service = FinancialStatementsService();
  final currencyFormat = NumberFormat.currency(
    symbol: 'FCFA',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  DateTime _dateDebut = DateTime(DateTime.now().year, 1, 1);
  DateTime _dateFin = DateTime.now();
  bool _isLoading = false;

  Bilan? _bilan;
  CompteResultat? _compteResultat;
  TableauFlux? _tableauFlux;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final bilan = await _service.generateBilan(dateFin: _dateFin);
      final cr = await _service.generateCompteResultat(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      final flux = await _service.generateTableauFlux(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      setState(() {
        _bilan = bilan;
        _compteResultat = cr;
        _tableauFlux = flux;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _resetDates() {
    _setQuickFilter('year');
  }

  void _setQuickFilter(String type) {
    final now = DateTime.now();
    setState(() {
      switch (type) {
        case 'today':
          _dateDebut = DateTime(now.year, now.month, now.day);
          _dateFin = now;
          break;
        case 'month':
          _dateDebut = DateTime(now.year, now.month, 1);
          _dateFin = now;
          break;
        case 'quarter':
          int quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
          _dateDebut = DateTime(now.year, quarterMonth, 1);
          _dateFin = now;
          break;
        case 'year':
          _dateDebut = DateTime(now.year, 1, 1);
          _dateFin = now;
          break;
        case 'last_month':
          _dateDebut = DateTime(now.year, now.month - 1, 1);
          _dateFin = DateTime(now.year, now.month, 0);
          break;
      }
    });
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('États financiers'),
        elevation: 0,
        backgroundColor: bgColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Changer la période',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetDates,
            tooltip: 'Réinitialiser la période',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filtres rapides',
            onSelected: _setQuickFilter,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('Aujourd\'hui')),
              const PopupMenuItem(value: 'month', child: Text('Ce mois')),
              const PopupMenuItem(
                value: 'quarter',
                child: Text('Trimestre en cours'),
              ),
              const PopupMenuItem(value: 'year', child: Text('Année en cours')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'last_month',
                child: Text('Mois dernier'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {},
            tooltip: 'Exporter PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      tabs: const [
                        Tab(
                          text: 'Bilan',
                          icon: Icon(Icons.account_balance_rounded, size: 20),
                        ),
                        Tab(
                          text: 'Compte de résultat',
                          icon: Icon(Icons.analytics_rounded, size: 20),
                        ),
                        Tab(
                          text: 'Flux de trésorerie',
                          icon: Icon(Icons.payments_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBilanTab(),
                      _buildCompteResultatTab(),
                      _buildFluxTresorerieTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBilanTab() {
    if (_bilan == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodInfo(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ACTIF
              Expanded(
                child: _buildStatementCard(
                  'ACTIF',
                  [
                    _buildRow(
                      'Actif immobilisé',
                      _bilan!.actif.actifImmobilise,
                    ),
                    _buildRow('Actif circulant', _bilan!.actif.actifCirculant),
                    _buildRow(
                      'Portefeuille crédits',
                      _bilan!.actif.portefeuilleCredits,
                      isBold: true,
                      color: Colors.blue,
                    ),
                    _buildRow(
                      'Provisions créances',
                      _bilan!.actif.provisionsCreances,
                    ),
                    _buildRow(
                      'Trésorerie',
                      _bilan!.actif.tresorerie,
                      isBold: true,
                      color: Colors.green,
                    ),
                    _buildRow('Autres actifs', _bilan!.actif.autresActifs),
                  ],
                  _bilan!.actif.totalActif,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 24),
              // PASSIF
              Expanded(
                child: _buildStatementCard(
                  'PASSIF',
                  [
                    _buildRow(
                      'Capitaux propres',
                      _bilan!.passif.capitauxPropres,
                      isBold: true,
                    ),
                    _buildRow(
                      'Dettes financières',
                      _bilan!.passif.dettesFinancieres,
                    ),
                    _buildRow(
                      'Épargne clientèle',
                      _bilan!.passif.epargneClientele,
                      isBold: true,
                      color: Colors.orange,
                    ),
                    _buildRow('Autres dettes', _bilan!.passif.autresDettes),
                  ],
                  _bilan!.passif.totalPassif,
                  Colors.orange,
                ),
              ),
            ],
          ),
          if (!_bilan!.isBalanced)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Déséquilibre détecté : ${currencyFormat.format(_bilan!.difference)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompteResultatTab() {
    if (_compteResultat == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildPeriodInfo(),
          const SizedBox(height: 24),
          _buildStatementCard(
            'PRODUITS D\'EXPLOITATION',
            [
              _buildRow(
                'Intérêts sur prêts',
                _compteResultat!.produits.interetsPrets,
              ),
              _buildRow('Commissions', _compteResultat!.produits.commissions),
              _buildRow('Pénalités', _compteResultat!.produits.penalites),
              _buildRow(
                'Autres produits',
                _compteResultat!.produits.autresProduits,
              ),
            ],
            _compteResultat!.produits.totalProduits,
            Colors.green,
          ),
          const SizedBox(height: 24),
          _buildStatementCard(
            'CHARGES D\'EXPLOITATION',
            [
              _buildRow(
                'Intérêts sur épargne',
                _compteResultat!.charges.interetsEpargne,
              ),
              _buildRow(
                'Charges personnel',
                _compteResultat!.charges.chargesPersonnel,
              ),
              _buildRow(
                'Charges fonctionnement',
                _compteResultat!.charges.chargesFonctionnement,
              ),
              _buildRow(
                'Dotations provisions',
                _compteResultat!.charges.dotationsProvisions,
              ),
              _buildRow(
                'Autres charges',
                _compteResultat!.charges.autresCharges,
              ),
            ],
            _compteResultat!.charges.totalCharges,
            Colors.red,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _compteResultat!.isProfitable
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _compteResultat!.isProfitable
                    ? Colors.green
                    : Colors.red,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RÉSULTAT NET',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _compteResultat!.isProfitable
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                Text(
                  currencyFormat.format(_compteResultat!.resultatNet),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _compteResultat!.isProfitable
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluxTresorerieTab() {
    if (_tableauFlux == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildPeriodInfo(),
          const SizedBox(height: 24),
          _buildStatementCard(
            'FLUX OPÉRATIONNELS',
            [
              _buildRow(
                'Encaissements clients',
                _tableauFlux!.fluxOperationnels.encaissementsClients,
              ),
              _buildRow(
                'Décaissements prêts',
                -_tableauFlux!.fluxOperationnels.decaissementsPrets,
              ),
              _buildRow(
                'Dépôts épargne',
                _tableauFlux!.fluxOperationnels.depotsEpargne,
              ),
              _buildRow(
                'Retraits épargne',
                -_tableauFlux!.fluxOperationnels.retraitsEpargne,
              ),
              _buildRow(
                'Autres flux',
                _tableauFlux!.fluxOperationnels.autresFluxOperationnels,
              ),
            ],
            _tableauFlux!.fluxOperationnels.totalFluxOperationnels,
            Colors.blue,
          ),
          const SizedBox(height: 32),
          _buildSummaryRow(
            'Trésorerie au début',
            _tableauFlux!.tresorerieDebut,
          ),
          _buildSummaryRow(
            'Variation de trésorerie',
            _tableauFlux!.variationTresorerie,
            isBold: true,
            color: Colors.blue,
          ),
          const Divider(height: 32),
          _buildSummaryRow(
            'Trésorerie à la fin',
            _tableauFlux!.tresorerieFin,
            isBold: true,
            fontSize: 24,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Text(
            'Période du ${DateFormat('dd/MM/yyyy').format(_dateDebut)} au ${DateFormat('dd/MM/yyyy').format(_dateFin)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementCard(
    String title,
    List<Widget> children,
    double total,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  currencyFormat.format(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    double fontSize = 16,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.normal,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _dateDebut, end: _dateFin),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dateDebut = picked.start;
        _dateFin = picked.end;
      });
      _loadAll();
    }
  }
}
