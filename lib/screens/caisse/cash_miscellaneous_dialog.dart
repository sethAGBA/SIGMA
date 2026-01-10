// lib/screens/caisse/cash_miscellaneous_dialog.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/cash_operation_model.dart';

class CashMiscellaneousDialog extends StatefulWidget {
  const CashMiscellaneousDialog({super.key});

  @override
  State<CashMiscellaneousDialog> createState() =>
      _CashMiscellaneousDialogState();
}

class _CashMiscellaneousDialogState extends State<CashMiscellaneousDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  bool _isLoading = false;
  CashOperationType _type = CashOperationType.sortie; // Default to Expense
  String _selectedCategory = 'AUTRE';

  final List<String> _expenseCategories = [
    'SALAIRE',
    'LOYER',
    'ELECTRICITE',
    'EAU',
    'INTERNET',
    'FOURNITURES',
    'MAINTENANCE',
    'AUTRE',
  ];
  final List<String> _incomeCategories = [
    'CHANGE',
    'EXCEDENT',
    'DIVERS',
    'AUTRE',
  ];

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTypeSelection(isDark),
              const SizedBox(height: 24),
              _buildFormFields(isDark),
              const SizedBox(height: 32),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.widgets_rounded, color: Colors.purple),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opération Diverse',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Enregistrement manuel (Charges, Recettes diverses)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSelection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeButton(
              'DÉPENSE',
              CashOperationType.sortie,
              Colors.orange,
            ),
          ),
          Expanded(
            child: _typeButton(
              'RECETTE',
              CashOperationType.entree,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String label, CashOperationType value, Color color) {
    bool isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() {
        _type = value;
        _selectedCategory = 'AUTRE'; // Reset category
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(bool isDark) {
    final categories = _type == CashOperationType.sortie
        ? _expenseCategories
        : _incomeCategories;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) => setState(() => _selectedCategory = val!),
          decoration: InputDecoration(
            labelText: 'Catégorie',
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Montant',
            prefixIcon: const Icon(Icons.payments_outlined),
            suffixText: 'FCFA',
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Libellé / Description',
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _referenceController,
          decoration: InputDecoration(
            labelText: 'N° Pièce / Référence (Facultatif)',
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ANNULER'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'ENREGISTRER',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseService().database;
      final montant = double.parse(_amountController.text);

      // Determine standardized category based on selection
      // Map manual categories to CashOperationCategory enum if possible, or use AUTRE/FRAIS
      CashOperationCategory dbCategory = CashOperationCategory.autre;
      if (_type == CashOperationType.sortie && _selectedCategory != 'AUTRE') {
        // Charges are generally "AUTRE" in the strict enum unless we expand the enum,
        // but for now we'll stick to 'AUTRE' or 'FRAIS' if applicable.
        // Let's use 'AUTRE' and put the specific subtype in libelle or reference?
        // Actually, if it's 'SALAIRE' etc, we should probably keep 'AUTRE' in category
        // but ensure the libelle is explicit.
        // However, the specification mentioned specific types.
        // Let's keep category as 'AUTRE' or 'FRAIS' for expenses.
        dbCategory = CashOperationCategory.autre;
      }

      await db.insert('operations_caisse', {
        'type_operation': _type == CashOperationType.entree
            ? 'ENTREE'
            : 'SORTIE',
        'categorie': dbCategory.value,
        'montant': montant,
        'libelle': '${_selectedCategory} - ${_descriptionController.text}',
        'reference_externe': _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        'agent_operation': 'Admin', // To be replaced by auth service
        'date_operation': DateTime.now().toIso8601String(),
        'mode_paiement': 'ESPECES', // Default for cash desk operations
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opération enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
