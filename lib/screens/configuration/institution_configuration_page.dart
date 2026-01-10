import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/configuration_model.dart';

class InstitutionConfigurationPage extends StatefulWidget {
  const InstitutionConfigurationPage({super.key});

  @override
  State<InstitutionConfigurationPage> createState() =>
      _InstitutionConfigurationPageState();
}

class _InstitutionConfigurationPageState
    extends State<InstitutionConfigurationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Legal Information Controllers
  final _raisonSocialeController = TextEditingController();
  final _formeJuridiqueController = TextEditingController();
  final _numeroAgrementController = TextEditingController();
  final _registreCommerceController = TextEditingController();
  final _numeroFiscalController = TextEditingController();
  final _adresseSiegeController = TextEditingController();
  final _contactsOfficielsController = TextEditingController();
  final _logoPathController = TextEditingController();

  // Financial Parameters Controllers
  final _exerciceFiscalController = TextEditingController();
  final _deviseReferenceController = TextEditingController();
  final _tauxChangeController = TextEditingController();
  final _plafondCaisseController = TextEditingController();
  final _seuilApprobationController = TextEditingController();
  final _fraisDossierStandardController = TextEditingController();

  // Credit Parameters Controllers
  final _tauxInteretDefautController = TextEditingController();
  String _selectedModeCalcul = 'Dégressif';
  final List<String> _frequencesSelected = ['Mensuel'];
  final _tauxPenaliteRetardController = TextEditingController();
  final _delaiGraceMaxController = TextEditingController();
  final _epargneObligatoireController = TextEditingController();
  final _ratioEndettementMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllConfigs();
  }

  Future<void> _loadAllConfigs() async {
    setState(() => _isLoading = true);
    try {
      final legal = await DatabaseService().getLegalInformation();
      final financial = await DatabaseService().getFinancialParameters();
      final credit = await DatabaseService().getCreditParameters();

      setState(() {
        // Legal
        _raisonSocialeController.text = legal.raisonSociale;
        _formeJuridiqueController.text = legal.formeJuridique;
        _numeroAgrementController.text = legal.numeroAgrement;
        _registreCommerceController.text = legal.registreCommerce;
        _numeroFiscalController.text = legal.numeroFiscal;
        _adresseSiegeController.text = legal.adresseSiege;
        _contactsOfficielsController.text = legal.contactsOfficiels;
        _logoPathController.text = legal.logoPath;

        // Financial
        _exerciceFiscalController.text = financial.exerciceFiscal;
        _deviseReferenceController.text = financial.deviseReference;
        _tauxChangeController.text = financial.tauxChange.toString();
        _plafondCaisseController.text = financial.plafondCaisse.toString();
        _seuilApprobationController.text = financial.seuilApprobation
            .toString();
        _fraisDossierStandardController.text = financial.fraisDossierStandard
            .toString();

        // Credit
        _tauxInteretDefautController.text = credit.tauxInteretDefaut.toString();
        _selectedModeCalcul = credit.modeCalculInteret;
        _frequencesSelected.clear();
        _frequencesSelected.addAll(credit.frequencesRemboursement);
        _tauxPenaliteRetardController.text = credit.tauxPenaliteRetard
            .toString();
        _delaiGraceMaxController.text = credit.delaiGraceMax.toString();
        _epargneObligatoireController.text = credit.epargneObligatoire
            .toString();
        _ratioEndettementMaxController.text = credit.ratioEndettementMax
            .toString();

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading configs: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCurrentTab() async {
    setState(() => _isLoading = true);
    try {
      if (_tabController.index == 0) {
        final info = LegalInformation(
          raisonSociale: _raisonSocialeController.text,
          formeJuridique: _formeJuridiqueController.text,
          numeroAgrement: _numeroAgrementController.text,
          registreCommerce: _registreCommerceController.text,
          numeroFiscal: _numeroFiscalController.text,
          adresseSiege: _adresseSiegeController.text,
          contactsOfficiels: _contactsOfficielsController.text,
          logoPath: _logoPathController.text,
        );
        await DatabaseService().saveLegalInformation(info);
      } else if (_tabController.index == 1) {
        final params = FinancialParameters(
          exerciceFiscal: _exerciceFiscalController.text,
          deviseReference: _deviseReferenceController.text,
          tauxChange: double.tryParse(_tauxChangeController.text) ?? 1.0,
          plafondCaisse: double.tryParse(_plafondCaisseController.text) ?? 0.0,
          seuilApprobation:
              double.tryParse(_seuilApprobationController.text) ?? 0.0,
          fraisDossierStandard:
              double.tryParse(_fraisDossierStandardController.text) ?? 0.0,
        );
        await DatabaseService().saveFinancialParameters(params);
      } else {
        final params = CreditParameters(
          tauxInteretDefaut:
              double.tryParse(_tauxInteretDefautController.text) ?? 0.0,
          modeCalculInteret: _selectedModeCalcul,
          frequencesRemboursement: _frequencesSelected,
          tauxPenaliteRetard:
              double.tryParse(_tauxPenaliteRetardController.text) ?? 0.0,
          delaiGraceMax: int.tryParse(_delaiGraceMaxController.text) ?? 0,
          epargneObligatoire:
              double.tryParse(_epargneObligatoireController.text) ?? 0.0,
          ratioEndettementMax:
              double.tryParse(_ratioEndettementMaxController.text) ?? 0.0,
        );
        await DatabaseService().saveCreditParameters(params);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration sauvegardée avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration Institution',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Paramétrez les informations légales et financières de votre IMF.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(
              text: 'INFORMATIONS LÉGALES',
              icon: Icon(Icons.business_rounded),
            ),
            Tab(
              text: 'PARAMÈTRES FINANCIERS',
              icon: Icon(Icons.account_balance_rounded),
            ),
            Tab(
              text: 'PARAMÈTRES CRÉDIT',
              icon: Icon(Icons.credit_card_rounded),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveCurrentTab,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Sauvegarder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLegalTab(isDark),
                _buildFinancialTab(isDark),
                _buildCreditTab(isDark),
              ],
            ),
    );
  }

  Widget _buildLegalTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildFormContainer(
        isDark,
        children: [
          _buildTextField(
            'Raison sociale',
            _raisonSocialeController,
            Icons.business,
          ),
          _buildTextField(
            'Forme juridique',
            _formeJuridiqueController,
            Icons.gavel,
          ),
          _buildTextField(
            'N° d\'agrément',
            _numeroAgrementController,
            Icons.verified,
          ),
          _buildTextField(
            'Registre de commerce',
            _registreCommerceController,
            Icons.receipt_long,
          ),
          _buildTextField(
            'N° fiscal (IFU)',
            _numeroFiscalController,
            Icons.tag,
          ),
          _buildTextField(
            'Adresse siège social',
            _adresseSiegeController,
            Icons.location_on,
          ),
          _buildTextField(
            'Contacts officiels',
            _contactsOfficielsController,
            Icons.contact_phone,
          ),
          _buildTextField(
            'Chemin du logo institution',
            _logoPathController,
            Icons.image,
            hint: 'assets/images/logo.png',
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildFormContainer(
        isDark,
        children: [
          _buildTextField(
            'Exercice fiscal en cours',
            _exerciceFiscalController,
            Icons.calendar_today,
          ),
          _buildTextField(
            'Devise de référence',
            _deviseReferenceController,
            Icons.monetization_on,
          ),
          _buildTextField(
            'Taux de change (si multi-devises)',
            _tauxChangeController,
            Icons.currency_exchange,
            isNumber: true,
          ),
          _buildTextField(
            'Plafonds caisses',
            _plafondCaisseController,
            Icons.point_of_sale,
            isNumber: true,
          ),
          _buildTextField(
            'Seuils d\'approbation',
            _seuilApprobationController,
            Icons.how_to_reg,
            isNumber: true,
          ),
          _buildTextField(
            'Frais de dossier standard',
            _fraisDossierStandardController,
            Icons.payments,
            isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildFormContainer(
        isDark,
        children: [
          _buildTextField(
            'Taux d\'intérêt par défaut (%)',
            _tauxInteretDefautController,
            Icons.percent,
            isNumber: true,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            'Modes de calcul intérêts',
            _selectedModeCalcul,
            ['Linéaire', 'Dégressif', 'Amortissement constant'],
            (val) {
              setState(() => _selectedModeCalcul = val!);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Fréquences de remboursement autorisées',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children:
                [
                  'Quotidien',
                  'Hebdomadaire',
                  'Bimensuel',
                  'Mensuel',
                  'Trimestriel',
                ].map((freq) {
                  final isSelected = _frequencesSelected.contains(freq);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(freq),
                    onSelected: (selected) {
                      setState(() {
                        if (selected)
                          _frequencesSelected.add(freq);
                        else
                          _frequencesSelected.remove(freq);
                      });
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Taux pénalités retard (%)',
            _tauxPenaliteRetardController,
            Icons.warning_amber_rounded,
            isNumber: true,
          ),
          _buildTextField(
            'Délai de grâce maximum (jours)',
            _delaiGraceMaxController,
            Icons.timer_outlined,
            isNumber: true,
          ),
          _buildTextField(
            'Épargne obligatoire (%)',
            _epargneObligatoireController,
            Icons.savings_outlined,
            isNumber: true,
          ),
          _buildTextField(
            'Ratio endettement maximum (%)',
            _ratioEndettementMaxController,
            Icons.account_balance_wallet_outlined,
            isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20),
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
