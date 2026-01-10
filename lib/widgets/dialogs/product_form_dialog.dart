// lib/widgets/dialogs/product_form_dialog.dart

import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/produit_financier_model.dart';
import '../../core/theme/app_colors.dart';

class ProductFormDialog extends StatefulWidget {
  final ProduitFinancier? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late ProductType _type;
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _rateController;
  late TextEditingController _eligibilityController;
  late TextEditingController _docsController;
  late TextEditingController _feesController;
  late TextEditingController _insuranceController;

  // Credit specific
  CreditCategory? _creditCategory;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;
  late TextEditingController _minDurationController;
  late TextEditingController _maxDurationController;
  InterestCalculationMode? _calcMode;
  RepaymentFrequency? _frequency;

  bool _differePossible = false;
  late TextEditingController _sectorsController;
  late TextEditingController _materialsController;
  late TextEditingController _supportController;
  late TextEditingController _guaranteeController;
  bool _procedureAcceleree = false;
  bool _cautionRequise = false;

  // Savings specific
  SavingsCategory? _savingsCategory;
  late TextEditingController _minBalanceController;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _type = p?.type ?? ProductType.credit;
    _nameController = TextEditingController(text: p?.nom);
    _codeController = TextEditingController(text: p?.code);
    _descController = TextEditingController(text: p?.description);
    _rateController = TextEditingController(
      text: p?.tauxInteret.toString() ?? '0',
    );
    _eligibilityController = TextEditingController(
      text: p?.conditionsEligibilite,
    );
    _docsController = TextEditingController(text: p?.documentsRequis);
    _feesController = TextEditingController(text: p?.fraisCommissions);
    _insuranceController = TextEditingController(
      text: p?.assurancesObligatoires,
    );

    _creditCategory = p?.creditCategory ?? CreditCategory.individuel;
    _minAmountController = TextEditingController(
      text: p?.montantMin?.toString() ?? '0',
    );
    _maxAmountController = TextEditingController(
      text: p?.montantMax?.toString() ?? '0',
    );
    _minDurationController = TextEditingController(
      text: p?.dureeMinMois?.toString() ?? '1',
    );
    _maxDurationController = TextEditingController(
      text: p?.dureeMaxMois?.toString() ?? '12',
    );
    _calcMode =
        p?.modeCalculInteret ?? InterestCalculationMode.decliningBalance;
    _frequency = p?.frequenceRemboursement ?? RepaymentFrequency.monthly;

    _differePossible = p?.differePossible ?? false;
    _sectorsController = TextEditingController(text: p?.secteursEligibles);
    _materialsController = TextEditingController(text: p?.materielFinancable);
    _supportController = TextEditingController(
      text: p?.accompagnementTechnique,
    );
    _guaranteeController = TextEditingController(
      text: p?.garantieSurEquipement,
    );
    _procedureAcceleree = p?.procedureAcceleree ?? false;
    _cautionRequise = p?.cautionSolidaireRequise ?? false;

