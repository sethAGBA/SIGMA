// lib/screens/prets/loan_request_detail_dialog.dart

import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/loan_request_model.dart';
import '../../models/loan_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/loan_calculator.dart';
import '../../widgets/dialogs/pin_validation_dialog.dart';
import '../../core/services/pdf_export_service.dart';

class LoanRequestDetailDialog extends StatefulWidget {
  final LoanRequest request;

  const LoanRequestDetailDialog({super.key, required this.request});

  @override
  State<LoanRequestDetailDialog> createState() =>
      _LoanRequestDetailDialogState();
}

class _LoanRequestDetailDialogState extends State<LoanRequestDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _avisController = TextEditingController();
  final TextEditingController _motifRejetController = TextEditingController();
  late LoanRequestStatus _currentStatut;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _currentStatut = widget.request.statut;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _avisController.dispose();
    _motifRejetController.dispose();
    super.dispose();
  }

  Future<void> _saveDecision(
    LoanRequestStatus newStatus, {
    String? motif,
  }) async {
    // Dans une vraie app, on identifierait le rôle de l'utilisateur (Agent, Chef, Comité)
    // Ici on simule selon le workflow
    String? avisAgent = widget.request.avisAgent;
    String? avisChef = widget.request.avisChefAgence;
    String? avisComite = widget.request.avisComite;

    if (_currentStatut == LoanRequestStatus.soumise) {
      avisAgent = _avisController.text;
    } else if (_currentStatut == LoanRequestStatus.enAnalyse) {
      avisChef = _avisController.text;
    } else if (_currentStatut == LoanRequestStatus.enComite) {
      avisComite = _avisController.text;
    }

    final updatedRequest = LoanRequest(
      id: widget.request.id,
      clientId: widget.request.clientId,
      produitId: widget.request.produitId,
      montantDemande: widget.request.montantDemande,
      dureeMois: widget.request.dureeMois,
      frequenceRemboursement: widget.request.frequenceRemboursement,
      objetPret: widget.request.objetPret,
      mensualite: widget.request.mensualite,
      totalARembourser: widget.request.totalARembourser,
      coutTotalCredit: widget.request.coutTotalCredit,
      teg: widget.request.teg,
      revenusMensuels: widget.request.revenusMensuels,
      chargesMensuelles: widget.request.chargesMensuelles,
      autresDettes: widget.request.autresDettes,
      capaciteRemboursement: widget.request.capaciteRemboursement,
      tauxEffort: widget.request.tauxEffort,
      resteAVivre: widget.request.resteAVivre,
      typeGarantie: widget.request.typeGarantie,
      descriptionGarantie: widget.request.descriptionGarantie,
      valeurGarantie: widget.request.valeurGarantie,
      cautionPersonnelle: widget.request.cautionPersonnelle,
      rapportVisite: widget.request.rapportVisite,
      observationsVisite: widget.request.observationsVisite,
      photosVisite: widget.request.photosVisite,
      scoreCalcule: widget.request.scoreCalcule,
      recommandationSysteme: widget.request.recommandationSysteme,
      documentsDossier: widget.request.documentsDossier,
      avisAgent: avisAgent,
      avisChefAgence: avisChef,
      avisComite: avisComite,
      statut: newStatus,
      motifRejet: motif,
      dateCreation: widget.request.dateCreation,
      dateModification: DateTime.now(),
    );

    await DatabaseService().insertLoanRequest(updatedRequest);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1100,
        height: 850,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const Divider(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_shared, color: AppColors.primary, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dossier #${widget.request.id} - ${widget.request.client?.nomComplet ?? "Client"}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Soumis le ${_formatDate(widget.request.dateCreation)}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        _buildStatusBadge(_currentStatut),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primary,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.primary,
      tabs: const [
        Tab(text: 'Dossier', icon: Icon(Icons.info_outline)),
        Tab(text: 'Analyse CAP', icon: Icon(Icons.analytics_outlined)),
        Tab(text: 'Garanties', icon: Icon(Icons.security)),
        Tab(text: 'Rapport Terrain', icon: Icon(Icons.map_outlined)),
        Tab(text: 'Décision', icon: Icon(Icons.gavel)),
      ],
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDossierInfo(),
        _buildFinancialAnalysis(),
        _buildGuarantees(),
        _buildFieldVisit(),
        _buildDecisionPanel(),
      ],
    );
  }

  Widget _buildDossierInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations Client'),
          _buildInfoRow(
            'Numéro Client',
            widget.request.client?.numeroClient ?? '-',
          ),
          _buildInfoRow(
            'Nom complet',
            widget.request.client?.nomComplet ?? '-',
          ),
          _buildInfoRow('Téléphone', widget.request.client?.telephone ?? '-'),
          _buildInfoRow(
            'Agence / Agent',
            '${widget.request.client?.agence ?? "Centrale"} / ${widget.request.client?.agentAffecte ?? "Non affecté"}',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Produit & Simulation'),
          _buildInfoRow('Produit', widget.request.produit?.nom ?? '-'),
          _buildInfoRow(
            'Montant demandé',
            '${_formatAmount(widget.request.montantDemande)} FCFA',
          ),
          _buildInfoRow('Durée', '${widget.request.dureeMois} mois'),
          _buildInfoRow(
            'Mensualité',
            '${_formatAmount(widget.request.mensualite)} FCFA',
          ),
          _buildInfoRow(
            'Coût total',
            '${_formatAmount(widget.request.coutTotalCredit)} FCFA',
          ),
          _buildInfoRow('Objet du prêt', widget.request.objetPret),
        ],
      ),
    );
  }

  Widget _buildFinancialAnalysis() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Score Crédit',
                  '${widget.request.scoreCalcule} pts',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Taux d\'effort',
                  '${widget.request.tauxEffort.toStringAsFixed(1)}%',
                  widget.request.tauxEffort > 35 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Capacité Financière Mensuelle'),
          _buildInfoRow(
            'Revenus déclarés',
            '${_formatAmount(widget.request.revenusMensuels)} FCFA',
          ),
          _buildInfoRow(
            'Charges déclarées',
            '${_formatAmount(widget.request.chargesMensuelles)} FCFA',
          ),
          _buildInfoRow(
            'Autres dettes',
            '${_formatAmount(widget.request.autresDettes)} FCFA',
          ),
          const Divider(),
          _buildInfoRow(
            'Capacité de remboursement brute',
            '${_formatAmount(widget.request.capaciteRemboursement)} FCFA',
            isBold: true,
          ),
          _buildInfoRow(
            'Reste à vivre (après prêt)',
            '${_formatAmount(widget.request.resteAVivre)} FCFA',
            isBold: true,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Recommandation Système'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.request.recommandationSysteme ??
                        "Analyse automatique non disponible.",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuarantees() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Sûretés Enregistrées'),
          _buildInfoRow(
            'Type de garantie',
            widget.request.typeGarantie ?? 'Aucune',
          ),
          _buildInfoRow(
            'Valeur d\'expertise',
            '${_formatAmount(widget.request.valeurGarantie ?? 0)} FCFA',
          ),
          _buildInfoRow(
            'Désignation',
            widget.request.descriptionGarantie ?? '-',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Cautions Personnelles'),
          _buildInfoRow(
            'Nom de la caution',
            widget.request.cautionPersonnelle ?? 'Aucune',
          ),
        ],
      ),
    );
  }

  Widget _buildFieldVisit() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Observations de l\'Agent de Crédit'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              widget.request.observationsVisite ??
                  "Aucun rapport de visite saisi.",
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Localisation GPS'),
          Row(
            children: const [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Position certifiée par GPS (Mode Mobile)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Historique du Circuit'),
          _buildAvisCard(
            'Avis Agent Terrain',
            widget.request.avisAgent,
            Icons.person_outline,
          ),
          _buildAvisCard(
            'Avis Chef d\'Agence',
            widget.request.avisChefAgence,
            Icons.manage_accounts_outlined,
          ),
          _buildAvisCard(
            'Comité de Crédit',
            widget.request.avisComite,
            Icons.groups_outlined,
          ),
          const SizedBox(height: 32),
          if (_canDecide()) ...[
            _buildSectionTitle('Prendre une Décision'),
            TextField(
              controller: _avisController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Saisissez votre avis motivé ici...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRejetDialog(),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'Rejeter Dossier',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _saveDecision(_getNextStatus()),
                  icon: const Icon(Icons.check),
                  label: Text(_getDecisionButtonLabel()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_currentStatut == LoanRequestStatus.approuvee) ...[
            _buildSectionTitle('Prêt Approuvé'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Le dossier a été approuvé par toutes les instances. Vous pouvez maintenant procéder au déblocage des fonds.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showDeblocageDialog(),
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('DÉBLOQUER LES FONDS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Ce dossier est déjà finalisé ou en attente d\'une autre étape.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _canDecide() {
    return _currentStatut != LoanRequestStatus.approuvee &&
        _currentStatut != LoanRequestStatus.rejetee &&
        _currentStatut != LoanRequestStatus.debloquee;
  }

  LoanRequestStatus _getNextStatus() {
    switch (_currentStatut) {
      case LoanRequestStatus.soumise:
        return LoanRequestStatus.enAnalyse;
      case LoanRequestStatus.enAnalyse:
        return widget.request.montantDemande > 1000000
            ? LoanRequestStatus.enComite
            : LoanRequestStatus.approuvee;
      case LoanRequestStatus.enComite:
        return LoanRequestStatus.approuvee;
      default:
        return _currentStatut;
    }
  }

  String _getDecisionButtonLabel() {
    switch (_currentStatut) {
      case LoanRequestStatus.soumise:
        return 'Transmettre au Chef d\'Agence';
      case LoanRequestStatus.enAnalyse:
        return widget.request.montantDemande > 1000000
            ? 'Envoyer au Comité'
            : 'Approuver le Prêt';
      case LoanRequestStatus.enComite:
        return 'Approuver (Décision Comité)';
      default:
        return 'Valider';
    }
  }

  void _showRejetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejet du dossier'),
        content: TextField(
          controller: _motifRejetController,
          decoration: const InputDecoration(labelText: 'Motif du rejet'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveDecision(
                LoanRequestStatus.rejetee,
                motif: _motifRejetController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer le Rejet'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisCard(String title, String? avis, IconData icon) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isFilled = avis != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFilled
            ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green[50])
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFilled
              ? (isDark ? Colors.green.withOpacity(0.3) : Colors.green[200]!)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: avis != null ? Colors.green : Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  avis ?? "En attente...",
                  style: TextStyle(
                    color: isFilled
                        ? (isDark ? Colors.green[200] : Colors.black)
                        : (isDark ? Colors.white38 : Colors.grey),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LoanRequestStatus status) {
    Color color;
    switch (status) {
      case LoanRequestStatus.brouillon:
        color = Colors.grey;
        break;
      case LoanRequestStatus.soumise:
        color = Colors.blue;
        break;
      case LoanRequestStatus.enAnalyse:
        color = Colors.orange;
        break;
      case LoanRequestStatus.enComite:
        color = Colors.purple;
        break;
      case LoanRequestStatus.approuvee:
        color = Colors.green;
        break;
      case LoanRequestStatus.rejetee:
        color = Colors.red;
        break;
      case LoanRequestStatus.debloquee:
        color = AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _showDeblocageDialog() async {
    final seuil = await DatabaseService().getSeuilValidationPinFCFA();
    if (widget.request.montantDemande > seuil) {
      if (!mounted) return;
      final pinOk = await showDialog<bool>(
        context: context,
        builder: (_) => const PinValidationDialog(),
      );
      if (pinOk != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Déblocage annulé — validation superviseur requise.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    // Exigence 9 — Conditionner le déblocage à la signature du contrat
    bool contratSigne = false;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: const Text('Confirmation de déblocage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voulez-vous confirmer le déblocage de ce prêt ?\n\n'
                'Cette action générera l\'échéancier réel et activera le prêt dans le portefeuille.',
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: contratSigne,
                onChanged: (v) => setStateDlg(() => contratSigne = v ?? false),
                title: const Text(
                  'J\'atteste que le contrat de prêt a été signé par le client',
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    PdfExportService().exportLoanContract(widget.request),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Générer contrat PDF'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (!contratSigne) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez confirmer la signature du contrat avant le déblocage.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmer le déblocage'),
            ),
          ],
        ),
      ),
    );

    if (confirme != true) return;
    _disburseLoan();
  }

  Future<void> _disburseLoan() async {
    setState(() => _isLoading = true);

    try {
      final db = DatabaseService();

      // Garde-fou : Vérifier si un prêt existe déjà
      final existingLoan = await db.getLoanByRequestId(widget.request.id!);
      if (existingLoan != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Un prêt a déjà été débloqué pour cette demande.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      final numeroPret =
          'PRT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // 1. Créer le prêt
      final loan = Loan(
        demandePretId: widget.request.id!,
        clientId: widget.request.clientId,
        produitId: widget.request.produitId,
        numeroPret: numeroPret,
        montantInitial: widget.request.montantDemande,
        soldeRestant: widget.request.montantDemande,
        dateDeblocage: DateTime.now(),
        statut: LoanStatus.aJour,
        agentGestionnaire: widget.request.client?.agentAffecte,
        agenceGestion: widget.request.client?.agence,
        moisDiffereCapital: widget.request.moisDiffereCapital,
        contratSigne: true,
      );

      final loanId = await db.insertLoan(loan);

      final tauxAnnuel = widget.request.produit?.tauxInteret ?? 0;
      final echeancier = LoanCalculator.calculerEcheancierAvecDiffere(
        montant: widget.request.montantDemande,
        duree: widget.request.dureeMois,
        tauxAnnuel: tauxAnnuel,
        moisDiffere: widget.request.moisDiffereCapital,
      );

      double capitalRestant = widget.request.montantDemande;
      for (int i = 0; i < echeancier.length; i++) {
        final row = echeancier[i];
        final capitalDu = row['capital_du'] ?? 0;
        capitalRestant -= capitalDu;
        final datePrevue = DateTime.now().add(Duration(days: 30 * (i + 1)));
        final schedule = RepaymentSchedule(
          pretId: loanId,
          numeroEcheance: i + 1,
          datePrevue: datePrevue,
          capitalDu: capitalDu,
          interetsDus: row['interets_dus'] ?? 0,
          totalDu: row['total_du'] ?? 0,
          capitalRestant: capitalRestant.clamp(0, double.infinity),
          statut: RepaymentStatus.enAttente,
        );
        await db.insertRepaymentSchedule(schedule);
      }

      // 3. Mettre à jour le statut de la demande
      await db.updateLoanRequestStatus(
        widget.request.id!,
        LoanRequestStatus.debloquee,
      );

      if (mounted) {
        setState(() {
          _currentStatut = LoanRequestStatus.debloquee;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prêt débloqué avec succès ! N° $numeroPret'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du déblocage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
