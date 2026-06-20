// lib/widgets/dialogs/client_form_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../core/services/client_api_service.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../models/client_model.dart';
import '../../models/groupe_solidaire_model.dart';
import '../../models/produit_financier_model.dart';
import '../../models/savings_account_model.dart';

class _PendingKycDocument {
  final String name;
  final int sizeBytes;
  final String sourcePath;

  const _PendingKycDocument({
    required this.name,
    required this.sizeBytes,
    required this.sourcePath,
  });
}

class ClientFormDialog extends StatefulWidget {
  final Client? client; // null = nouveau client, non-null = édition

  const ClientFormDialog({super.key, this.client});

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Step 1: Identification
  final _nomController = TextEditingController();
  final _prenomsController = TextEditingController();
  final _lieuNaissanceController = TextEditingController();
  final _numeroCNIController = TextEditingController();
  final _numeroPasseportController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descriptionLogementController = TextEditingController();
  final _languesParleesController = TextEditingController();
  DateTime? _dateNaissance;
  ClientGender _sexe = ClientGender.m;
  SituationFamiliale? _situationFamiliale;
  int? _nombreEnfants;
  TypeLogement? _typeLogement;
  String? _photoPath;

  // Step 2: Activité économique
  final _activiteController = TextEditingController();
  final _activitesSecondairesController = TextEditingController();
  final _revenusController = TextEditingController();
  final _chargesController = TextEditingController();
  final _ancienneteActiviteController = TextEditingController();
  final _lieuExerciceActiviteController = TextEditingController();
  final _descriptionActiviteController = TextEditingController();
  final _biensPatrimoineController = TextEditingController();

  // Step 3: Contact & Adresse (moved from step 1)
  final _telController = TextEditingController();
  final _adresseController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // Step 4: Références
  final _refNom1Controller = TextEditingController();
  final _refTel1Controller = TextEditingController();
  final _refRelation1Controller = TextEditingController();
  final _refNom2Controller = TextEditingController();
  final _refTel2Controller = TextEditingController();
  final _refRelation2Controller = TextEditingController();
  bool _cautionSolidaireActive = false;
  int? _selectedGroupeId;
  List<GroupeSolidaire> _groupes = [];

  // Step 5: Documents KYC
  final List<_PendingKycDocument> _kycFiles = [];
  String? _documentCNIPath;
  String? _documentJustifDomicilePath;
  String? _photoCommercePath;
  String? _photoDomicilePath;

  // Step 6: Évaluation (calculated fields)
  double? _capaciteRemboursement;
  double? _capaciteEndettement;
  double? _tauxEndettement;
  double? _montantMaxAutorise;
  int _scoreCredit = 50;
  ClientRisk _niveauRisque = ClientRisk.medium;