    _savingsCategory = p?.savingsCategory ?? SavingsCategory.libre;
    _minBalanceController = TextEditingController(
      text: p?.soldeMinimum?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _rateController.dispose();
    _eligibilityController.dispose();
    _docsController.dispose();
    _feesController.dispose();
    _insuranceController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    _sectorsController.dispose();
    _materialsController.dispose();
    _supportController.dispose();
    _guaranteeController.dispose();
    _minBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final product = ProduitFinancier(
        id: widget.product?.id,
        nom: _nameController.text,
        code: _codeController.text,
        description: _descController.text,
        type: _type,
        tauxInteret: double.tryParse(_rateController.text) ?? 0,
        conditionsEligibilite: _eligibilityController.text,
        documentsRequis: _docsController.text,
        fraisCommissions: _feesController.text,
        assurancesObligatoires: _insuranceController.text,
        creditCategory: _type == ProductType.credit ? _creditCategory : null,
        montantMin: _type == ProductType.credit
            ? double.tryParse(_minAmountController.text)
            : null,
        montantMax: _type == ProductType.credit
            ? double.tryParse(_maxAmountController.text)
            : null,
        dureeMinMois: _type == ProductType.credit
            ? int.tryParse(_minDurationController.text)
            : null,
        dureeMaxMois: _type == ProductType.credit
            ? int.tryParse(_maxDurationController.text)
            : null,
        modeCalculInteret: _type == ProductType.credit ? _calcMode : null,
        frequenceRemboursement: _type == ProductType.credit ? _frequency : null,
        differePossible: _type == ProductType.credit ? _differePossible : false,
        secteursEligibles: _type == ProductType.credit
            ? _sectorsController.text
            : null,
        materielFinancable: _type == ProductType.credit
            ? _materialsController.text
            : null,
        accompagnementTechnique: _type == ProductType.credit
            ? _supportController.text
            : null,
        garantieSurEquipement: _type == ProductType.credit
            ? _guaranteeController.text
            : null,
        procedureAcceleree: _type == ProductType.credit
            ? _procedureAcceleree
            : false,
        cautionSolidaireRequise: _type == ProductType.credit
            ? _cautionRequise
            : false,
        savingsCategory: _type == ProductType.epargne ? _savingsCategory : null,
        soldeMinimum: _type == ProductType.epargne
            ? double.tryParse(_minBalanceController.text)
            : null,
      );

      await DatabaseService().insertProduitFinancier(product);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 900),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommonFields(),
                      const SizedBox(height: 24),
                      if (_type == ProductType.credit)
                        _buildCreditFields()
                      else
                        _buildSavingsFields(),
                      const SizedBox(height: 24),
                      _buildManagementFields(),
                    ],
                  ),
                ),
              ),
              const Divider(),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                widget.product == null
                    ? 'Nouveau Produit Financier'
                    : 'Modifier le Produit',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INFORMATIONS GÉNÉRALES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ProductType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de produit',
                  border: OutlineInputBorder(),
                ),
                items: ProductType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code produit (Ex: CI, EL)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Libellé complet du produit',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v?.isEmpty == true ? 'Requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Description commerciale',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _rateController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Taux d\'intérêt annuel (%)',
            border: OutlineInputBorder(),
            suffixText: '%',
            helperText: 'Taux utilisé pour les simulations et calculs',
          ),
          validator: (v) =>
              double.tryParse(v ?? '') == null ? 'Nombre invalide' : null,
        ),
      ],
    );
  }

  Widget _buildCreditFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PARAMÈTRES DE CRÉDIT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CreditCategory>(
          value: _creditCategory,
          decoration: const InputDecoration(
            labelText: 'Catégorie de crédit',
            border: OutlineInputBorder(),
          ),
          items: CreditCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (v) => setState(() => _creditCategory = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant Minimum',
                  border: OutlineInputBorder(),
                  suffixText: 'FCFA',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant Maximum',
                  border: OutlineInputBorder(),
                  suffixText: 'FCFA',
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
                controller: _minDurationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée Min (Mois)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxDurationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée Max (Mois)',
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
              child: DropdownButtonFormField<InterestCalculationMode>(
                value: _calcMode,
                decoration: const InputDecoration(
                  labelText: 'Méthode de calcul',
                  border: OutlineInputBorder(),
                ),
                items: InterestCalculationMode.values
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _calcMode = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<RepaymentFrequency>(
                value: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Fréquence de remboursement',
                  border: OutlineInputBorder(),
                ),
                items: RepaymentFrequency.values
                    .map(
                      (f) => DropdownMenuItem(value: f, child: Text(f.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Spécificités métier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          children: [
            SizedBox(
              width: 200,
              child: CheckboxListTile(
                title: const Text(
                  'Différé autorisé',
                  style: TextStyle(fontSize: 13),
                ),
                value: _differePossible,
                onChanged: (v) => setState(() => _differePossible = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 200,
              child: CheckboxListTile(
                title: const Text(
                  'Instruction accélérée',
                  style: TextStyle(fontSize: 13),
                ),
                value: _procedureAcceleree,
                onChanged: (v) =>
                    setState(() => _procedureAcceleree = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: 240,
              child: CheckboxListTile(
                title: const Text(
                  'Caution solidaire membre',
                  style: TextStyle(fontSize: 13),
                ),
                value: _cautionRequise,
                onChanged: (v) => setState(() => _cautionRequise = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        if (_creditCategory == CreditCategory.agr) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _sectorsController,
            decoration: const InputDecoration(
              labelText: 'Secteurs d\'activité éligibles',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _supportController,
            decoration: const InputDecoration(
              labelText: 'Accompagnement technique prévu',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (_creditCategory == CreditCategory.equipement) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _materialsController,
            decoration: const InputDecoration(
              labelText: 'Types de matériels finançables',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _guaranteeController,
            decoration: const InputDecoration(
              labelText: 'Garanties spécifiques sur équipement',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavingsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PARAMÈTRES D\'ÉPARGNE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<SavingsCategory>(
          value: _savingsCategory,
          decoration: const InputDecoration(
            labelText: 'Catégorie d\'épargne',
            border: OutlineInputBorder(),
          ),
          items: SavingsCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (v) => setState(() => _savingsCategory = v),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _minBalanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Solde minimum à l\'ouverture',
            border: OutlineInputBorder(),
            suffixText: 'FCFA',
          ),
        ),
      ],
    );
  }

  Widget _buildManagementFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GESTION & ÉLIGIBILITÉ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _eligibilityController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Conditions d\'éligibilité détaillées',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _docsController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Pièces justificatives requises',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _feesController,
                decoration: const InputDecoration(
                  labelText: 'Frais et Commissions',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _insuranceController,
                decoration: const InputDecoration(
                  labelText: 'Assurances obligatoires',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Enregistrer le produit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
