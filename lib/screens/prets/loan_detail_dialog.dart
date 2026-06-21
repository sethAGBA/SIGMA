// lib/screens/prets/loan_detail_dialog.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/database_service.dart';
import '../../core/services/loan_contract_template_service.dart';
import '../../models/loan_model.dart';
import '../../models/repayment_schedule_model.dart';
import '../../core/theme/app_colors.dart';
import '../remboursements/repayment_form_dialog.dart';
import '../../models/repayment_model.dart';

class LoanDetailDialog extends StatefulWidget {
  final int loanId;

  const LoanDetailDialog({super.key, required this.loanId});

  @override
  State<LoanDetailDialog> createState() => _LoanDetailDialogState();
}

class _LoanDetailDialogState extends State<LoanDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Loan? _loan;
  List<RepaymentSchedule> _schedule = [];
  List<Repayment> _repayments = [];
  bool _isLoading = true;

  // --- Scan contrat ---
  bool _scanLoading = false;
  String? _scanPath;
  Uint8List? _scanBytes; // null si chargé depuis chemin fichier

  // --- Génération contrat PDF ---
  bool _contractGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final loan = await DatabaseService().getLoanById(widget.loanId);
    final schedule = await DatabaseService().getRepaymentSchedules(
      widget.loanId,
    );
    final repayments = await DatabaseService().getRepayments(widget.loanId);
    final scanData = await DatabaseService().getLoanContractScan(widget.loanId);

    if (mounted) {
      Uint8List? bytes;
      // Priorité : chemin fichier local ; sinon base64 stocké
      final path = scanData['path'];
      final b64 = scanData['base64'];
      if (path != null && File(path).existsSync()) {
        bytes = await File(path).readAsBytes();
      } else if (b64 != null && b64.isNotEmpty) {
        try {
          bytes = base64Decode(b64);
        } catch (_) {}
      }
      setState(() {
        _loan = loan;
        _schedule = schedule;
        _repayments = repayments;
        _isLoading = false;
        _scanPath = path;
        _scanBytes = bytes;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ SCAN

  Future<void> _importScan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _scanLoading = true);

    try {
      // Sauvegarder localement dans appDocDir
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/contract_scans');
      if (!scansDir.existsSync()) scansDir.createSync(recursive: true);

      final ext = file.extension ?? 'bin';
      final localPath =
          '${scansDir.path}/pret_${widget.loanId}_contrat.$ext';
      await File(localPath).writeAsBytes(file.bytes!);

      // Encoder en base64 pour portabilité (backup)
      final b64 = base64Encode(file.bytes!);

      await DatabaseService().saveLoanContractScan(widget.loanId, localPath, b64);

      if (mounted) {
        setState(() {
          _scanPath = localPath;
          _scanBytes = file.bytes;
          _scanLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan importé et archivé avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'import : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteScan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le scan'),
        content: const Text(
          'Voulez-vous vraiment supprimer le scan du contrat archivé ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await DatabaseService().deleteLoanContractScan(widget.loanId);
    // Supprimer le fichier local si accessible
    if (_scanPath != null) {
      final f = File(_scanPath!);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _scanPath = null;
        _scanBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan supprimé.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loan == null) {
      return const AlertDialog(
        title: Text('Erreur'),
        content: Text('Prêt introuvable'),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const Divider(),
            Expanded(child: _buildTabContent()),
            const Divider(),
            _buildActionFooter(),
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
            const Icon(
              Icons.account_balance_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prêt ${_loan!.numeroPret} - ${_loan!.client?.nomComplet ?? "Client"}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Débloqué le ${_formatDate(_loan!.dateDeblocage)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        _buildStatusBadge(_loan!.statut),
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
      tabs: [
        const Tab(text: 'Informations générales', icon: Icon(Icons.info_outline)),
        const Tab(text: 'Échéancier', icon: Icon(Icons.calendar_month_outlined)),
        const Tab(text: 'Remboursements', icon: Icon(Icons.history)),
        const Tab(text: 'Suivi & Terrain', icon: Icon(Icons.map_outlined)),
        Tab(
          text: 'Contrat signé',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.description_outlined),
              if (_scanBytes != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGeneralInfo(),
        _buildScheduleTable(),
        _buildRepaymentHistory(),
        _buildFollowupTab(),
        _buildContractScanTab(),
      ],
    );
  }

  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Situation Financière'),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Montant Initial',
                  _loan!.montantInitial,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Solde Restant',
                  _loan!.soldeRestant,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'Retard Jours',
                  _loan!.joursRetard.toDouble(),
                  Colors.red,
                  isAmount: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoRow('Produit de crédit', _loan!.produit?.nom ?? '-'),
          _buildInfoRow('Taux appliqué', '${_loan!.produit?.tauxInteret}%'),
          _buildInfoRow(
            'Pénalités calculées',
            '${_formatAmount(_loan!.calculatePenalties())} F',
            isWarning: _loan!.joursRetard > 0,
          ),
          _buildInfoRow('Date de déblocage', _formatDate(_loan!.dateDeblocage)),
          _buildInfoRow(
            'Échéance finale',
            _loan!.dateEcheanceProchaine != null
                ? _formatDate(_loan!.dateEcheanceProchaine!)
                : '-',
          ),
          _buildInfoRow('Agent gestionnaire', _loan!.agentGestionnaire ?? '-'),
          _buildInfoRow(
            'Agence de gestion',
            _loan!.agenceGestion ?? 'Agence Centrale',
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 1,
                  child: Text(
                    'N°',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date prévue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Capital',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Intérêts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total dû',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Statut',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _schedule.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _schedule[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text('${row.numeroEcheance}')),
                      Expanded(
                        flex: 2,
                        child: Text(_formatDate(row.datePrevue)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_formatAmount(row.capitalDu)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_formatAmount(row.interetsDus)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(row.totalDu),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildRepaymentStatusBadge(row.statut),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentHistory() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_repayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Aucun remboursement enregistré pour le moment',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Montant',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'N° Reçu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Agent',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _repayments.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = _repayments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(_formatDate(r.datePaiement)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatAmount(r.montantTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      Expanded(flex: 2, child: Text(r.numeroRecu)),
                      Expanded(flex: 2, child: Text(r.modePaiement.label)),
                      Expanded(
                        flex: 2,
                        child: Text(r.agentCollecteur ?? 'Système'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Historique des Visites Terrain'),
          _buildFollowupItem(
            DateTime.now().subtract(const Duration(days: 5)),
            'Visite de Relance',
            'Client rencontré. Promesse de paiement pour le 15 du mois.',
            Icons.directions_walk,
          ),
          _buildFollowupItem(
            DateTime.now().subtract(const Duration(days: 15)),
            'Appel Téléphonique',
            'Difficultés passagères dues à une mévente. À suivre.',
            Icons.phone_outlined,
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Actions Automatisées'),
          _buildFollowupItem(
            DateTime.now().subtract(const Duration(days: 1)),
            'SMS de Rappel',
            'Envoi automatique SMS échéance J-1.',
            Icons.sms_outlined,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ TAB: Contrat signé

  Widget _buildContractScanTab() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasScan = _scanBytes != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Archivage du contrat signé'),

          // ---- Zone de scan ----
          if (_scanLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!hasScan)
            _buildNoScanPlaceholder(isDark)
          else
            _buildScanPreview(isDark),

          const SizedBox(height: 24),

          // ---- Actions ----
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _scanLoading ? null : _importScan,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(hasScan ? 'Remplacer le scan' : 'Importer scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
              if (hasScan) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _scanLoading ? null : _deleteScan,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Supprimer scan',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ---- Infos formats acceptés ----
          Text(
            'Formats acceptés : PDF, JPG, JPEG, PNG',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScanPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 48,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun scan archivé',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Importez le contrat signé pour l\'archiver.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanPreview(bool isDark) {
    final isPdf = _scanPath != null &&
        _scanPath!.toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aperçu image ou icône PDF
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.green.withOpacity(0.3) : Colors.green.shade200,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isPdf
                ? _buildPdfPreview(isDark)
                : _buildImagePreview(),
          ),
        ),
        const SizedBox(height: 12),
        // Chemin fichier
        if (_scanPath != null)
          Row(
            children: [
              Icon(Icons.attach_file, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _scanPath!.split('/').last,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_scanBytes == null) return const SizedBox.shrink();
    return InteractiveViewer(
      child: Image.memory(
        _scanBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => const Center(
          child: Text(
            'Impossible d\'afficher l\'image.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPreview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(
            'Document PDF archivé',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _scanPath!.split('/').last,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openLocalFile(_scanPath!),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ouvrir le fichier'),
          ),
        ],
      ),
    );
  }

  void _openLocalFile(String path) {
    // Sur desktop (macOS) : ouvre avec l'application par défaut
    if (!kIsWeb) {
      try {
        Process.run('open', [path]);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'ouvrir le fichier : $e')),
          );
        }
      }
    }
  }

  // ------------------------------------------------------------------ TAB: Suivi terrain

  Widget _buildFollowupItem(
    DateTime date,
    String title,
    String description,
    IconData icon, {
    Color? color,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color ?? AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
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

  Widget _buildMetricBox(
    String label,
    double value,
    Color color, {
    bool isAmount = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            isAmount ? '${_formatAmount(value)} F' : value.toInt().toString(),
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

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LoanStatus status) {
    // Reutiliser la logique de LoanListPage pour plus de cohérence
    Color color;
    switch (status) {
      case LoanStatus.aJour:
        color = Colors.green;
        break;
      case LoanStatus.alerte:
        color = Colors.orange;
        break;
      case LoanStatus.retard:
        color = Colors.deepOrange;
        break;
      case LoanStatus.contentieux:
        color = Colors.red;
        break;
      case LoanStatus.perte:
        color = Colors.black;
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
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRepaymentStatusBadge(RepaymentStatus status) {
    Color color;
    switch (status) {
      case RepaymentStatus.paye:
        color = Colors.green;
        break;
      case RepaymentStatus.impaye:
        color = Colors.red;
        break;
      case RepaymentStatus.partiel:
        color = Colors.orange;
        break;
      case RepaymentStatus.enAttente:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Contrat PDF

  Future<void> _generateContractPdf() async {
    if (_contractGenerating) return;
    setState(() => _contractGenerating = true);

    try {
      final path = await LoanContractTemplateService()
          .generateLoanContract(widget.loanId);

      if (!mounted) return;
      setState(() => _contractGenerating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contrat généré : ${path.split('/').last}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Ouvrir',
            textColor: Colors.white,
            onPressed: () {
              if (!kIsWeb) {
                try {
                  Process.run('open', [path]);
                } catch (_) {}
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _contractGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur génération contrat : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ------------------------------------------------------------------ FOOTER

  Widget _buildActionFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildQuickAction(
            Icons.print_outlined,
            'Imprimer Échéancier',
            Colors.grey,
            () {},
          ),
          const SizedBox(width: 12),
          _buildQuickAction(
            Icons.sms_outlined,
            'Envoyer Rappel',
            Colors.blue,
            () {},
          ),
          const SizedBox(width: 12),
          _buildQuickAction(
            Icons.event_note_outlined,
            'Planifier Visite',
            Colors.orange,
            () {},
          ),
          const SizedBox(width: 12),
          _buildQuickAction(
            Icons.sync_problem_outlined,
            'Restructurer',
            Colors.deepOrange,
            () {},
          ),
          const Spacer(),
          // Bouton Générer Contrat PDF (Exigences 7.1 / 7.2)
          OutlinedButton.icon(
            onPressed: _contractGenerating ? null : _generateContractPdf,
            icon: _contractGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              _contractGenerating ? 'Génération…' : 'Générer Contrat PDF',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => RepaymentFormDialog(loan: _loan!),
              );
              if (result == true) _loadData();
            },
            icon: const Icon(Icons.add_card),
            label: const Text('ENREGISTRER PAIEMENT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 20),
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
}
