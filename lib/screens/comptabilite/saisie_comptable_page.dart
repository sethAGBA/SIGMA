import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/accounting_service.dart';
import '../../models/accounting_account_model.dart';
import '../../models/ecriture_comptable_model.dart';
import '../../models/journal_model.dart';

class SaisieComptablePage extends StatefulWidget {
  const SaisieComptablePage({super.key});

  @override
  State<SaisieComptablePage> createState() => _SaisieComptablePageState();
}

class _SaisieComptablePageState extends State<SaisieComptablePage> {
  final AccountingService _accountingService = AccountingService();
  final _formKey = GlobalKey<FormState>();

  // Header State
  DateTime _dateComptable = DateTime.now();
  Journal? _selectedJournal;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _libelleGlobalController =
      TextEditingController();

  // Data
  List<Journal> _journaux = [];
  List<AccountingAccount> _plansComptables = [];
  bool _isLoading = true;

  // Lines State
  List<LigneEntry> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Start with 2 empty lines
    _lines = [LigneEntry(), LigneEntry()];
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final j = await _accountingService.getJournaux();
      final p = await _accountingService.getAccountingAccounts();
      setState(() {
        _journaux = j;
        _plansComptables = p;
        if (j.isNotEmpty) {
          _selectedJournal = j.firstWhere(
            (element) => element.code == 'OD',
            orElse: () => j.first,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  // --- Header Widgets ---

  Widget _buildHeader(bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En-tête de pièce',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Journal>(
                  isExpanded: true,
                  value: _selectedJournal,
                  items: _journaux.map((j) {
                    return DropdownMenuItem(
                      value: j,
                      child: Text(
                        '${j.code} - ${j.libelle}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedJournal = val),
                  decoration: const InputDecoration(labelText: 'Journal'),
                  validator: (val) => val == null ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateComptable,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _dateComptable = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date Comptable',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_dateComptable),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: 'Admin', // TODO: User name
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Agent de saisie',
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'N° Pièce / Référence',
                    hintText: 'Ex: FACT-001',
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Requis';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _libelleGlobalController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé de l\'opération',
                    hintText: 'Ex: Achat fournitures bureau',
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Requis';
                    return null;
                  },
                  onChanged: (val) {
                    // Update empty line labels
                    for (var line in _lines) {
                      if (line.libelleController.text.isEmpty) {
                        line.libelleController.text = val;
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement scan functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fonctionnalité de scan à implémenter'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Lines Widget ---

  Widget _buildLinesList(bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lignes d\'écriture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une ligne'),
                onPressed: _addLine,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Compte / Libellé')),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Débit / Crédit')),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Tiers / Analytique')),
                SizedBox(width: 40), // Delete button space
              ],
            ),
          ),
          const Divider(),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lines.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final line = _lines[index];
              return _buildSingleLine(line, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLine(LigneEntry line, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Account + Label
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Autocomplete<AccountingAccount>(
                      displayStringForOption: (opt) =>
                          '${opt.numero} - ${opt.libelle}',
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<AccountingAccount>.empty();
                        }
                        return _plansComptables.where((a) {
                          return a.numero.contains(textEditingValue.text) ||
                              a.libelle.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                        });
                      },
                      onSelected: (selection) {
                        line.account = selection;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            if (line.account != null &&
                                controller.text.isEmpty) {
                              controller.text =
                                  '${line.account!.numero} - ${line.account!.libelle}';
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              decoration: const InputDecoration(
                                labelText: 'Compte',
                                hintText: 'Chercher compte...',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (line.account == null) return 'Requis';
                                return null;
                              },
                            );
                          },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: line.libelleController,
                      decoration: const InputDecoration(
                        labelText: 'Libellé Ligne',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requis';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Column 2: Debit + Credit
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    TextFormField(
                      controller: line.debitController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Débit',
                        hintText: '0.0',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: line.creditController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Crédit',
                        hintText: '0.0',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Column 3: Tiers + Analytique
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    TextFormField(
                      controller: line.tiersController, // Need to add to model
                      decoration: const InputDecoration(
                        labelText: 'Client / Tiers',
                        hintText: 'Optionnel',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller:
                          line.analytiqueController, // Need to add to model
                      decoration: const InputDecoration(
                        labelText: 'Analytique (Agence)',
                        hintText: 'Optionnel',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _removeLine(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Logic ---

  void _addLine() {
    setState(() {
      final newLine = LigneEntry();
      // Auto-fill libelle if header exists
      if (_libelleGlobalController.text.isNotEmpty) {
        newLine.libelleController.text = _libelleGlobalController.text;
      }
      _lines.add(newLine);
    });
  }

  void _removeLine(int index) {
    if (_lines.length > 2) {
      setState(() {
        _lines.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il faut au moins 2 lignes')),
      );
    }
  }

  double _getSafeDouble(String val) {
    if (val.isEmpty) return 0.0;
    return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
  }

  double get _totalDebit => _lines.fold(
    0.0,
    (sum, line) => sum + _getSafeDouble(line.debitController.text),
  );
  double get _totalCredit => _lines.fold(
    0.0,
    (sum, line) => sum + _getSafeDouble(line.creditController.text),
  );
  double get _balance => _totalDebit - _totalCredit;
  bool get _isBalanced => _balance.abs() < 0.01;

  Future<void> _validateAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'écriture n\'est pas équilibrée')),
      );
      return;
    }

    if (_lines.any((l) => l.account == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner les comptes pour toutes les lignes',
          ),
        ),
      );
      return;
    }

    // Check strict double entry: at least one debit > 0 and one credit > 0 ?
    // Not strictly required for all journals, but usually yes.
    // For now we trust balance check.

    setState(() => _isLoading = true);

    try {
      final ecriture = EcritureComptable(
        dateComptable: _dateComptable,
        journalCode: _selectedJournal!.code,
        numeroPiece: _refController.text,
        libelle: _libelleGlobalController.text,
        agentSaisie: 'Admin', // TODO: Get logged user
        dateSaisie: DateTime.now(),
        statut: 'VALIDE',
      );

      final lignes = _lines
          .map(
            (l) => LigneEcriture(
              compteNumero: l.account!.numero,
              libelleLigne: l.libelleController.text,
              debit: _getSafeDouble(l.debitController.text),
              credit: _getSafeDouble(l.creditController.text),
              tiers: l.tiersController.text.isNotEmpty
                  ? l.tiersController.text
                  : null,
              refAnalytique: l.analytiqueController.text.isNotEmpty
                  ? l.analytiqueController.text
                  : null,
            ),
          )
          .toList();

      await _accountingService.createEcriture(ecriture, lignes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Écriture validée avec succès')),
        );
        // Reset form for next entry
        _refController.clear();
        _libelleGlobalController.clear();
        setState(() {
          _lines = [LigneEntry(), LigneEntry()];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Saisie Comptable'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildHeader(isDark, cardColor, textColor),
                    const SizedBox(height: 16),
                    _buildLinesList(isDark, cardColor, textColor),
                    const SizedBox(height: 24),

                    // Totals Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isBalanced
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isBalanced ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Débit: ${_totalDebit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Total Crédit: ${_totalCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _isBalanced
                                ? 'ÉQUILIBRÉE'
                                : 'DÉSÉQUILIBRÉE (${_balance.toStringAsFixed(2)})',
                            style: TextStyle(
                              color: _isBalanced ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isBalanced ? _validateAndSave : null,
                            icon: const Icon(Icons.check),
                            label: const Text('Valider'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class LigneEntry {
  AccountingAccount? account;
  final TextEditingController libelleController = TextEditingController();
  final TextEditingController debitController = TextEditingController();
  final TextEditingController creditController = TextEditingController();
  final TextEditingController tiersController = TextEditingController();
  final TextEditingController analytiqueController = TextEditingController();
}
