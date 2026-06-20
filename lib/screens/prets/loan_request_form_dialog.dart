// lib/screens/prets/loan_request_form_dialog.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/services/database_service.dart';
import '../../core/services/location_service.dart';
import '../../models/client_model.dart';
import '../../models/produit_financier_model.dart';
import '../../models/loan_request_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/loan_calculator.dart';
import '../../widgets/dialogs/client_form_dialog.dart';
import 'dart:math' as math;

class LoanRequestFormDialog extends StatefulWidget {
  const LoanRequestFormDialog({super.key});

  @override
  State<LoanRequestFormDialog> createState() => _LoanRequestFormDialogState();
}

class _LoanRequestFormDialogState extends State<LoanRequestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Selection state
  Client? _selectedClient;
  ProduitFinancier? _selectedProduct;

  // Controllers - Step 1 & 2
  final _amountController = TextEditingController();
  final _durationController = TextEditingController();
  final _differeController = TextEditingController(text: '0');
  final _objectController = TextEditingController();

  // Controllers - Step 4 (Analyse Financière)
  final _revenusController = TextEditingController();
  final _chargesController = TextEditingController();
  final _autresDettesController = TextEditingController();

  // Controllers - Step 5 (Garanties)
  String? _typeGarantie;
  final _descGarantieController = TextEditingController();
  final _valeurGarantieController = TextEditingController();
  final _cautionNomController = TextEditingController();

  // Step 6 (Documents) - Paths placeholders
  String? _cniPath;
  String? _facturePath;
  String? _photoCommercePath;

  // Step 7 (Visite)
  final _observationsVisiteController = TextEditingController();
  double? _latitudeVisite;
  double? _longitudeVisite;
  bool _gpsUnavailable = false;
  bool _gpsLoading = false;
  final List<String> _visitPhotoPaths = [];

  // Metrics
  double _mensualite = 0;
  double _totalARembourser = 0;
  double _coutTotalCredit = 0;
  double _teg = 0;
  static const double _seuilUsureTeg = 36.0;
  double _fraisDossierStandard = 0;
  double _tauxEffort = 0;
  double _capaciteRemboursement = 0;
  double _resteAVivre = 0;

  List<Client> _clients = [];
  List<ProduitFinancier> _products = [];
  String _clientSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final clients = await DatabaseService().getClients();
    final products = await DatabaseService().getProduits(
      type: ProductType.credit,
    );
    final finParams = await DatabaseService().getFinancialParameters();
    setState(() {
      _clients = clients;
      _products = products;
      _fraisDossierStandard = finParams.fraisDossierStandard;
    });
  }

  void _calculateSimulation() {
    if (_selectedProduct == null) return;

    double capital = double.tryParse(_amountController.text) ?? 0;
    int months = int.tryParse(_durationController.text) ?? 0;
    double annualRate = _selectedProduct!.tauxInteret / 100;

    if (capital <= 0 || months <= 0) return;

    if (_selectedProduct!.modeCalculInteret == InterestCalculationMode.flat) {
      double totalInterest = capital * annualRate * (months / 12);
      _totalARembourser = capital + totalInterest;
      _mensualite = _totalARembourser / months;
    } else {
      double monthlyRate = annualRate / 12;
      _mensualite =
          (capital * monthlyRate) / (1 - math.pow(1 + monthlyRate, -months));
      _totalARembourser = _mensualite * months;
    }

    _coutTotalCredit = _totalARembourser - capital;
    _teg = LoanCalculator.calculerTEG(
      tauxNominalAnnuel: _selectedProduct!.tauxInteret,
      tauxAssurance: _selectedProduct!.tauxAssurance ?? 0,
      fraisDossier: _fraisDossierStandard,
      montantPret: capital,
      dureesMois: months,
    );

    double rev = double.tryParse(_revenusController.text) ?? 0;
    double ch = double.tryParse(_chargesController.text) ?? 0;
    double dettes = double.tryParse(_autresDettesController.text) ?? 0;

    _capaciteRemboursement = rev - ch - dettes;
    _tauxEffort = rev > 0 ? ((_mensualite + dettes) / rev) * 100 : 0;
    _resteAVivre = rev - ch - dettes - _mensualite;

    setState(() {});
  }

  Future<void> _save() async {
    if (_selectedClient == null || _selectedProduct == null) return;

    final request = LoanRequest(
      clientId: _selectedClient!.id!,
      produitId: _selectedProduct!.id!,
      montantDemande: double.tryParse(_amountController.text) ?? 0,
      dureeMois: int.tryParse(_durationController.text) ?? 0,
      frequenceRemboursement: RepaymentFrequency.monthly,
      objetPret: _objectController.text,
      mensualite: _mensualite,
      totalARembourser: _totalARembourser,
      coutTotalCredit: _coutTotalCredit,
      teg: _teg,
      moisDiffereCapital: int.tryParse(_differeController.text) ?? 0,
      revenusMensuels: double.tryParse(_revenusController.text) ?? 0,
      chargesMensuelles: double.tryParse(_chargesController.text) ?? 0,
      autresDettes: double.tryParse(_autresDettesController.text) ?? 0,
      capaciteRemboursement: _capaciteRemboursement,
      tauxEffort: _tauxEffort,
      resteAVivre: _resteAVivre,
      typeGarantie: _typeGarantie,
      descriptionGarantie: _descGarantieController.text,
      valeurGarantie: double.tryParse(_valeurGarantieController.text),
      cautionPersonnelle: _cautionNomController.text,
      observationsVisite: _observationsVisiteController.text,
      latitudeVisite: _latitudeVisite,
      longitudeVisite: _longitudeVisite,
      photosVisite: [
        ..._visitPhotoPaths,
      ].where((p) => p.isNotEmpty).join(','),
      documentsDossier: [
        _cniPath,
        _facturePath,
        _photoCommercePath,
      ].where((p) => p != null).join(','),
      statut: LoanRequestStatus.soumise,
      dateCreation: DateTime.now(),
    );

    final requestId = await DatabaseService().insertLoanRequest(request);
    await _finalizeVisitPhotos(requestId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _captureVisitGps() async {
    setState(() {
      _gpsLoading = true;
      _gpsUnavailable = false;
    });
    final pos = await LocationService().getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _gpsLoading = false;
      if (pos != null) {
        _latitudeVisite = pos.latitude;
        _longitudeVisite = pos.longitude;
        _gpsUnavailable = false;
      } else {
        _gpsUnavailable = true;
      }
    });
  }

  Future<void> _pickVisitPhoto(ImageSource source) async {
    if (_visitPhotoPaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos de visite')),
      );
      return;
    }
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      final file = File(image.path);
      if (await file.length() > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo trop volumineuse (max 5 Mo)')),
          );
        }
        return;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDir.path, 'visites', 'tmp'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final dest = p.join(
        dir.path,
        'visite_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.copy(dest);
      if (mounted) setState(() => _visitPhotoPaths.add(dest));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur photo : $e')),
        );
      }
    }
  }

  Future<void> _finalizeVisitPhotos(int requestId) async {
    if (_visitPhotoPaths.isEmpty) return;
    final appDir = await getApplicationDocumentsDirectory();
    final finalDir = Directory(p.join(appDir.path, 'visites', '$requestId'));
    if (!await finalDir.exists()) await finalDir.create(recursive: true);
    final paths = <String>[];
    for (int i = 0; i < _visitPhotoPaths.length; i++) {
      final dest = p.join(finalDir.path, 'photo_$i.jpg');
      await File(_visitPhotoPaths[i]).copy(dest);
      paths.add(dest);
    }
    await DatabaseService().updateLoanRequestPhotos(
      requestId,
      paths.join(','),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            _buildStepper(),
            const Divider(),
            Expanded(child: _buildStepContent()),
            const Divider(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.edit_document, color: AppColors.primary, size: 28),
            SizedBox(width: 16),
            Text(
              'Montage Dossier de Crédit Complet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepIndicator(0, 'Client', Icons.person),
          _buildStepLine(),
          _buildStepIndicator(1, 'Produit', Icons.account_balance),
          _buildStepLine(),
          _buildStepIndicator(2, 'Simulation', Icons.calculate),
          _buildStepLine(),
          _buildStepIndicator(3, 'Analyse', Icons.analytics),
          _buildStepLine(),
          _buildStepIndicator(4, 'Garanties', Icons.security),
          _buildStepLine(),
          _buildStepIndicator(5, 'Documents', Icons.folder),
          _buildStepLine(),
          _buildStepIndicator(6, 'Visite', Icons.map),
          _buildStepLine(),
          _buildStepIndicator(7, 'Scoring', Icons.speed),
          _buildStepLine(),
          _buildStepIndicator(8, 'Décision', Icons.gavel),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    bool isActive = _currentStep == step;
    bool isCompleted = _currentStep > step;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isCompleted
              ? Colors.green
              : (isActive
                    ? AppColors.primary
                    : (isDark ? Colors.white10 : Colors.grey[200])),
          foregroundColor: isCompleted || isActive
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.grey[600]),
          child: Icon(isCompleted ? Icons.check : icon, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? AppColors.primary
                : (isDark ? Colors.white60 : Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 25,
      height: 2,
      color: Theme.of(context).dividerColor,
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildClientSelection();
      case 1:
        return _buildProductSelection();
      case 2:
        return _buildSimulationStep();
      case 3:
        return _buildFinancialAnalysis();
      case 4:
        return _buildGuarantees();
      case 5:
        return _buildDocumentsStep();
      case 6:
        return _buildVisiteStep();
      case 7:
        return _buildScoringStep();
      case 8:
        return _buildDecisionStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildClientSelection() {
    final filteredClients = _clients
        .where(
          (c) =>
              c.nomComplet.toLowerCase().contains(
                _clientSearchQuery.toLowerCase(),
              ) ||
              c.numeroClient.toLowerCase().contains(
                _clientSearchQuery.toLowerCase(),
              ),
        )
        .toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher un client existant...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _clientSearchQuery = v),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _showNewClientDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('Nouveau Client'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: filteredClients.length,
            itemBuilder: (context, index) {
              final client = filteredClients[index];
              bool isSelected = _selectedClient?.id == client.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    client.nom[0],
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                title: Text(
                  client.nomComplet,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${client.numeroClient} • Score: ${client.scoreCredit}',
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedClient = client;
                    _revenusController.text =
                        client.revenusMensuels?.toString() ?? '';
                    _chargesController.text =
                        client.chargesMensuelles?.toString() ?? '';
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choix du produit financier',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              bool isSelected = _selectedProduct?.id == product.id;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    product.nom,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(product.description),
                  trailing: Text(
                    '${product.tauxInteret}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => setState(() {
                    _selectedProduct = product;
                    _calculateSimulation();
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant souhaité',
                    border: OutlineInputBorder(),
                    suffixText: 'FCFA',
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  onChanged: (v) => _calculateSimulation(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée souhaitée (Mois)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  onChanged: (v) => _calculateSimulation(),
                ),
              ),
            ],
          ),
        ),
        if (_selectedProduct?.differePossible == true) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _differeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Mois de différé capital',
              border: const OutlineInputBorder(),
              helperText:
                  'Max ${_selectedProduct?.dureeMaxDiffereCapitalMois ?? 0} mois',
            ),
            onChanged: (_) => _calculateSimulation(),
            validator: (v) {
              final val = int.tryParse(v ?? '') ?? 0;
              final max = _selectedProduct?.dureeMaxDiffereCapitalMois ?? 0;
              if (val < 0 || val > max) {
                return 'Entre 0 et $max mois';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSimulationStep() {
    _calculateSimulation();
    final tegDepasseUsure = _teg > _seuilUsureTeg;
    return Column(
      children: [
        if (tegDepasseUsure)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TEG ${_teg.toStringAsFixed(2)} % > seuil d\'usure ($_seuilUsureTeg %)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            _buildResultBox('Mensualité', _mensualite),
            const SizedBox(width: 12),
            _buildResultBox('Total dû', _totalARembourser),
            const SizedBox(width: 12),
            _buildResultBox(
              'TEG (%)',
              _teg,
              isPercent: true,
              highlight: tegDepasseUsure ? Colors.orange : null,
            ),
          ],
        ),
        if (_selectedProduct != null) ...[
          const SizedBox(height: 8),
          Text(
            'Taux nominal : ${_selectedProduct!.tauxInteret.toStringAsFixed(2)} %/an',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Tableau d\'amortissement indicatif',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              itemCount: (int.tryParse(_durationController.text) ?? 0).clamp(
                0,
                36,
              ),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  title: Text(
                    'Échéance du ${_formatDate(DateTime.now().add(Duration(days: 30 * (index + 1))))}',
                  ),
                  trailing: Text(
                    '${_formatAmount(_mensualite)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialAnalysis() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analyse CAP (Capacité de remboursement)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _revenusController,
                  'Revenus mensuels',
                  Icons.add_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  _chargesController,
                  'Charges mensuelles',
                  Icons.remove_circle,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _autresDettesController,
            'Autres dettes mensuelles',
            Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 24),
          _buildAnalysisMetrics(),
        ],
      ),
    );
  }

  Widget _buildAnalysisMetrics() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _buildMetricRow(
            'Capacité de remboursement brute',
            _capaciteRemboursement,
          ),
          const Divider(),
          _buildMetricRow(
            'Taux d\'effort global',
            _tauxEffort,
            isPercent: true,
          ),
          const Divider(),
          _buildMetricRow('Reste à vivre mensuel', _resteAVivre),
        ],
      ),
    );
  }

  Widget _buildGuarantees() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sûretés et Cautions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _typeGarantie,
            decoration: const InputDecoration(
              labelText: 'Nature de la garantie',
              border: OutlineInputBorder(),
            ),
            items: [
              'Hypothèque',
              'Gage sans dépossession',
              'Caution Personnelle',
              'Caution Solidaire',
              'Matériel agricole',
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _typeGarantie = v),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _descGarantieController,
            'Désignation détaillée / Localisation',
            Icons.description,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _valeurGarantieController,
                  'Valeur d\'expertise',
                  Icons.euro,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  _cautionNomController,
                  'Nom de la caution',
                  Icons.person_pin,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pièces jointes au dossier (KYC/Garanties)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildDocItem(
          'Photocopie CNI / Passeport',
          _cniPath != null,
          () => setState(() => _cniPath = 'uploaded'),
        ),
        _buildDocItem(
          'Justificatif de domicile (Facture)',
          _facturePath != null,
          () => setState(() => _facturePath = 'uploaded'),
        ),
        _buildDocItem(
          'Photo du lieu d\'exercice (Commerce/Champ)',
          _photoCommercePath != null,
          () => setState(() => _photoCommercePath = 'uploaded'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Note: Les fichiers doivent être inférieurs à 5Mo.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDocItem(String label, bool isUploaded, VoidCallback onUpload) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle : Icons.upload_file,
                color: isUploaded ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
          TextButton(
            onPressed: onUpload,
            child: Text(isUploaded ? 'Remplacer' : 'Uploader'),
          ),
        ],
      ),
    );
  }

  Widget _buildVisiteStep() {
    final isWindows = Platform.isWindows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rapport de visite terrain',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextFormField(
            controller: _observationsVisiteController,
            maxLines: 15,
            decoration: const InputDecoration(
              hintText:
                  'Saisissez ici les observations faites sur le lieu de l\'activité, l\'environnement du client, et son intégrité perçue...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              _latitudeVisite != null ? Icons.location_on : Icons.location_off,
              color: _gpsUnavailable ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _gpsLoading
                  ? const Text('Acquisition GPS en cours...')
                  : _latitudeVisite != null
                      ? Text(
                          'Position : ${_latitudeVisite!.toStringAsFixed(5)}, '
                          '${_longitudeVisite!.toStringAsFixed(5)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )
                      : Text(
                          _gpsUnavailable
                              ? 'GPS indisponible — la visite peut quand même être enregistrée'
                              : 'Position non capturée',
                          style: TextStyle(
                            color: _gpsUnavailable ? Colors.orange : Colors.grey,
                          ),
                        ),
            ),
            TextButton.icon(
              onPressed: _gpsLoading ? null : _captureVisitGps,
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isWindows)
              OutlinedButton.icon(
                onPressed: () => _pickVisitPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Photo'),
              ),
            OutlinedButton.icon(
              onPressed: () => _pickVisitPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, size: 16),
              label: const Text('Galerie'),
            ),
          ],
        ),
        if (_visitPhotoPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_visitPhotoPaths.length}/3 photo(s) jointe(s)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildScoringStep() {
    int clientScore = _selectedClient?.scoreCredit ?? 50;
    bool isRiskOk = _tauxEffort < 35 && clientScore > 40;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Évaluation Automatique du Risque',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: clientScore / 100,
                  strokeWidth: 15,
                  backgroundColor: Theme.of(context).dividerColor,
                  color: isRiskOk ? Colors.green : Colors.orange,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$clientScore',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Points Score CREDIT',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRiskOk
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRiskOk ? Colors.green : Colors.orange,
              ),
            ),
            child: Column(
              children: [
                Text(
                  isRiskOk
                      ? 'AVIS SYSTÈME POSITIF'
                      : 'ATTENTION : RISQUE POTENTIEL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isRiskOk ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                Text(
                  isRiskOk
                      ? 'Le profil financier respecte les seuils de prudence.'
                      : 'Le taux d\'effort ou le score client nécessite une vigilance.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Validation Finale & Orientations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _objectController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Objet final motivé du prêt',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryBox(
            'Montant demandé',
            '${_formatAmount(double.tryParse(_amountController.text) ?? 0)} FCFA',
          ),
          _buildSummaryBox(
            'Capacité identifiée',
            '${_formatAmount(_capaciteRemboursement)} FCFA / mois',
          ),
          _buildSummaryBox('Périodicité', 'Mensuelle'),
          const SizedBox(height: 24),
          const AlertBox(
            title: 'Prochaine étape',
            message:
                'Dès soumission, le dossier passera au statut "Soumise" et sera analysé par le Chef d\'Agence.',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    Color? color,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => _calculateSimulation(),
    );
  }

  Widget _buildMetricRow(String label, double value, {bool isPercent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            isPercent
                ? '${value.toStringAsFixed(1)}%'
                : '${_formatAmount(value)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBox(
    String label,
    double value, {
    bool isPercent = false,
    Color? highlight,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: highlight ?? Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              isPercent
                  ? '${value.toStringAsFixed(1)}%'
                  : '${_formatAmount(value)} FCFA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: highlight ?? AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          TextButton.icon(
            onPressed: () => setState(() => _currentStep--),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Précédent'),
          )
        else
          const SizedBox.shrink(),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (_currentStep < 8) {
                  if (_currentStep == 0 && _selectedClient == null) return;
                  if (_currentStep == 1 &&
                      (_selectedProduct == null ||
                          !_formKey.currentState!.validate()))
                    return;
                  setState(() => _currentStep++);
                  if (_currentStep == 6) _captureVisitGps();
                } else {
                  _save();
                }
              },
              icon: Icon(_currentStep == 8 ? Icons.send : Icons.arrow_forward),
              label: Text(
                _currentStep == 8 ? 'Finaliser & Soumettre' : 'Suivant',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _showNewClientDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientFormDialog(),
    );
    if (result == true) _loadInitialData();
  }
}

class AlertBox extends StatelessWidget {
  final String title;
  final String message;
  const AlertBox({super.key, required this.title, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
