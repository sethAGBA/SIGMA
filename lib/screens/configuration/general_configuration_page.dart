// lib/screens/configuration/general_configuration_page.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/accounting_config_model.dart';

class GeneralConfigurationPage extends StatefulWidget {
  const GeneralConfigurationPage({super.key});

  @override
  State<GeneralConfigurationPage> createState() =>
      _GeneralConfigurationPageState();
}

class _GeneralConfigurationPageState extends State<GeneralConfigurationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  AccountingConfiguration? _config;

  // Controllers
  final _comptePretsController = TextEditingController();
  final _compteCaisseController = TextEditingController();
  final _compteInteretsController = TextEditingController();
  final _comptePenalitesController = TextEditingController();
  final _compteInteretsCourusPretsController = TextEditingController();
  final _compteDotationProvisionsController = TextEditingController();
  final _compteDepreciationPretsController = TextEditingController();
  final _compteDepotsController = TextEditingController();
  final _compteInteretsAcquisEpargneController = TextEditingController();
  final _compteChargeInteretEpargneController = TextEditingController();
  final _compteResultatExerciceController = TextEditingController();
  final _compteBanqueController = TextEditingController();
  final _compteVenteServicesController = TextEditingController();
  final _compteProduitsFinanciersController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await DatabaseService().getAccountingConfig();
      setState(() {
        _config = config;
        _comptePretsController.text = config.comptePrets;
        _compteCaisseController.text = config.compteCaisse;
        _compteInteretsController.text = config.compteInterets;
        _comptePenalitesController.text = config.comptePenalites;
        _compteInteretsCourusPretsController.text =
            config.compteInteretsCourusPrets;
        _compteDotationProvisionsController.text =
            config.compteDotationProvisions;
        _compteDepreciationPretsController.text =
            config.compteDepreciationPrets;
        _compteDepotsController.text = config.compteDepots;
        _compteInteretsAcquisEpargneController.text =
            config.compteInteretsAcquisEpargne;
        _compteChargeInteretEpargneController.text =
            config.compteChargeInteretEpargne;
        _compteResultatExerciceController.text = config.compteResultatExercice;
        _compteBanqueController.text = config.compteBanque;
        _compteVenteServicesController.text = config.compteVenteServices;
        _compteProduitsFinanciersController.text =
            config.compteProduitsFinanciers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newConfig = AccountingConfiguration(
        comptePrets: _comptePretsController.text,
        compteCaisse: _compteCaisseController.text,
        compteInterets: _compteInteretsController.text,
        comptePenalites: _comptePenalitesController.text,
        compteInteretsCourusPrets: _compteInteretsCourusPretsController.text,
        compteDotationProvisions: _compteDotationProvisionsController.text,
        compteDepreciationPrets: _compteDepreciationPretsController.text,
        compteDepots: _compteDepotsController.text,
        compteInteretsAcquisEpargne:
            _compteInteretsAcquisEpargneController.text,
        compteChargeInteretEpargne: _compteChargeInteretEpargneController.text,
        compteResultatExercice: _compteResultatExerciceController.text,
        compteBanque: _compteBanqueController.text,
        compteVenteServices: _compteVenteServicesController.text,
        compteProduitsFinanciers: _compteProduitsFinanciersController.text,
      );

      await DatabaseService().saveAccountingConfig(newConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration sauvegardée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _comptePretsController.dispose();
    _compteCaisseController.dispose();
    _compteInteretsController.dispose();
    _comptePenalitesController.dispose();
    _compteInteretsCourusPretsController.dispose();
    _compteDotationProvisionsController.dispose();
    _compteDepreciationPretsController.dispose();
    _compteDepotsController.dispose();
    _compteInteretsAcquisEpargneController.dispose();
    _compteChargeInteretEpargneController.dispose();
    _compteResultatExerciceController.dispose();
    _compteBanqueController.dispose();
    _compteVenteServicesController.dispose();
    _compteProduitsFinanciersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Générale (Comptabilité)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Comptes par défaut (SYSCOHADA)'),
              const SizedBox(height: 24),
              _buildSectionHeader('Activité Crédit'),
              _buildGrid([
                _buildTextField(
                  'Compte Prêts (Encours)',
                  _comptePretsController,
                  'Ex: 271',
                ),
                _buildTextField(
                  'Compte Intérêts',
                  _compteInteretsController,
                  'Ex: 7712',
                ),
                _buildTextField(
                  'Compte Pénalités',
                  _comptePenalitesController,
                  'Ex: 7078',
                ),
                _buildTextField(
                  'Intérêts Courus (Recevables)',
                  _compteInteretsCourusPretsController,
                  'Ex: 2761',
                ),
                _buildTextField(
                  'Dotations Provisions',
                  _compteDotationProvisionsController,
                  'Ex: 6972',
                ),
                _buildTextField(
                  'Dépréciations Prêts',
                  _compteDepreciationPretsController,
                  'Ex: 2971',
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionHeader('Activité Épargne & Caisse'),
              _buildGrid([
                _buildTextField(
                  'Compte Caisse',
                  _compteCaisseController,
                  'Ex: 571',
                ),
                _buildTextField(
                  'Compte Dépôts',
                  _compteDepotsController,
                  'Ex: 1651',
                ),
                _buildTextField(
                  'Intérêts à Payer (Épargne)',
                  _compteInteretsAcquisEpargneController,
                  'Ex: 1665',
                ),
                _buildTextField(
                  'Charges Intérêts (Épargne)',
                  _compteChargeInteretEpargneController,
                  'Ex: 6741',
                ),
                _buildTextField(
                  'Compte Banque',
                  _compteBanqueController,
                  'Ex: 521',
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionHeader('Clôture'),
              _buildGrid([
                _buildTextField(
                  'Résultat Net',
                  _compteResultatExerciceController,
                  'Ex: 131',
                ),
                _buildTextField(
                  'Vente Services (Commissions)',
                  _compteVenteServicesController,
                  'Ex: 706',
                ),
                _buildTextField(
                  'Produits Financiers (Intérêts)',
                  _compteProduitsFinanciersController,
                  'Ex: 77',
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGrid(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: children,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Requis';
        }
        return null;
      },
    );
  }
}