  // Step 7: Épargne
  bool _epargneObligatoireOuverte = false;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    _loadGroupes();
    if (_isEditing) {
      _loadClientData();
    }
  }

  Future<void> _loadGroupes() async {
    final groupes = await DatabaseService().getGroupesSolidaires();
    if (mounted) setState(() => _groupes = groupes);
  }

  Future<void> _afterClientCreated(int clientId) async {
    final db = DatabaseService();

    // Renommer le fichier photo temporaire avec le vrai clientId
    if (_photoPath != null && File(_photoPath!).existsSync()) {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      final finalPath = p.join(photosDir.path, '$clientId.jpg');
      await File(_photoPath!).copy(finalPath);
      // Supprimer le fichier temp si différent
      if (_photoPath != finalPath) {
        try {
          await File(_photoPath!).delete();
        } catch (_) {}
      }
      _photoPath = finalPath;
    }

    final epargneProducts = await db.getProduits(type: ProductType.epargne);
    final obligatoire = epargneProducts
        .where((p) => p.savingsCategory == SavingsCategory.obligatoire)
        .toList();
    if (obligatoire.isNotEmpty) {
      final produit = obligatoire.first;
      final month = DateFormat('yyyyMM').format(DateTime.now());
      await db.insertSavingsAccount(
        SavingsAccount(
          clientId: clientId,
          produitId: produit.id!,
          numeroCompte: 'CEP-$clientId-$month',
          statut: SavingsAccountStatus.actif,
          dateOuverture: DateTime.now(),
          tauxInteretApplique: produit.tauxInteret,
        ),
      );
      _epargneObligatoireOuverte = true;
    }

    if (_selectedGroupeId != null) {
      await db.addClientToGroup(clientId, _selectedGroupeId!);
    }

    if (_kycFiles.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final kycDir = Directory(p.join(appDir.path, 'kyc', clientId.toString()));
      if (!await kycDir.exists()) await kycDir.create(recursive: true);

      for (final doc in _kycFiles) {
        final destPath = p.join(kycDir.path, doc.name);
        await File(doc.sourcePath).copy(destPath);
        await db.insertDocumentClient(
          clientId: clientId,
          typeDocument: 'kyc',
          nomFichier: doc.name,
          cheminLocal: destPath,
        );
      }
    }
  }

  Future<void> _pickKycDocument() async {
    if (_kycFiles.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 documents KYC.')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;
    if (file.size > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier trop volumineux (max 10 Mo).')),
        );
      }
      return;
    }

    setState(() {
      _kycFiles.add(
        _PendingKycDocument(
          name: file.name,
          sizeBytes: file.size,
          sourcePath: file.path!,
        ),
      );
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  void _loadClientData() {
    final client = widget.client!;
    _nomController.text = client.nom;
    _prenomsController.text = client.prenoms;
    _dateNaissance = client.dateNaissance;
    _lieuNaissanceController.text = client.lieuNaissance ?? '';
    _sexe = client.sexe;
    _numeroCNIController.text = client.numeroCNI ?? '';
    _numeroPasseportController.text = client.numeroPasseport ?? '';
    _emailController.text = client.email ?? '';
    _whatsappController.text = client.whatsapp ?? '';
    _situationFamiliale = client.situationFamiliale;
    _nombreEnfants = client.nombreEnfants;
    _typeLogement = client.typeLogement;
    _descriptionLogementController.text = client.descriptionLogement ?? '';
    _languesParleesController.text = client.languesParlees ?? '';
    _photoPath = client.photoPath;

    _telController.text = client.telephone ?? '';
    _adresseController.text = client.adresse ?? '';
    _latitudeController.text = client.latitude?.toString() ?? '';
    _longitudeController.text = client.longitude?.toString() ?? '';

    _activiteController.text = client.activitePrincipale ?? '';
    _activitesSecondairesController.text = client.activitesSecondaires ?? '';
    _revenusController.text = client.revenusMensuels?.toString() ?? '';
    _chargesController.text = client.chargesMensuelles?.toString() ?? '';
    _ancienneteActiviteController.text =
        client.ancienneteActivite?.toString() ?? '';
    _lieuExerciceActiviteController.text = client.lieuExerciceActivite ?? '';
    _descriptionActiviteController.text = client.descriptionActivite ?? '';
    _biensPatrimoineController.text = client.biensPatrimoine ?? '';

    _refNom1Controller.text = client.referenceNom1 ?? '';
    _refTel1Controller.text = client.referenceTel1 ?? '';
    _refRelation1Controller.text = client.referenceRelation1 ?? '';
    _refNom2Controller.text = client.referenceNom2 ?? '';
    _refTel2Controller.text = client.referenceTel2 ?? '';
    _refRelation2Controller.text = client.referenceRelation2 ?? '';
    _cautionSolidaireActive = client.cautionSolidaireActive;

    _documentCNIPath = client.documentCNIPath;
    _documentJustifDomicilePath = client.documentJustifDomicilePath;
    _photoCommercePath = client.photoCommercePath;
    _photoDomicilePath = client.photoDomicilePath;

    _scoreCredit = client.scoreCredit;
    _niveauRisque = client.niveauRisque;
    _capaciteRemboursement = client.capaciteRemboursement;
    _capaciteEndettement = client.capaciteEndettement;
    _tauxEndettement = client.tauxEndettement;
    _montantMaxAutorise = client.montantMaxAutorise;
    _epargneObligatoireOuverte = client.epargneObligatoireOuverte;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomsController.dispose();
    _lieuNaissanceController.dispose();
    _numeroCNIController.dispose();
    _numeroPasseportController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _descriptionLogementController.dispose();
    _telController.dispose();
    _adresseController.dispose();
    _activiteController.dispose();
    _activitesSecondairesController.dispose();
    _revenusController.dispose();
    _chargesController.dispose();
    _ancienneteActiviteController.dispose();
    _lieuExerciceActiviteController.dispose();
    _descriptionActiviteController.dispose();
    _biensPatrimoineController.dispose();
    _refNom1Controller.dispose();
    _refTel1Controller.dispose();
    _refRelation1Controller.dispose();
    _refNom2Controller.dispose();
    _refTel2Controller.dispose();
    _refRelation2Controller.dispose();
    _languesParleesController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    return _formKey.currentState?.validate() ?? false;
  }

  void _calculateFinancialMetrics() {
    final revenus = double.tryParse(_revenusController.text) ?? 0;
    final charges = double.tryParse(_chargesController.text) ?? 0;

    // Capacité de remboursement = 30% du revenu net (revenus - charges)
    final revenuNet = revenus - charges;
    _capaciteRemboursement = revenuNet * 0.3;

    // Capacité d'endettement = montant maximum qu'on peut prêter
    _capaciteEndettement = _capaciteRemboursement! * 12;

    // Taux d'endettement (simplifié pour l'instant)
    _tauxEndettement = revenus > 0 ? (charges / revenus) * 100 : 0;

    // Montant maximum autorisé (basé sur capacité de remboursement sur 12 mois)
    _montantMaxAutorise = _capaciteRemboursement! * 12;

    // Ajuster le score et le risque basé sur le taux d'endettement
    if (_tauxEndettement! < 30) {
      _scoreCredit = 70;
      _niveauRisque = ClientRisk.low;
    } else if (_tauxEndettement! < 50) {
      _scoreCredit = 50;
      _niveauRisque = ClientRisk.medium;
    } else {
      _scoreCredit = 30;
      _niveauRisque = ClientRisk.high;
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep == 2) {
        // Calculer les métriques financières avant de passer à l'étape 5
        _calculateFinancialMetrics();
      }

      if (_currentStep < 6) {
        setState(() => _currentStep++);
      } else {
        _submit();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      DialogUtils.showLoadingDialog(
        context: context,
        message: _isEditing
            ? 'Modification en cours...'
            : 'Création en cours...',
      );

      // Vérification des doublons
      final isDuplicate = await ClientApiService().isDuplicate(
        telephone: _telController.text.trim(),
        numeroCNI: _numeroCNIController.text.trim(),
        excludeId: widget.client?.id,
      );

      if (isDuplicate) {
        if (mounted) {
          DialogUtils.hideLoadingDialog(context);
          DialogUtils.showErrorDialog(
            context: context,
            title: 'Doublon détecté',
            message:
                'Un client avec ce numéro de téléphone ou cette CNI existe déjà.',
          );
        }
        return;
      }

      final clientData = Client(
        id: widget.client?.id,
        numeroClient:
            widget.client?.numeroClient ??
            'CLI-${Random().nextInt(90000) + 10000}',
        nom: _nomController.text.trim(),
        prenoms: _prenomsController.text.trim(),
        dateNaissance: _dateNaissance,
        lieuNaissance: _lieuNaissanceController.text.trim().isEmpty
            ? null
            : _lieuNaissanceController.text.trim(),
        sexe: _sexe,
        numeroCNI: _numeroCNIController.text.trim().isEmpty
            ? null
            : _numeroCNIController.text.trim(),
        numeroPasseport: _numeroPasseportController.text.trim().isEmpty
            ? null
            : _numeroPasseportController.text.trim(),
        telephone: _telController.text.trim().isEmpty
            ? null
            : _telController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        whatsapp: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty
            ? null
            : _adresseController.text.trim(),
        situationFamiliale: _situationFamiliale,
        nombreEnfants: _nombreEnfants,
        typeLogement: _typeLogement,
        descriptionLogement: _descriptionLogementController.text.trim().isEmpty
            ? null
            : _descriptionLogementController.text.trim(),
        languesParlees: _languesParleesController.text.trim().isEmpty
            ? null
            : _languesParleesController.text.trim(),
        photoPath: _photoPath,
        activitePrincipale: _activiteController.text.trim().isEmpty
            ? null
            : _activiteController.text.trim(),
        activitesSecondaires:
            _activitesSecondairesController.text.trim().isEmpty
            ? null
            : _activitesSecondairesController.text.trim(),
        revenusMensuels: double.tryParse(_revenusController.text.trim()),
        chargesMensuelles: double.tryParse(_chargesController.text.trim()),
        capaciteRemboursement: _capaciteRemboursement,
        ancienneteActivite: int.tryParse(
          _ancienneteActiviteController.text.trim(),
        ),
        lieuExerciceActivite:
            _lieuExerciceActiviteController.text.trim().isEmpty
            ? null
            : _lieuExerciceActiviteController.text.trim(),
        descriptionActivite: _descriptionActiviteController.text.trim().isEmpty
            ? null
            : _descriptionActiviteController.text.trim(),
        biensPatrimoine: _biensPatrimoineController.text.trim().isEmpty
            ? null
            : _biensPatrimoineController.text.trim(),
        referenceNom1: _refNom1Controller.text.trim().isEmpty
            ? null
            : _refNom1Controller.text.trim(),
        referenceTel1: _refTel1Controller.text.trim().isEmpty
            ? null
            : _refTel1Controller.text.trim(),
        referenceRelation1: _refRelation1Controller.text.trim().isEmpty
            ? null
            : _refRelation1Controller.text.trim(),
        referenceNom2: _refNom2Controller.text.trim().isEmpty
            ? null
            : _refNom2Controller.text.trim(),
        referenceTel2: _refTel2Controller.text.trim().isEmpty
            ? null
            : _refTel2Controller.text.trim(),
        referenceRelation2: _refRelation2Controller.text.trim().isEmpty
            ? null
            : _refRelation2Controller.text.trim(),
        cautionSolidaireActive: _cautionSolidaireActive,
        documentCNIPath: _documentCNIPath,
        documentJustifDomicilePath: _documentJustifDomicilePath,
        photoCommercePath: _photoCommercePath,
        photoDomicilePath: _photoDomicilePath,
        scoreCredit: _scoreCredit,
        niveauRisque: _niveauRisque,
        capaciteEndettement: _capaciteEndettement,
        tauxEndettement: _tauxEndettement,
        montantMaxAutorise: _montantMaxAutorise,
        dateEvaluation: DateTime.now(),
        epargneObligatoireOuverte: _epargneObligatoireOuverte,
        latitude: double.tryParse(_latitudeController.text.trim()),
        longitude: double.tryParse(_longitudeController.text.trim()),
        dateCreation: widget.client?.dateCreation ?? DateTime.now(),
      );

      if (_isEditing) {
        await ClientApiService().updateClient(clientData);
      } else {
        final clientId = await ClientApiService().insertClient(clientData);
        await _afterClientCreated(clientId);
      }

      if (mounted) {
        DialogUtils.hideLoadingDialog(context);
        if (!_isEditing && _epargneObligatoireOuverte) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte épargne obligatoire ouvert automatiquement.'),
            ),
          );
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.hideLoadingDialog(context);
        DialogUtils.showErrorDialog(
          context: context,
          title: 'Erreur',
          message: 'Une erreur est survenue: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DialogConstants.borderRadius),
      ),
      child: Container(
        width: DialogConstants.largeDialogWidth,
        constraints: const BoxConstraints(maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            _buildStepIndicator(theme),
            Expanded(
              child: SingleChildScrollView(
                padding: DialogConstants.dialogPadding,
                child: Form(key: _formKey, child: _buildStepContent()),
              ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: DialogConstants.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DialogConstants.borderRadius),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Modifier le client' : 'Nouveau client',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final steps = [
      'Identification',
      'Contact',
      'Économie',
      'Références',
      'Documents',
      'Évaluation',
      'Validation',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _buildStepCircle(i, steps[i], theme),
              if (i < steps.length - 1) _buildStepLine(i, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, ThemeData theme) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    Color circleColor;
    Color textColor;
    Widget icon;

    if (isCompleted) {
      circleColor = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
      icon = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
    } else if (isActive) {
      circleColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.primary;
      icon = Text(
        '${step + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    } else {
      circleColor = theme.colorScheme.surfaceVariant;
      textColor = theme.colorScheme.onSurfaceVariant;
      icon = Text(
        '${step + 1}',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int step, ThemeData theme) {
    final isCompleted = _currentStep > step;
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      color: isCompleted
          ? const Color(0xFF10B981)
          : theme.colorScheme.surfaceVariant,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildIdentificationStep();
      case 1:
        return _buildContactStep();
      case 2:
        return _buildEconomicStep();
      case 3:
        return _buildReferencesStep();
      case 4:
        return _buildDocumentsStep();
      case 5:
        return _buildEvaluationStep();
      case 6:
        return _buildValidationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIdentificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'État civil complet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est requis';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _prenomsController,
                decoration: const InputDecoration(
                  labelText: 'Prénoms *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Les prénoms sont requis';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ClientGender>(
                value: _sexe,
                decoration: const InputDecoration(
                  labelText: 'Sexe *',
                  prefixIcon: Icon(Icons.wc_rounded),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ClientGender.m,
                    child: Text('Masculin'),
                  ),
                  DropdownMenuItem(
                    value: ClientGender.f,
                    child: Text('Féminin'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sexe = value);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dateNaissance ?? DateTime(1990),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _dateNaissance = date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dateNaissance != null
                        ? '${_dateNaissance!.day}/${_dateNaissance!.month}/${_dateNaissance!.year}'
                        : 'Sélectionner',
                    style: TextStyle(
                      color: _dateNaissance != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lieuNaissanceController,
          decoration: const InputDecoration(
            labelText: 'Lieu de naissance',
            prefixIcon: Icon(Icons.location_city_rounded),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _numeroCNIController,
                decoration: const InputDecoration(
                  labelText: 'N° CNI',
                  prefixIcon: Icon(Icons.badge_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _numeroPasseportController,
                decoration: const InputDecoration(
                  labelText: 'N° Passeport',
                  prefixIcon: Icon(Icons.card_travel_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp',
                  prefixIcon: Icon(Icons.chat_rounded),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<SituationFamiliale>(
                value: _situationFamiliale,
                decoration: const InputDecoration(
                  labelText: 'Situation familiale',
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SituationFamiliale.celibataire,
                    child: Text('Célibataire'),
                  ),
                  DropdownMenuItem(
                    value: SituationFamiliale.marie,
                    child: Text('Marié(e)'),
                  ),
                  DropdownMenuItem(
                    value: SituationFamiliale.divorce,
                    child: Text('Divorcé(e)'),
                  ),
                  DropdownMenuItem(
                    value: SituationFamiliale.veuf,
                    child: Text('Veuf/Veuve'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _situationFamiliale = value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _nombreEnfants?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'enfants',
                  prefixIcon: Icon(Icons.child_care_rounded),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  _nombreEnfants = int.tryParse(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TypeLogement>(
          value: _typeLogement,
          decoration: const InputDecoration(
            labelText: 'Type de logement',
            prefixIcon: Icon(Icons.home_rounded),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: TypeLogement.proprietaire,
              child: Text('Propriétaire'),
            ),
            DropdownMenuItem(
              value: TypeLogement.locataire,
              child: Text('Locataire'),
            ),
          ],
          onChanged: (value) {
            setState(() => _typeLogement = value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionLogementController,
          decoration: const InputDecoration(
            labelText: 'Description du logement',
            prefixIcon: Icon(Icons.description_outlined),
            border: OutlineInputBorder(),
            hintText: 'Ex: Maison en dur, 3 pièces...',
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _languesParleesController,
          decoration: const InputDecoration(
            labelText: 'Langues parlées',
            prefixIcon: Icon(Icons.language_rounded),
            border: OutlineInputBorder(),
            hintText: 'Ex: Français, Fon, Mina...',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 24),
        _buildPhotoSelector(),
      ],
    );
  }

  Widget _buildPhotoSelector() {
    final theme = Theme.of(context);
    final bool isWindows = Platform.isWindows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo du client',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: _photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_photoPath!), fit: BoxFit.cover),
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.5,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: isWindows
                      ? 'Caméra non disponible sur ce poste'
                      : '',
                  child: ElevatedButton.icon(
                    onPressed: isWindows
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Prendre une photo'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Choisir depuis la galerie'),
                ),
                if (_photoPath != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => setState(() => _photoPath = null),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      // Copier dans {appDocDir}/photos/ avec un nom temporaire
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);

      final ext = p.extension(image.path).isEmpty
          ? '.jpg'
          : p.extension(image.path);
      final tempName =
          'photo_tmp_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(photosDir.path, tempName);
      await File(image.path).copy(destPath);

      if (mounted) {
        setState(() => _photoPath = destPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection : $e')),
        );
      }
    }
  }

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coordonnées',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _telController,
          decoration: const InputDecoration(
            labelText: 'Téléphone *',
            prefixIcon: Icon(Icons.phone_rounded),
            border: OutlineInputBorder(),
            hintText: '+228 XX XX XX XX',
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le téléphone est requis';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adresseController,
          decoration: const InputDecoration(
            labelText: 'Adresse complète *',
            prefixIcon: Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(),
            hintText: 'Quartier, Rue, Ville',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'L\'adresse est requise';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Géolocalisation (Optionnel)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  prefixIcon: Icon(Icons.explore_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  prefixIcon: Icon(Icons.explore_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () async {
                final pos = await LocationService().getCurrentPosition();
                if (!mounted) return;
                if (pos != null) {
                  setState(() {
                    _latitudeController.text = pos.latitude.toStringAsFixed(6);
                    _longitudeController.text = pos.longitude.toStringAsFixed(6);
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Position GPS indisponible'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'Ma position',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEconomicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité économique',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _activiteController,
          decoration: const InputDecoration(
            labelText: 'Activité principale *',
            prefixIcon: Icon(Icons.work_outline_rounded),
            border: OutlineInputBorder(),
            hintText: 'Commerce, Agriculture, Artisanat...',
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'L\'activité principale est requise';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _activitesSecondairesController,
          decoration: const InputDecoration(
            labelText: 'Activités secondaires',
            prefixIcon: Icon(Icons.business_center_outlined),
            border: OutlineInputBorder(),
            hintText: 'Autres sources de revenus',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _revenusController,
                decoration: const InputDecoration(
                  labelText: 'Revenus mensuels (FCFA) *',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(),
                  hintText: '100000',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Les revenus sont requis';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _chargesController,
                decoration: const InputDecoration(
                  labelText: 'Charges mensuelles (FCFA) *',
                  prefixIcon: Icon(Icons.money_off_rounded),
                  border: OutlineInputBorder(),
                  hintText: '50000',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Les charges sont requises';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ancienneteActiviteController,
                decoration: const InputDecoration(
                  labelText: 'Ancienneté (mois)',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                  border: OutlineInputBorder(),
                  hintText: '24',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _lieuExerciceActiviteController,
                decoration: const InputDecoration(
                  labelText: 'Lieu d\'exercice',
                  prefixIcon: Icon(Icons.place_rounded),
                  border: OutlineInputBorder(),
                  hintText: 'Marché, Boutique...',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionActiviteController,
          decoration: const InputDecoration(
            labelText: 'Description détaillée de l\'activité',
            prefixIcon: Icon(Icons.description_outlined),
            border: OutlineInputBorder(),
            hintText: 'Décrivez l\'activité en détail...',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _biensPatrimoineController,
          decoration: const InputDecoration(
            labelText: 'Biens et patrimoine',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            border: OutlineInputBorder(),
            hintText: 'Terrain, véhicule, équipements...',
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildReferencesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personnes de référence',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Référence 1',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _refNom1Controller,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _refTel1Controller,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _refRelation1Controller,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                  border: OutlineInputBorder(),
                  hintText: 'Ami, Famille...',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Référence 2',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _refNom2Controller,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _refTel2Controller,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _refRelation2Controller,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                  border: OutlineInputBorder(),
                  hintText: 'Ami, Famille...',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Caution solidaire active'),
          subtitle: const Text('Le client fait partie d\'un groupe solidaire'),
          value: _cautionSolidaireActive,
          onChanged: (value) {
            setState(() => _cautionSolidaireActive = value);
          },
        ),
        if (_groupes.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: _selectedGroupeId,
            decoration: const InputDecoration(
              labelText: 'Groupe solidaire (optionnel)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Aucun groupe'),
              ),
              ..._groupes.map(
                (g) => DropdownMenuItem<int?>(
                  value: g.id,
                  child: Text('${g.nom} (${g.code})'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedGroupeId = v),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents KYC',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PDF, JPG ou PNG — max 5 fichiers, 10 Mo chacun',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ..._kycFiles.map(
          (doc) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(doc.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(_formatFileSize(doc.sizeBytes)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => setState(() => _kycFiles.remove(doc)),
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickKycDocument,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un document'),
        ),
        const SizedBox(height: 24),
        _buildDocumentItem(
          'CNI (recto/verso)',
          Icons.badge_rounded,
          _documentCNIPath,
        ),
        _buildDocumentItem(
          'Justificatif de domicile',
          Icons.home_rounded,
          _documentJustifDomicilePath,
        ),
        _buildDocumentItem(
          'Photo du commerce/activité',
          Icons.store_rounded,
          _photoCommercePath,
        ),
        _buildDocumentItem(
          'Photo du domicile',
          Icons.house_rounded,
          _photoDomicilePath,
        ),
      ],
    );
  }

  Widget _buildDocumentItem(String label, IconData icon, String? path) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: path != null
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.upload_file_outlined),
      onTap: () {
        // TODO: Implement file picker
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fonctionnalité d\'upload à venir'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Widget _buildEvaluationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Évaluation crédit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score crédit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '$_scoreCredit / 100',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _scoreCredit / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          'Niveau de risque',
          _niveauRisque == ClientRisk.low
              ? 'Faible'
              : _niveauRisque == ClientRisk.medium
              ? 'Moyen'
              : 'Élevé',
          _niveauRisque == ClientRisk.low
              ? Colors.green
              : _niveauRisque == ClientRisk.medium
              ? Colors.orange
              : Colors.red,
          Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Capacité de remboursement mensuelle',
          '${_capaciteRemboursement?.toStringAsFixed(0) ?? '0'} FCFA',
          Colors.blue,
          Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Taux d\'endettement',
          '${_tauxEndettement?.toStringAsFixed(1) ?? '0'}%',
          _tauxEndettement != null && _tauxEndettement! < 30
              ? Colors.green
              : _tauxEndettement != null && _tauxEndettement! < 50
              ? Colors.orange
              : Colors.red,
          Icons.percent_rounded,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Montant maximum autorisé',
          '${_montantMaxAutorise?.toStringAsFixed(0) ?? '0'} FCFA',
          Colors.purple,
          Icons.monetization_on_rounded,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ces métriques sont calculées automatiquement en fonction des revenus et charges déclarés.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildValidationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Validation finale',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récapitulatif',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24),
                _buildSummaryItem(
                  'Nom complet',
                  '${_nomController.text} ${_prenomsController.text}',
                ),
                _buildSummaryItem('Téléphone', _telController.text),
                _buildSummaryItem('Adresse', _adresseController.text),
                _buildSummaryItem('Activité', _activiteController.text),
                _buildSummaryItem(
                  'Revenus mensuels',
                  '${_revenusController.text} FCFA',
                ),
                _buildSummaryItem(
                  'Charges mensuelles',
                  '${_chargesController.text} FCFA',
                ),
                _buildSummaryItem('Score crédit', '$_scoreCredit / 100'),
                _buildSummaryItem(
                  'Niveau de risque',
                  _niveauRisque == ClientRisk.low
                      ? 'Faible'
                      : _niveauRisque == ClientRisk.medium
                      ? 'Moyen'
                      : 'Élevé',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text('Ouvrir un compte épargne obligatoire'),
          subtitle: const Text('Recommandé pour les nouveaux clients'),
          value: _epargneObligatoireOuverte,
          onChanged: (value) {
            setState(() => _epargneObligatoireOuverte = value);
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Toutes les informations sont complètes. Vous pouvez créer le client.',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      height: DialogConstants.footerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(DialogConstants.borderRadius),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          Row(
            children: [
              if (_currentStep > 0)
                TextButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Précédent'),
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _nextStep,
                icon: Icon(
                  _currentStep < 6
                      ? Icons.arrow_forward_rounded
                      : Icons.check_rounded,
                ),
                label: Text(
                  _currentStep < 6
                      ? 'Suivant'
                      : (_isEditing ? 'Modifier' : 'Créer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
