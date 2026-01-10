import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:afroforma/models/compte_comptable.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:file_picker/file_picker.dart';

class EcritureTemplatesTab extends StatefulWidget {
  @override
  State<EcritureTemplatesTab> createState() => _EcritureTemplatesTabState();
}

class _EcritureTemplatesTabState extends State<EcritureTemplatesTab> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  List<Map<String, Object?>> _accounts = [];
  List<String> _favoriteAccountCodes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService();
    await db.insertDefaultEntryTemplatesIfMissing();
    final rows = await db.getEntryTemplates();
    final accs = await db.getPlanComptable();
    final favs = await db.getTopAccountCodes(limit: 10);
    setState(() {
      _templates = rows;
      _loading = false;
      _accounts = accs;
      _favoriteAccountCodes = favs;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Modèles d\'écritures', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Row(children: [
              OutlinedButton.icon(onPressed: _exportTemplates, icon: const Icon(Icons.file_upload), label: const Text('Exporter')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _importTemplates, icon: const Icon(Icons.file_download), label: const Text('Importer')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: () => _openEditor(), icon: const Icon(Icons.add), label: const Text('Nouveau modèle')),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
            child: _templates.isEmpty
                ? const Center(child: Text('Aucun modèle', style: TextStyle(color: Colors.white70)))
                : ListView.separated(
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (ctx, i) {
                      final t = _templates[i];
                      final lines = _safeLines(t['content'] as String?);
                      return ListTile(
                        title: Text(t['name'] as String, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${lines.length} ligne(s)', style: const TextStyle(color: Colors.white70)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () => _openEditor(existing: t)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Supprimer le modèle ?'),
                                        content: Text('"${t['name']}"'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (ok) {
                                  await DatabaseService().deleteEntryTemplate(t['id'] as String);
                                  _load();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<dynamic> _safeLines(String? content) {
    if (content == null || content.isEmpty) return const [];
    try {
      final parsed = jsonDecode(content);
      if (parsed is List) return parsed;
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing != null ? existing['name'] as String : '');
    final lines = <_TplLine>[];
    final journaux = await DatabaseService().getJournaux();
    String? selectedJournalId = existing != null ? existing['defaultJournalId'] as String? : null;
    if (existing != null) {
      final parsed = _safeLines(existing['content'] as String?);
      for (final e in parsed) {
        lines.add(_TplLine(
          account: (e['account'] ?? '').toString(),
          label: (e['label'] ?? '').toString(),
          debit: (e['debit'] as num?)?.toDouble() ?? 0.0,
          credit: (e['credit'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    }

    bool onlyFavWhenEmpty = true;
    try {
      final pref = await DatabaseService().getPref('ui.onlyFavWhenEmptyFavoritesAutocomplete');
      onlyFavWhenEmpty = (pref == null) ? true : (pref != '0');
    } catch (_) {}
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          void addLine() => setState(() => lines.add(_TplLine()));
          void removeLine(int i) => setState(() => lines.removeAt(i));
          return AlertDialog(
            title: Text(existing == null ? 'Nouveau modèle' : 'Modifier le modèle'),
            content: SizedBox(
              width: 700,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du modèle', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: selectedJournalId,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Aucun journal par défaut')),
                        ...journaux.map((j) => DropdownMenuItem<String?>(value: j['id'] as String, child: Text('${j['code']} - ${j['name']}'))),
                      ],
                      onChanged: (v) => setState(() => selectedJournalId = v),
                      decoration: const InputDecoration(labelText: 'Journal par défaut', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                  Row(children: const [
                    Expanded(child: Text('Compte')), SizedBox(width: 8), Expanded(child: Text('Libellé')), SizedBox(width: 8), SizedBox(width: 100, child: Text('Débit')), SizedBox(width: 8), SizedBox(width: 100, child: Text('Crédit'))
                  ]),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CheckboxListTile(
                      value: onlyFavWhenEmpty,
                      onChanged: (v) async {
                        final val = v ?? true;
                        setState(() => onlyFavWhenEmpty = val);
                        await DatabaseService().setPref('ui.onlyFavWhenEmptyFavoritesAutocomplete', val ? '1' : '0');
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Afficher uniquement les comptes favoris quand le champ est vide', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (_, i) {
                        final l = lines[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Autocomplete<Map<String, Object?>>(
                                  displayStringForOption: (opt) => '${opt['code']} - ${opt['title']}',
                                  optionsBuilder: (TextEditingValue tev) {
                                    final q = tev.text.toLowerCase();
                                    Iterable<Map<String, Object?>> base = _accounts;
                                    if (q.isNotEmpty) {
                                      base = base.where((a) {
                                        final code = (a['code'] ?? '').toString().toLowerCase();
                                        final title = (a['title'] ?? '').toString().toLowerCase();
                                        return code.contains(q) || title.contains(q);
                                      });
                                    }
                                    final list = base.toList();
                                    list.sort((a, b) {
                                      final ac = (a['code'] ?? '').toString();
                                      final bc = (b['code'] ?? '').toString();
                                      final af = _favoriteAccountCodes.contains(ac) ? 0 : 1;
                                      final bf = _favoriteAccountCodes.contains(bc) ? 0 : 1;
                                      final cf = af.compareTo(bf);
                                      return cf != 0 ? cf : ac.compareTo(bc);
                                    });
                                    if (onlyFavWhenEmpty && q.isEmpty && _favoriteAccountCodes.isNotEmpty) {
                                      final favs = list.where((a) => _favoriteAccountCodes.contains((a['code'] ?? '').toString())).toList();
                                      return favs.take(10);
                                    }
                                    return list;
                                  },
                                  onSelected: (opt) {
                                    l.account.text = (opt['code'] ?? '').toString();
                                  },
                                  fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                                    if (l.account.text.isNotEmpty && l.account.text != ctrl.text) ctrl.text = l.account.text;
                                    ctrl.addListener(() {
                                      if (l.account.text != ctrl.text) l.account.text = ctrl.text;
                                    });
                                    return TextField(controller: ctrl, focusNode: focus, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Code (ex: 701, 512)'));
                                  },
                                  optionsViewBuilder: (context, onSelected, options) => Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (_, idx) {
                                            final opt = options.elementAt(idx);
                                            return ListTile(
                                              title: Text('${opt['code']} - ${opt['title']}'),
                                              onTap: () => onSelected(opt),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Épingler ce compte',
                                icon: Icon(
                                  _favoriteAccountCodes.contains(l.account.text.trim()) ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                ),
                                onPressed: () async {
                                  final code = l.account.text.trim();
                                  if (code.isEmpty) return;
                                  final pinned = _favoriteAccountCodes.contains(code);
                                  await DatabaseService().setPinnedAccount(code, !pinned);
                                  final favs = await DatabaseService().getTopAccountCodes(limit: 10);
                                  setState(() => _favoriteAccountCodes = favs);
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: l.label, decoration: const InputDecoration(border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              SizedBox(width: 100, child: TextField(controller: l.debit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              SizedBox(width: 100, child: TextField(controller: l.credit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder()))),
                              IconButton(onPressed: () => removeLine(i), icon: const Icon(Icons.remove_circle, color: Colors.redAccent)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(onPressed: addLine, icon: const Icon(Icons.add), label: const Text('Ajouter une ligne')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  final id = existing?['id'] as String? ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}';
                  final content = lines
                      .map((l) => {
                            'account': l.account.text.trim(),
                            'label': l.label.text.trim(),
                            'debit': double.tryParse(l.debit.text.replaceAll(',', '.')) ?? 0.0,
                            'credit': double.tryParse(l.credit.text.replaceAll(',', '.')) ?? 0.0,
                          })
                      .toList();
                  await DatabaseService().upsertEntryTemplate(
                    id: id,
                    name: nameCtrl.text.trim().isEmpty ? 'Modèle' : nameCtrl.text.trim(),
                    contentJson: jsonEncode(content),
                    defaultJournalId: selectedJournalId,
                  );
                  Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _exportTemplates() async {
    try {
      final rows = await DatabaseService().getEntryTemplates();
      final jsonStr = jsonEncode(rows);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter les modèles',
        fileName: 'templates_ecritures.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(jsonStr);
      _showSnack('Exporté vers $path');
    } catch (e) {
      _showSnack('Erreur export: $e', error: true);
    }
  }

  Future<void> _importTemplates() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (res == null || res.files.single.path == null) return;
      final content = await File(res.files.single.path!).readAsString();
      final List data = jsonDecode(content) as List;
      final db = DatabaseService();
      for (final t in data) {
        final m = t as Map<String, dynamic>;
        await db.upsertEntryTemplate(
          id: (m['id'] ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}').toString(),
          name: (m['name'] ?? 'Modèle').toString(),
          contentJson: (m['content'] ?? '[]').toString(),
          defaultJournalId: (m['defaultJournalId'] as String?),
        );
      }
      await _load();
      _showSnack('Modèles importés');
    } catch (e) {
      _showSnack('Erreur import: $e', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }
}

class _TplLine {
  final TextEditingController account = TextEditingController();
  final TextEditingController label = TextEditingController();
  final TextEditingController debit = TextEditingController(text: '0.00');
  final TextEditingController credit = TextEditingController(text: '0.00');

  _TplLine({String account = '', String label = '', double debit = 0.0, double credit = 0.0}) {
    this.account.text = account;
    this.label.text = label;
    this.debit.text = debit.toStringAsFixed(2);
    this.credit.text = credit.toStringAsFixed(2);
  }
}
