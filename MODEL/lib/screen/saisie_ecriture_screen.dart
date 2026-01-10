import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/compte_comptable.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

// A single line in the journal entry
class EcritureLine {
  final String id;
  final TextEditingController accountController;
  final TextEditingController labelController;
  final TextEditingController debitController;
  final TextEditingController creditController;
  final TextEditingController lettrageController;
  String? selectedAccountId;

  EcritureLine() 
      : id = DateTime.now().microsecondsSinceEpoch.toString(),
        accountController = TextEditingController(),
        labelController = TextEditingController(),
        debitController = TextEditingController(text: '0.00'),
        creditController = TextEditingController(text: '0.00'),
        lettrageController = TextEditingController();
}

class SaveIntent extends Intent { const SaveIntent(); }
class AddLineIntent extends Intent { const AddLineIntent(); }

class SaisieEcritureScreen extends StatefulWidget {
  final List<CompteComptable> accounts;
  final List<Map<String, Object?>> journaux;

  const SaisieEcritureScreen({
    Key? key,
    required this.accounts,
    required this.journaux,
  }) : super(key: key);

  @override
  _SaisieEcritureScreenState createState() => _SaisieEcritureScreenState();
}

class _SaisieEcritureScreenState extends State<SaisieEcritureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _referenceController = TextEditingController();
  final _libelleGeneralController = TextEditingController();
  final FocusNode _libelleGeneralFocus = FocusNode();
  String _lastGeneralLabel = '';
  bool _onlyFavWhenEmpty = true;
  String? _selectedJournalId;
  final List<EcritureLine> _lines = [];
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  String? _nextPiecePreview;
  String _selectedTemplate = 'Aucun';
  List<Map<String, dynamic>> _templates = const [
    {'id': 'none', 'name': 'Aucun', 'content': '[]'},
  ];
  List<String> _favoriteAccountCodes = const [];
  List<String> _pinnedAccountCodes = const [];

  @override
  void initState() {
    super.initState();
    if (widget.journaux.isNotEmpty) {
      _selectedJournalId = widget.journaux.first['id'] as String?;
    }
    // Start with two empty lines
    _addNewLine();
    _addNewLine();
    _refreshNextPiecePreview();
    _libelleGeneralController.addListener(() {
      // Live assist: keep any line whose label equals the previous general label (or empty) in sync
      final current = _libelleGeneralController.text;
      for (final l in _lines) {
        final lbl = l.labelController.text;
        if (lbl.isEmpty || lbl == _lastGeneralLabel) {
          l.labelController.text = current;
        }
      }
      _lastGeneralLabel = current;
    });
    _libelleGeneralFocus.addListener(() {
      if (!_libelleGeneralFocus.hasFocus) {
        _applyGeneralLabel();
      }
    });
    _loadTemplates();
    _loadFavorites();
    _loadOnlyFavPref();
  }

  @override
  void dispose() {
    _libelleGeneralFocus.dispose();
    super.dispose();
  }

  void _addNewLine() {
    setState(() {
      _lines.add(EcritureLine());
      // Prefill label from general label if present
      final last = _lines.last;
      if (_libelleGeneralController.text.isNotEmpty && last.labelController.text.isEmpty) {
        last.labelController.text = _libelleGeneralController.text;
      }
    });
  }

  void _removeLine(String id) {
    setState(() {
      _lines.removeWhere((line) => line.id == id);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    double debit = 0.0;
    double credit = 0.0;
    for (final line in _lines) {
      debit += double.tryParse(line.debitController.text.replaceAll(',', '.')) ?? 0.0;
      credit += double.tryParse(line.creditController.text.replaceAll(',', '.')) ?? 0.0;
    }
    setState(() {
      _totalDebit = debit;
      _totalCredit = credit;
    });
  }

  Future<void> _saveEcriture() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_totalDebit != _totalCredit) {
      _showError('L\'écriture doit être équilibrée.');
      return;
    }
    if (_totalDebit == 0) {
      _showError('L\'écriture ne peut pas être nulle.');
      return;
    }

    // Validate every used line has a valid/known account, otherwise prompt to create
    for (final line in _lines) {
      final d = double.tryParse(line.debitController.text.replaceAll(',', '.')) ?? 0.0;
      final c = double.tryParse(line.creditController.text.replaceAll(',', '.')) ?? 0.0;
      if (d == 0.0 && c == 0.0) continue;
      if (line.selectedAccountId == null || line.selectedAccountId!.isEmpty) {
        await _handleUnknownAccount(line.accountController, line);
        if (line.selectedAccountId == null || line.selectedAccountId!.isEmpty) {
          _showError('Veuillez choisir ou créer le compte pour toutes les lignes utilisées.');
          return;
        }
      }
    }

    final db = DatabaseService();
    final journalId = _selectedJournalId;
    if (journalId == null) {
      _showError('Veuillez sélectionner un journal.');
      return;
    }

    final pieceNumber = await db.getNextPieceNumberForJournal(journalId);
    final pieceId = DateTime.now().millisecondsSinceEpoch.toString();
    final date = DateTime.tryParse(_dateController.text);
    if (date == null) {
      _showError('Date invalide.');
      return;
    }

    try {
      for (final line in _lines) {
        final accountCode = line.selectedAccountId;
        if (accountCode == null || accountCode.isEmpty) continue;

        final debit = double.tryParse(line.debitController.text.replaceAll(',', '.')) ?? 0.0;
        final credit = double.tryParse(line.creditController.text.replaceAll(',', '.')) ?? 0.0;

        if (debit == 0.0 && credit == 0.0) continue;
        final lettrage = line.lettrageController.text.trim();
        if (lettrage.isNotEmpty) {
          // Best-effort: ensure lettrage exists
          await db.insertLettrage({'id': lettrage, 'label': lettrage, 'createdAt': DateTime.now().millisecondsSinceEpoch});
        }

        await db.insertEcriture({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'pieceId': pieceId,
          'pieceNumber': pieceNumber,
          'date': date.millisecondsSinceEpoch,
          'journalId': journalId,
          'reference': _referenceController.text,
          'accountCode': accountCode,
          'label': line.labelController.text,
          'debit': debit,
          'credit': credit,
          'lettrageId': lettrage.isEmpty ? null : lettrage,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      NotificationService().showNotification(NotificationItem(id: 'ecriture_ok', message: 'Écriture enregistrée avec succès.'));
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      _showError('Erreur lors de l\'enregistrement: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _handleUnknownAccount(TextEditingController controller, EcritureLine line) async {
    final initialCode = controller.text;
    if (initialCode.isEmpty) return;

    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte introuvable'),
        content: Text('Le compte "$initialCode" n\'existe pas. Voulez-vous le créer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Créer')),
        ],
      ),
    );

    if (create == true) {
      final newAccount = await _showCreateAccountDialog(initialCode);
      if (newAccount != null) {
        setState(() {
          widget.accounts.add(newAccount);
          line.selectedAccountId = newAccount.code;
          controller.text = '${newAccount.code} - ${newAccount.title}';
        });
      }
    }
  }

  Future<CompteComptable?> _showCreateAccountDialog(String initialCode) {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: initialCode);
    final titleController = TextEditingController();
    String? parentId;

    return showDialog<CompteComptable>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer un nouveau compte'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code du compte'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Code requis';
                  if (widget.accounts.any((acc) => acc.code == value)) return 'Ce code existe déjà';
                  return null;
                },
              ),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Intitulé du compte'),
                validator: (value) => (value == null || value.isEmpty) ? 'Intitulé requis' : null,
              ),
              DropdownButtonFormField<String?>(
                value: parentId,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Aucun (racine)')),
                  ...widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.code} - ${a.title}', overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) => parentId = value,
                decoration: const InputDecoration(labelText: 'Compte parent'),
                isExpanded: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newAccount = CompteComptable(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  code: codeController.text,
                  title: titleController.text,
                  parentId: parentId,
                );
                try {
                  await DatabaseService().insertCompte({'id': newAccount.id, 'code': newAccount.code, 'title': newAccount.title, 'parentId': newAccount.parentId});
                  Navigator.of(ctx).pop(newAccount);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN): const AddLineIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const AddLineIntent(),
      },
      actions: <Type, Action<Intent>>{
        SaveIntent: CallbackAction<SaveIntent>(onInvoke: (intent) {
          final balance = _totalDebit - _totalCredit;
          final isBalanced = balance.abs() < 0.01 && _totalDebit > 0;
          if (isBalanced) {
            _saveEcriture();
          }
          return null;
        }),
        AddLineIntent: CallbackAction<AddLineIntent>(onInvoke: (intent) {
          _addNewLine();
          return null;
        }),
      },
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLinesHeader(),
              Flexible(child: _buildLines()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                    validator: (value) => (value?.isEmpty ?? true) ? 'Date requise' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedJournalId,
                    items: widget.journaux.map((j) => DropdownMenuItem(
                      value: j['id'] as String,
                      child: Text(j['name'] as String? ?? ''),
                    )).toList(),
                    onChanged: (value) async {
                      setState(() => _selectedJournalId = value);
                      await _refreshNextPiecePreview();
                    },
                    decoration: const InputDecoration(labelText: 'Journal', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(labelText: 'Référence pièce', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _libelleGeneralController,
                    focusNode: _libelleGeneralFocus,
                    decoration: const InputDecoration(labelText: 'Libellé général', border: OutlineInputBorder()),
                    onEditingComplete: () {
                      _applyGeneralLabel();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Prochaine pièce', border: OutlineInputBorder()),
                    child: Text(_nextPiecePreview ?? '—'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTemplate,
                    items: _templates.map((t) => DropdownMenuItem(
                      value: t['name'] as String,
                      child: Text(t['name'] as String),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _selectedTemplate = val ?? 'Aucun');
                      _applyTemplate(_selectedTemplate);
                    },
                    decoration: const InputDecoration(labelText: 'Modèle', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showPasteDialog,
                  icon: const Icon(Icons.paste),
                  label: const Text('Coller (Excel/CSV)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: CheckboxListTile(
                value: _onlyFavWhenEmpty,
                onChanged: (v) async {
                  final val = v ?? true;
                  setState(() => _onlyFavWhenEmpty = val);
                  await DatabaseService().setPref('ui.onlyFavWhenEmptyFavoritesAutocomplete', val ? '1' : '0');
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Afficher uniquement les comptes favoris quand le champ est vide', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('Compte', style: TextStyle(fontWeight: FontWeight.bold))),
          const Expanded(flex: 4, child: Text('Libellé', style: TextStyle(fontWeight: FontWeight.bold))),
          const Expanded(flex: 2, child: Text('Débit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
          const Expanded(flex: 2, child: Text('Crédit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
          const Expanded(flex: 2, child: Text('Lettrage', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 48), // For delete button
        ],
      ),
    );
  }

  Widget _buildLines() {
    return ListView.builder(
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Autocomplete<CompteComptable>(
                  displayStringForOption: (CompteComptable option) => '${option.code} - ${option.title}',
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final q = textEditingValue.text.toLowerCase();
                    Iterable<CompteComptable> base = widget.accounts;
                    if (q.isNotEmpty) {
                      base = base.where((o) => o.title.toLowerCase().contains(q) || o.code.toLowerCase().contains(q));
                    }
                    final list = base.toList();
                    // Favorites first
                    list.sort((a, b) {
                      final af = _favoriteAccountCodes.contains(a.code) ? 0 : 1;
                      final bf = _favoriteAccountCodes.contains(b.code) ? 0 : 1;
                      final cf = af.compareTo(bf);
                      return cf != 0 ? cf : a.code.compareTo(b.code);
                    });
                    // If no query and we have favorites, return only top favorites (max 10)
                    if (_onlyFavWhenEmpty && q.isEmpty && _favoriteAccountCodes.isNotEmpty) {
                      final favs = list.where((o) => _favoriteAccountCodes.contains(o.code)).toList();
                      return favs.take(10);
                    }
                    return list;
                  },
                  onSelected: (CompteComptable selection) {
                    setState(() {
                      line.selectedAccountId = selection.code;
                      line.accountController.text = '${selection.code} - ${selection.title}';
                    });
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    // Sync provided controller with our line controller so Autocomplete filtering stays live
                    if (line.accountController.text.isNotEmpty && line.accountController.text != fieldTextEditingController.text) {
                      fieldTextEditingController.text = line.accountController.text;
                    }
                    fieldTextEditingController.addListener(() {
                      if (line.accountController.text != fieldTextEditingController.text) {
                        line.accountController.text = fieldTextEditingController.text;
                      }
                    });
                    return TextFormField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Code ou nom du compte',
                      ),
                      onEditingComplete: () {
                        final text = fieldTextEditingController.text.trim();
                        final account = widget.accounts.firstWhere(
                          (acc) => acc.code == text || '${acc.code} - ${acc.title}' == text,
                          orElse: () => CompteComptable(id: '', code: '', title: ''),
                        );
                        if (account.id.isNotEmpty) {
                          setState(() {
                            line.selectedAccountId = account.code;
                            fieldTextEditingController.text = '${account.code} - ${account.title}';
                          });
                        } else {
                          _handleUnknownAccount(fieldTextEditingController, line);
                        }
                        fieldFocusNode.unfocus();
                      },
                    );
                  },
                  optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<CompteComptable> onSelected, Iterable<CompteComptable> options) {
                      return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                              elevation: 4.0,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
                                child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                        final CompteComptable option = options.elementAt(index);
                                        return InkWell(
                                            onTap: () {
                                                onSelected(option);
                                            },
                                            child: ListTile(
                                                title: Text('${option.code} - ${option.title}'),
                                            ),
                                        );
                                    },
                                ),
                              ),
                          ),
                      );
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Épingler ce compte',
                icon: Icon(
                  _pinnedAccountCodes.contains(line.selectedAccountId ?? '') ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () async {
                  final code = line.selectedAccountId ?? '';
                  if (code.isEmpty) return;
                  final pinned = _pinnedAccountCodes.contains(code);
                  await DatabaseService().setPinnedAccount(code, !pinned);
                  final favs = await DatabaseService().getTopAccountCodes(limit: 10);
                  final pins = await DatabaseService().getPinnedAccountCodes();
                  setState(() {
                    _favoriteAccountCodes = favs;
                    _pinnedAccountCodes = pins;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: line.labelController,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.debitController,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (value) {
                    if (double.tryParse(value.replaceAll(',', '.')) != 0) {
                      line.creditController.text = '0.00';
                    }
                    _calculateTotals();
                  },
                  onEditingComplete: () {
                    if (index == _lines.length - 1) {
                      _addNewLine();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.creditController,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (value) {
                    if (double.tryParse(value.replaceAll(',', '.')) != 0) {
                      line.debitController.text = '0.00';
                    }
                    _calculateTotals();
                  },
                  onEditingComplete: () {
                    if (index == _lines.length - 1) {
                      _addNewLine();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.lettrageController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Code'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removeLine(line.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final balance = _totalDebit - _totalCredit;
    final isBalanced = balance.abs() < 0.01;

    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(children: [Icon(Icons.keyboard, size: 18, color: Colors.white70), SizedBox(width: 6), Text('Entrée ou Ctrl/Cmd+N: ajoute une ligne', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                    SizedBox(height: 2),
                    Row(children: [Icon(Icons.lock_clock, size: 18, color: Colors.white70), SizedBox(width: 6), Text('Enregistrer actif si équilibré et non nul (Ctrl/Cmd+S)', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                    SizedBox(height: 2),
                    Row(children: [Icon(Icons.short_text, size: 18, color: Colors.white70), SizedBox(width: 6), Text('Libellé général recopié sur les lignes vides', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                  ],
                ),
                Row(
                  children: [
                    Text('Total Débit: ${_currencyFormat.format(_totalDebit)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 32),
                    Text('Total Crédit: ${_currencyFormat.format(_totalCredit)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  isBalanced ? 'ÉQUILIBRÉ' : 'Déséquilibre: ${_currencyFormat.format(balance)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isBalanced ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Ajouter une ligne'),
                    onPressed: _addNewLine,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.balance),
                    label: const Text('Équilibrer'),
                    onPressed: _equilibrer,
                  ),
                ]),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer l\'écriture'),
                  onPressed: isBalanced && _totalDebit > 0 ? _saveEcriture : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshNextPiecePreview() async {
    try {
      if (_selectedJournalId == null || _selectedJournalId!.isEmpty) {
        setState(() => _nextPiecePreview = null);
        return;
      }
      final preview = await DatabaseService().peekNextPieceNumberForJournal(_selectedJournalId!);
      setState(() => _nextPiecePreview = preview);
    } catch (_) {
      setState(() => _nextPiecePreview = null);
    }
  }

  void _applyTemplate(String name) {
    final tpl = _templates.firstWhere((t) => t['name'] == name, orElse: () => _templates.first);
    if (tpl['id'] == 'none') return; // Aucun
    final content = (tpl['content'] as String?) ?? '[]';
    List<dynamic> linesJson;
    try { linesJson = (jsonDecode(content) as List); } catch (_) { linesJson = const []; }
    if (linesJson.isEmpty) return;
    setState(() {
      // Preselect default journal if provided
      final dj = tpl['defaultJournalId'] as String?;
      if (dj != null && dj.isNotEmpty) {
        final exists = widget.journaux.any((j) => (j['id'] as String) == dj);
        if (exists) {
          _selectedJournalId = dj;
          _refreshNextPiecePreview();
        }
      }
      _lines.clear();
      _libelleGeneralController.text = name;
      for (final e in linesJson) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
        final line = EcritureLine();
        final accountStr = (m['account'] as String? ?? '').trim();
        // try exact match, then prefix
        CompteComptable? matched;
        matched = widget.accounts.firstWhere(
          (a) => a.code == accountStr,
          orElse: () => CompteComptable(id: '', code: '', title: ''),
        );
        if (matched.id.isEmpty && accountStr.isNotEmpty) {
          matched = widget.accounts.firstWhere(
            (a) => a.code.startsWith(accountStr),
            orElse: () => CompteComptable(id: '', code: '', title: ''),
          );
        }
        if (matched.id.isNotEmpty) {
          line.selectedAccountId = matched.code;
          line.accountController.text = '${matched.code} - ${matched.title}';
        }
        line.labelController.text = m['label'] as String? ?? name;
        final d = (m['debit'] as num?)?.toDouble() ?? 0.0;
        final c = (m['credit'] as num?)?.toDouble() ?? 0.0;
        line.debitController.text = d.toStringAsFixed(2);
        line.creditController.text = c.toStringAsFixed(2);
        _lines.add(line);
      }
      _calculateTotals();
    });
  }

  Future<void> _loadTemplates() async {
    try {
      final db = DatabaseService();
      await db.insertDefaultEntryTemplatesIfMissing();
      final rows = await db.getEntryTemplates();
      setState(() {
        _templates = [
          {'id': 'none', 'name': 'Aucun', 'content': '[]'},
          ...rows,
        ];
      });
    } catch (_) {}
  }

  Future<void> _loadFavorites() async {
    try {
      final codes = await DatabaseService().getTopAccountCodes(limit: 10);
      final pins = await DatabaseService().getPinnedAccountCodes();
      setState(() {
        _favoriteAccountCodes = codes;
        _pinnedAccountCodes = pins;
      });
    } catch (_) {}
  }

  Future<void> _loadOnlyFavPref() async {
    try {
      final s = await DatabaseService().getPref('ui.onlyFavWhenEmptyFavoritesAutocomplete');
      setState(() => _onlyFavWhenEmpty = (s == null) ? true : (s != '0'));
    } catch (_) {}
  }

  void _applyGeneralLabel() {
    final current = _libelleGeneralController.text.trim();
    if (current == _lastGeneralLabel) return;
    setState(() {
      for (final l in _lines) {
        final lbl = l.labelController.text.trim();
        if (lbl.isEmpty || lbl == _lastGeneralLabel) {
          l.labelController.text = current;
        }
      }
      _lastGeneralLabel = current;
    });
  }

  Future<void> _showPasteDialog() async {
    final textController = TextEditingController();
    final replace = ValueNotifier<bool>(true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coller des lignes (Compte; Libellé; Débit; Crédit)'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 10,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Collez ici (tab, ; ou , comme séparateur)'),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: replace,
                builder: (context, v, _) => CheckboxListTile(
                  value: v,
                  onChanged: (nv) => replace.value = nv ?? true,
                  title: const Text('Remplacer les lignes existantes'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Appliquer')),
        ],
      ),
    );
    if (confirmed != true) return;
    final rows = _parsePastedText(textController.text);
    if (rows.isEmpty) return;
    final unknown = <String>{};
    for (final r in rows) {
      final acc = widget.accounts.firstWhere(
        (a) => a.code == r['account'],
        orElse: () => CompteComptable(id: '', code: '', title: ''),
      );
      if (acc.id.isEmpty) unknown.add(r['account'] as String);
    }
    if (unknown.isNotEmpty) {
      _showError('Comptes inconnus: ${unknown.join(', ')}');
      return;
    }
    setState(() {
      if (replace.value) _lines.clear();
      for (final r in rows) {
        final acc = widget.accounts.firstWhere((a) => a.code == r['account']);
        final line = EcritureLine();
        line.selectedAccountId = acc.code;
        line.accountController.text = '${acc.code} - ${acc.title}';
        line.labelController.text = (r['label'] as String?) ?? _libelleGeneralController.text;
        line.debitController.text = (r['debit'] as double).toStringAsFixed(2);
        line.creditController.text = (r['credit'] as double).toStringAsFixed(2);
        _lines.add(line);
      }
      _calculateTotals();
    });
  }

  List<Map<String, dynamic>> _parsePastedText(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
    final List<Map<String, dynamic>> out = [];
    for (final raw in lines) {
      final line = raw.trim();
      String sep = '\t';
      if (line.contains(';')) sep = ';';
      else if (line.contains('\t')) sep = '\t';
      else if (line.contains(',')) sep = ',';
      final parts = line.split(sep).map((s) => s.trim()).toList();
      if (parts.length < 4) continue;
      final account = parts[0];
      final label = parts[1];
      double debit = double.tryParse(parts[2].replaceAll(',', '.')) ?? 0.0;
      double credit = double.tryParse(parts[3].replaceAll(',', '.')) ?? 0.0;
      if (debit == 0.0 && credit == 0.0) continue;
      out.add({'account': account, 'label': label, 'debit': debit, 'credit': credit});
    }
    return out;
  }

  Future<void> _equilibrer() async {
    final balance = _totalDebit - _totalCredit;
    if (balance.abs() < 0.01) return; // Already balanced
    CompteComptable? chosen;
    await showDialog(
      context: context,
      builder: (ctx) {
        CompteComptable? selected;
        return AlertDialog(
          title: const Text('Compte d\'équilibrage'),
          content: SizedBox(
            width: 500,
            child: Autocomplete<CompteComptable>(
              displayStringForOption: (o) => '${o.code} - ${o.title}',
              optionsBuilder: (TextEditingValue t) {
                final q = t.text.toLowerCase();
                if (q.isEmpty) return widget.accounts;
                return widget.accounts.where((o) => o.code.toLowerCase().contains(q) || o.title.toLowerCase().contains(q));
              },
              onSelected: (o) => selected = o,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                controller: controller,
                focusNode: focus,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Saisir code ou nom de compte'),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(onPressed: () { chosen = selected; Navigator.of(ctx).pop(); }, child: const Text('Appliquer')),
          ],
        );
      },
    );
    if (chosen == null) return;
    setState(() {
      final line = EcritureLine();
      line.selectedAccountId = chosen!.code;
      line.accountController.text = '${chosen!.code} - ${chosen!.title}';
      line.labelController.text = _libelleGeneralController.text.isNotEmpty ? _libelleGeneralController.text : 'Équilibrage';
      if (balance > 0) {
        // more debit than credit -> add credit
        line.creditController.text = balance.abs().toStringAsFixed(2);
        line.debitController.text = '0.00';
      } else {
        line.debitController.text = balance.abs().toStringAsFixed(2);
        line.creditController.text = '0.00';
      }
      _lines.add(line);
      _calculateTotals();
    });
  }
}
