// lib/widgets/dialogs/client_detail_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/client_model.dart';
import '../../models/groupe_solidaire_model.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dialog_utils.dart';

class ClientDetailDialog extends StatefulWidget {
  final Client client;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ClientDetailDialog({
    super.key,
    required this.client,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ClientDetailDialog> createState() => _ClientDetailDialogState();
}

class _ClientDetailDialogState extends State<ClientDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GroupeSolidaire? _group;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    if (widget.client.groupeSolidaireId != null) {
      final group = await DatabaseService().getGroupeById(
        widget.client.groupeSolidaireId!,
      );
      if (mounted) {
        setState(() => _group = group);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000,
        height: 800,
        child: Column(
          children: [
            _buildHeader(theme),
            _buildTabBar(theme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalTab(),
                  _buildSocioEconTab(),
                  _buildGroupTab(),
                  _buildCreditHistoryTab(),
                  _buildScoringTab(),
                  _buildSavingsTab(),
                  _buildGuaranteesTab(),
                  _buildKYCTab(),
                  _buildCommsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.client.nom} ${widget.client.prenoms}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip(
                      Icons.numbers_rounded,
                      widget.client.numeroClient,
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(widget.client.statut),
                    const SizedBox(width: 12),
                    _buildRiskBadge(widget.client.niveauRisque),
                  ],
                ),
              ],
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: widget.client.photoPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(widget.client.photoPath!, fit: BoxFit.cover),
            )
          : Center(
              child: Text(
                widget.client.nom[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ClientStatus status) {
    Color color = status == ClientStatus.active
        ? AppColors.success
        : (status == ClientStatus.inactive ? Colors.grey : AppColors.error);
    return _buildBadge(status.label, color);
  }

  Widget _buildRiskBadge(ClientRisk risk) {
    Color color = risk == ClientRisk.low
        ? AppColors.success
        : (risk == ClientRisk.medium ? AppColors.warning : AppColors.error);
    return _buildBadge('Risque : ${risk.label}', color);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        IconButton(
          onPressed: widget.onEdit,
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Modifier',
        ),
        IconButton(
          onPressed: () async {
            final confirm = await DialogUtils.showConfirmDialog(
              context: context,
              title: 'Supprimer le client',
              message: 'Voulez-vous vraiment supprimer ce client ?',
              isDangerous: true,
            );
            if (confirm) widget.onDelete?.call();
          },
          icon: const Icon(Icons.delete_rounded, color: AppColors.error),
          tooltip: 'Supprimer',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Perso.', icon: Icon(Icons.person_rounded)),
          Tab(text: 'Socio-écon.', icon: Icon(Icons.business_center_rounded)),
          Tab(text: 'Groupe', icon: Icon(Icons.groups_rounded)),
          Tab(text: 'Crédit', icon: Icon(Icons.account_balance_wallet_rounded)),
          Tab(text: 'Scoring', icon: Icon(Icons.analytics_rounded)),
          Tab(text: 'Épargne', icon: Icon(Icons.savings_rounded)),
          Tab(text: 'Garanties', icon: Icon(Icons.security_rounded)),
          Tab(text: 'KYC', icon: Icon(Icons.folder_shared_rounded)),
          Tab(text: 'Comms', icon: Icon(Icons.sms_rounded)),
        ],
      ),
    );
  }

  Widget _buildPersonalTab() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return _buildTabContent([
      _buildInfoSection('État Civil & Identification', [
        _buildInfoRow(
          'Nom complet',
          '${widget.client.nom} ${widget.client.prenoms}',
        ),
        _buildInfoRow('Sexe', widget.client.sexe.label),
        _buildInfoRow(
          'Date de naissance',
          widget.client.dateNaissance != null
              ? dateFormat.format(widget.client.dateNaissance!)
              : 'N/A',
        ),
        _buildInfoRow(
          'Lieu de naissance',
          widget.client.lieuNaissance ?? 'N/A',
        ),
        _buildInfoRow('N° CNI', widget.client.numeroCNI ?? 'N/A'),
        _buildInfoRow('N° Passeport', widget.client.numeroPasseport ?? 'N/A'),
        _buildInfoRow('Langues parlées', widget.client.languesParlees ?? 'N/A'),
      ]),
      _buildInfoSection('Coordonnées & Adresse', [
        _buildInfoRow('Téléphone', widget.client.telephone ?? 'N/A'),
        _buildInfoRow('WhatsApp', widget.client.whatsapp ?? 'N/A'),
        _buildInfoRow('Email', widget.client.email ?? 'N/A'),
        _buildInfoRow('Adresse domicile', widget.client.adresse ?? 'N/A'),
        if (widget.client.latitude != null && widget.client.longitude != null)
          _buildInfoRow(
            'Géolocalisation',
            'Lat: ${widget.client.latitude}, Long: ${widget.client.longitude}',
          ),
      ]),
      _buildInfoSection('Situation Familiale & Logement', [
        _buildInfoRow(
          'Statut matrimonial',
          widget.client.situationFamiliale?.label ?? 'N/A',
        ),
        _buildInfoRow(
          'Nombre d\'enfants',
          widget.client.nombreEnfants?.toString() ?? 'N/A',
        ),
        _buildInfoRow(
          'Type de logement',
          widget.client.typeLogement?.label ?? 'N/A',
        ),
        _buildInfoRow(
          'Description logement',
          widget.client.descriptionLogement ?? 'N/A',
        ),
      ]),
    ]);
  }

  Widget _buildSocioEconTab() {
    final curFormat = NumberFormat.currency(
      symbol: 'FCFA',
      decimalDigits: 0,
      locale: 'fr_FR',
    );
    return _buildTabContent([
      _buildInfoSection('Activité Professionnelle', [
        _buildInfoRow(
          'Activité principale',
          widget.client.activitePrincipale ?? 'N/A',
        ),
        _buildInfoRow(
          'Activités secondaires',
          widget.client.activitesSecondaires ?? 'N/A',
        ),
        _buildInfoRow(
          'Lieu d\'exercice',
          widget.client.lieuExerciceActivite ?? 'N/A',
        ),
        _buildInfoRow(
          'Ancienneté',
          widget.client.ancienneteActivite != null
              ? '${widget.client.ancienneteActivite} mois'
              : 'N/A',
        ),
      ]),
      _buildInfoSection('Analyse Budgétaire (Mensuelle)', [
        _buildInfoRow(
          'Revenus déclarés',
          widget.client.revenusMensuels != null
              ? curFormat.format(widget.client.revenusMensuels)
              : 'N/A',
        ),
        _buildInfoRow(
          'Charges estimées',
          widget.client.chargesMensuelles != null
              ? curFormat.format(widget.client.chargesMensuelles)
              : 'N/A',
        ),
        _buildInfoRow(
          'Capacité de remb.',
          widget.client.capaciteRemboursement != null
              ? curFormat.format(widget.client.capaciteRemboursement)
              : 'N/A',
        ),
      ]),
      _buildInfoSection('Patrimoine & Biens', [
        _buildInfoRow(
          'Description des biens',
          widget.client.biensPatrimoine ?? 'N/A',
        ),
      ]),
    ]);
  }

  Widget _buildGroupTab() {
    return _buildTabContent([
      _buildInfoSection('Appartenance au Groupe Solidaire', [
        _buildInfoRow('Nom du groupe', _group?.nom ?? 'Aucun'),
        _buildInfoRow('Code groupe', _group?.code ?? 'N/A'),
        _buildInfoRow(
          'Caution solidaire',
          widget.client.cautionSolidaireActive ? 'ACTIVE' : 'INACTIVE',
        ),
      ]),
    ]);
  }

  Widget _buildCreditHistoryTab() => _buildPlaceholderTab(
    'Historique des prêts (Prêts remboursés, actifs, retards)',
  );
  Widget _buildScoringTab() {
    return _buildTabContent([
      _buildInfoSection('Scoring & Évaluation du Risque', [
        _buildInfoRow('Score Crédit', '${widget.client.scoreCredit} / 100'),
        _buildInfoRow('Niveau de risque', widget.client.niveauRisque.label),
        _buildInfoRow(
          'Taux d\'endettement',
          widget.client.tauxEndettement != null
              ? '${widget.client.tauxEndettement}%'
              : 'N/A',
        ),
        _buildInfoRow(
          'Max autorisé',
          widget.client.montantMaxAutorise != null
              ? '${widget.client.montantMaxAutorise} FCFA'
              : 'N/A',
        ),
      ]),
    ]);
  }

  Widget _buildSavingsTab() =>
      _buildPlaceholderTab('Comptes d\'épargne (Libre, Obligatoire, DAT)');
  Widget _buildGuaranteesTab() =>
      _buildPlaceholderTab('Garanties matérielles & Cautions personnelles');
  Widget _buildKYCTab() => _buildPlaceholderTab(
    'Documents numérisés (CNI, Justificatitifs, Photos activité)',
  );
  Widget _buildCommsTab() => _buildPlaceholderTab(
    'Historique des échanges (SMS, Appels, Visites terrain)',
  );

  Widget _buildTabContent(List<Widget> sections) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 12),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: AppColors.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Module en cours d\'implémentation',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
