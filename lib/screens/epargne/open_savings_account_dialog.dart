// lib/screens/epargne/open_savings_account_dialog.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/client_model.dart';
import '../../models/produit_financier_model.dart';
import '../../models/savings_account_model.dart';

class OpenSavingsAccountDialog extends StatefulWidget {
  const OpenSavingsAccountDialog({super.key});

  @override
  State<OpenSavingsAccountDialog> createState() =>
      _OpenSavingsAccountDialogState();
}

class _OpenSavingsAccountDialogState extends State<OpenSavingsAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  List<Client> _clients = [];
  List<ProduitFinancier> _products = [];
  Client? _selectedClient;
  ProduitFinancier? _selectedProduct;
  final _accountNumberController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final clients = await _db.getClients();
      final products = await _db.getProduits(); // On filtrera par type éparge
      setState(() {
        _clients = clients;
        _products = products
            .where((p) => p.type == ProductType.epargne)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement: $e')));
      }
    }
  }

  void _generateAccountNumber() {
    if (_selectedClient == null || _selectedProduct == null) return;

    final dateStr = DateTime.now()
        .toString()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(2, 8);
    final random = (DateTime.now().millisecond % 1000).toString().padLeft(
      3,
      '0',
    );
    final code = _selectedProduct!.code;

    setState(() {
      _accountNumberController.text = '$code-$dateStr-$random';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedClient == null ||
        _selectedProduct == null)
      return;

    setState(() => _isLoading = true);

    final account = SavingsAccount(
      clientId: _selectedClient!.id!,
      produitId: _selectedProduct!.id!,
      numeroCompte: _accountNumberController.text,
      statut: SavingsAccountStatus.actif,
      dateOuverture: DateTime.now(),
      tauxInteretApplique: _selectedProduct!.tauxInteret,
    );

    try {
      await _db.insertSavingsAccount(account);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: _isLoading && _products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ouverture de Compte Épargne',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lier un client à un nouveau produit d\'épargne',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // Sélection Client
                    const Text(
                      'Client',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Client>(
                      value: _selectedClient,
                      items: _clients
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.nom} ${c.prenoms} (${c.numeroClient})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedClient = val;
                          _generateAccountNumber();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Choisir un client',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) =>
                          val == null ? 'Veuillez choisir un client' : null,
                    ),

                    const SizedBox(height: 20),

                    // Sélection Produit
                    const Text(
                      'Produit d\'Épargne',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProduitFinancier>(
                      value: _selectedProduct,
                      items: _products
                          .map(
                            (p) =>
                                DropdownMenuItem(value: p, child: Text(p.nom)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedProduct = val;
                          _generateAccountNumber();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Choisir un produit',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) =>
                          val == null ? 'Veuillez choisir un produit' : null,
                    ),

                    const SizedBox(height: 20),

                    // Numéro de compte
                    const Text(
                      'Numéro de Compte',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: InputDecoration(
                        hintText: 'Généré automatiquement',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _generateAccountNumber,
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Champ obligatoire'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ANNULER'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'OUVRIR LE COMPTE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
