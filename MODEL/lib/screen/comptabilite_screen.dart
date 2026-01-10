import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'saisie_ecriture_screen.dart';
import 'grand_livre_screen.dart';
import 'balance_generale_screen.dart';
import 'bilan_screen.dart';
import 'compte_resultat_screen.dart';
import 'tresorerie_screen.dart';
import 'declarations_fiscales_screen.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/compte_comptable.dart';
import '../models/ecriture_comptable.dart';
// journal and lettrage models currently not referenced directly in this file

class ComptabiliteScreen extends StatefulWidget {
  @override
  _ComptabiliteScreenState createState() => _ComptabiliteScreenState();
}

class _ComptabiliteScreenState extends State<ComptabiliteScreen> {
  // Comptabilité menu gradient (matches main_screen menu item)
  static const Gradient comptaGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // State fields for accounts and journal
  final List<CompteComptable> _accounts = [];
  String? _selectedAccountId;
  final List<Map<String, Object?>> _journaux = [];

  final List<EcritureComptable> _journalEntries = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedJournal = 'Tous';
  final TextEditingController _searchController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _currencyFormat = NumberFormat("#,##0.00", "fr_FR");

  @override
  void initState() {
    super.initState();
    _loadComptaData();
  }

  Future<void> _loadComptaData() async {
    final db = DatabaseService();
    // load journaux with migration for defaults
    final existingJournaux = await db.getJournaux();
    final existingCodes = existingJournaux.map((j) => j['code'] as String?).toSet();

    final defaults = [
      {'id': 'j_ach', 'code': 'ACH', 'name': 'Achats', 'description': 'Journal des achats', 'type': 'ACHATS'},
      {'id': 'j_ventes', 'code': 'VTE', 'name': 'Ventes', 'description': 'Journal des ventes', 'type': 'VENTES'},
      {'id': 'j_banque', 'code': 'BQ', 'name': 'Banque', 'description': 'Journal des opérations bancaires', 'type': 'BANQUE'},
      {'id': 'j_caisse', 'code': 'CAI', 'name': 'Caisse', 'description': 'Journal des espèces', 'type': 'CAISSE'},
      {'id': 'j_od', 'code': 'OD', 'name': 'Opérations Diverses', 'description': 'Journal des opérations diverses', 'type': 'DIVERS'},
    ];

    bool wasChanged = false;
    for (final defaultJournal in defaults) {
      if (!existingCodes.contains(defaultJournal['code'])) {
        await db.insertJournal(defaultJournal);
        wasChanged = true;
      }
    }

    if (wasChanged) {
      // reload all journaux if we added new ones
      _journaux.clear();
      _journaux.addAll(await db.getJournaux());
    } else {
      _journaux.clear();
      _journaux.addAll(existingJournaux);
    }

    // load plan comptable
    final plan = await db.getPlanComptable();
    // If there exists an INST account that is unused (no children, no entries), remove it automatically
    try {
      final hasInst = plan.any((r) => (r['code'] ?? r['id'] ?? '').toString() == 'INST' || (r['id'] ?? '').toString() == 'INST');
      if (hasInst) {
        final instHasChildren = await db.hasChildAccounts('INST');
        final instEntries = await db.countEcrituresForAccountCode('INST');
        if (!instHasChildren && instEntries == 0) {
          print('[DEBUG] Removing unused INST account automatically');
          await db.deleteCompte('INST');
          // refresh plan variable after deletion
          // Note: we intentionally do not alert user here to keep it silent; UI will refresh below.
        }
      }
    } catch (_) {}
    if (plan.isNotEmpty) {
      _accounts.clear();
      for (final r in plan) {
  final account = CompteComptable.fromMap(r);
  final pType = account.parentId == null ? 'null' : account.parentId.runtimeType.toString();
  print('[DEBUG] Loaded account: id=${account.id}, code=${account.code}, parentId=${account.parentId ?? 'null'}, type=$pType');
        _accounts.add(account);
      }
    } else {
      // seed sample plan if DB empty
      _accounts.addAll([
        CompteComptable(id: 'c1', code: '1', title: 'Classe 1 - Capitaux propres'),
        CompteComptable(id: '101', code: '101', title: 'Capital social', parentId: 'c1'),
        CompteComptable(id: '110', code: '110', title: 'Réserves', parentId: 'c1'),
        CompteComptable(id: 'c2', code: '2', title: 'Classe 2 - Immobilisations'),
        CompteComptable(id: '201', code: '201', title: 'Immobilisations incorporelles', parentId: 'c2'),
        CompteComptable(id: '211', code: '211', title: 'Immobilisations corporelles', parentId: 'c2'),
      ]);
      // persist seed
      for (final a in _accounts) {
        await db.insertCompte({'id': a.id, 'code': a.code, 'title': a.title, 'parentId': a.parentId});
      }
    }

    // load existing ecritures into UI list
    final rows = await db.getEcritures();
    if (rows.isNotEmpty) {
      _journalEntries.clear();
      for (final r in rows) {
        _journalEntries.add(EcritureComptable.fromMap(r));
      }
    }
    if(!mounted) return;
    setState(() {});
  }

  List<EcritureComptable> get _filteredJournalEntries {
    return _journalEntries.where((e) {
      if (_startDate != null && e.date.isBefore(_startDate!)) return false;
      if (_endDate != null && e.date.isAfter(_endDate!)) return false;
      if (_selectedJournal != 'Tous' && e.journalId != _selectedJournal) return false;
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty && !(e.label.toLowerCase().contains(q) || e.accountCode.toLowerCase().contains(q))) return false;
      return true;
    }).toList();
  }

  Widget _buildAccountsTree() {
    // Show as roots both true roots (parentId == null) and orphans
    // (parentId != null but parent not present in the loaded accounts). This
    // ensures every account appears somewhere in the tree view.
    final roots = _accounts.where((a) {
      if (a.parentId == null) return true;
      final parentExists = _accounts.any((p) => p.id == a.parentId);
      return !parentExists;
    }).toList();
    return ListView(
      children: roots.map((r) => _AccountNode(model: r, children: _accounts.where((a) => a.parentId == r.id).toList(), onSelect: (m) => setState(() => _selectedAccountId = m.id))).toList(),
    );
  }

  // Collect all descendant account ids for given account id (used to prevent cycles)
  Set<String> _collectDescendantIds(String id) {
    final result = <String>{};
    final stack = <String>[id];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      final children = _accounts.where((a) => a.parentId == cur).map((a) => a.id).toList();
      for (final c in children) {
        if (result.add(c)) stack.add(c);
      }
    }
    return result;
  }

  Widget _buildAccountDetailPanel() {
    final selected = _accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => _accounts.isNotEmpty ? _accounts.first : CompteComptable(id: '', code: '', title: ''));
    if (selected.id.isEmpty) {
      return Center(child: Text('Sélectionnez un compte pour voir les détails', style: TextStyle(color: Colors.white70)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compte : ${selected.code} ${selected.title}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Parent : ${selected.parentId ?? 'Aucun'}', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(onPressed: () => _editAccount(selected), child: Text('Modifier')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => _deleteAccount(selected), child: Text('Supprimer')),
          ],
        ),
      ],
    );
  }

  void _showInfo(String title, String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'))]));
  }

  void _exportJournalCSV() {
    // For skeleton: show a simple info dialog
    _showInfo('Export CSV', 'Export du journal (placeholder).');
  }

  // ----- EXPORT HELPERS -----
  Map<String, dynamic> _computeTrialBalance() {
    final map = <String, Map<String, double>>{}; // code -> {debit, credit}
    for (final e in _filteredJournalEntries) {
      final m = map.putIfAbsent(e.accountCode, () => {'debit': 0.0, 'credit': 0.0});
      m['debit'] = (m['debit'] ?? 0) + e.debit;
      m['credit'] = (m['credit'] ?? 0) + e.credit;
    }
    final rows = map.entries.map((kv) {
      final code = kv.key;
      final d = kv.value['debit'] ?? 0.0;
      final c = kv.value['credit'] ?? 0.0;
      final title = _accounts.firstWhere((a) => a.code == code, orElse: () => CompteComptable(id: '', code: code, title: '')).title;
      return {'code': code, 'title': title, 'debit': d, 'credit': c, 'balance': d - c};
    }).toList()
      ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
    return {'rows': rows};
  }

  Map<String, dynamic> _computeBilanEtCR() {
    final tb = _computeTrialBalance()['rows'] as List<Map<String, dynamic>>;
    double actifs = 0, passifs = 0;
    double produits = 0, charges = 0;
    for (final r in tb) {
      final code = r['code'] as String;
      final bal = (r['balance'] as num).toDouble();
      if (code.startsWith('2') || code.startsWith('3')) {
        actifs += bal; // classe 2/3 sont des actifs (débit positif souhaité)
      } else if (code.startsWith('4') || code.startsWith('5')) {
        if (bal >= 0) actifs += bal; else passifs += -bal;
      } else if (code.startsWith('1')) {
        passifs += -bal; // classe 1 (capitaux): généralement créditeur
      } else if (code.startsWith('6')) {
        charges += ((r['debit'] as num) - (r['credit'] as num)).toDouble();
      } else if (code.startsWith('7')) {
        produits += ((r['credit'] as num) - (r['debit'] as num)).toDouble();
      }
    }
    final resultat = produits - charges;
    // Ajuster bilan avec résultat si besoin
    if (resultat >= 0) passifs += resultat; else actifs += -resultat;
    return {
      'actifs': actifs,
      'passifs': passifs,
      'produits': produits,
      'charges': charges,
      'resultat': resultat,
      'tb': tb,
    };
  }

  Future<void> _exportBilan(String format) async {
    final data = _computeBilanEtCR();
    if (format == 'CSV') {
      final sb = StringBuffer();
      sb.writeln('Bilan');
      sb.writeln('Actifs,${_currencyFormat.format(data['actifs'])}');
      sb.writeln('Passifs,${_currencyFormat.format(data['passifs'])}');
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Bilan (CSV)', fileName: 'bilan.csv', type: FileType.custom, allowedExtensions: ['csv']);
      if (path == null) return;
      await File(path).writeAsString(sb.toString());
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Bilan exporté (CSV).'));
    } else if (format == 'Excel') {
      final ex = excel_lib.Excel.createExcel();
      final s = ex[ex.getDefaultSheet()!];
      s.appendRow([excel_lib.TextCellValue('Bilan')]);
      s.appendRow([excel_lib.TextCellValue('Actifs'), excel_lib.TextCellValue(_currencyFormat.format(data['actifs']))]);
      s.appendRow([excel_lib.TextCellValue('Passifs'), excel_lib.TextCellValue(_currencyFormat.format(data['passifs']))]);
      final bytes = ex.encode();
      if (bytes == null) return;
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Bilan (Excel)', fileName: 'bilan.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
      if (path == null) return;
      await File(path).writeAsBytes(Uint8List.fromList(bytes));
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Bilan exporté (Excel).'));
    }
  }

  Future<void> _exportCompteResultat(String format) async {
    final data = _computeBilanEtCR();
    final produits = (data['produits'] as num).toDouble();
    final charges = (data['charges'] as num).toDouble();
    final resultat = (data['resultat'] as num).toDouble();
    if (format == 'CSV') {
      final sb = StringBuffer();
      sb.writeln('Compte de Résultat');
      sb.writeln('Produits,${_currencyFormat.format(produits)}');
      sb.writeln('Charges,${_currencyFormat.format(charges)}');
      sb.writeln('Résultat,${_currencyFormat.format(resultat)}');
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Compte de résultat (CSV)', fileName: 'compte_resultat.csv', type: FileType.custom, allowedExtensions: ['csv']);
      if (path == null) return;
      await File(path).writeAsString(sb.toString());
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Compte de résultat exporté (CSV).'));
    } else if (format == 'Excel') {
      final ex = excel_lib.Excel.createExcel();
      final s = ex[ex.getDefaultSheet()!];
      s.appendRow([excel_lib.TextCellValue('Compte de Résultat')]);
      s.appendRow([excel_lib.TextCellValue('Produits'), excel_lib.TextCellValue(_currencyFormat.format(produits))]);
      s.appendRow([excel_lib.TextCellValue('Charges'), excel_lib.TextCellValue(_currencyFormat.format(charges))]);
      s.appendRow([excel_lib.TextCellValue('Résultat'), excel_lib.TextCellValue(_currencyFormat.format(resultat))]);
      final bytes = ex.encode();
      if (bytes == null) return;
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Compte de résultat (Excel)', fileName: 'compte_resultat.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
      if (path == null) return;
      await File(path).writeAsBytes(Uint8List.fromList(bytes));
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Compte de résultat exporté (Excel).'));
    }
  }

  Future<void> _exportCompteResultatPdf() async {
    final data = _computeBilanEtCR();
    final produits = (data['produits'] as num).toDouble();
    final charges = (data['charges'] as num).toDouble();
    final resultat = (data['resultat'] as num).toDouble();
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Compte de Résultat', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Ligne', 'Montant'],
          data: [
            ['Produits', _currencyFormat.format(produits)],
            ['Charges', _currencyFormat.format(charges)],
            ['Résultat', _currencyFormat.format(resultat)],
          ],
          border: pw.TableBorder.all(color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    final bytes = await pdf.save();
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Compte de résultat (PDF)', fileName: 'compte_resultat.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
    if (path == null) return; await File(path).writeAsBytes(bytes);
    NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Compte de résultat exporté (PDF).'));
  }

  // PDF exports for the three rapports implémentés ici: Balance, Grand Livre, Trésorerie
  Future<void> _exportBalancePdf() async {
    final tb = _computeTrialBalance()['rows'] as List<Map<String, dynamic>>;
    if (tb.isEmpty) { _showInfo('Balance', 'Aucune donnée.'); return; }
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Balance générale', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Code', 'Intitulé', 'Débit', 'Crédit', 'Solde'],
          data: tb.map((r) => [r['code'], r['title'] ?? '', _currencyFormat.format(r['debit']), _currencyFormat.format(r['credit']), _currencyFormat.format(r['balance'])]).toList(),
          border: pw.TableBorder.all(color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    final bytes = await pdf.save();
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Balance (PDF)', fileName: 'balance.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
    if (path == null) return; await File(path).writeAsBytes(bytes);
    NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Balance exportée (PDF).'));
  }

  Future<void> _exportGrandLivrePdf() async {
    final entries = _filteredJournalEntries..sort((a, b) => a.date.compareTo(b.date));
    if (entries.isEmpty) { _showInfo('Grand Livre', 'Aucune donnée.'); return; }
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Grand Livre', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Compte', 'Intitulé', 'Date', 'Journal', 'Pièce', 'Libellé', 'Débit', 'Crédit'],
          data: entries.map((e) {
            final acc = _accounts.firstWhere((a) => a.code == e.accountCode, orElse: () => CompteComptable(id: '', code: e.accountCode, title: ''));
            return [e.accountCode, acc.title, _dateFormat.format(e.date), e.journalId, e.pieceNumber, e.label, _currencyFormat.format(e.debit), _currencyFormat.format(e.credit)];
          }).toList(),
          border: pw.TableBorder.all(color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    final bytes = await pdf.save();
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Grand livre (PDF)', fileName: 'grand_livre.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
    if (path == null) return; await File(path).writeAsBytes(bytes);
    NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Grand livre exporté (PDF).'));
  }

  Future<void> _exportTresoreriePdf() async {
    final entries = _filteredJournalEntries.where((e) => e.accountCode.startsWith('5') || e.journalId.toUpperCase().contains('BQ') || e.journalId.toUpperCase().contains('CA')).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (entries.isEmpty) { _showInfo('Trésorerie', 'Aucune donnée.'); return; }
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Journal de Trésorerie', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Date', 'Journal', 'Pièce', 'Libellé', 'Débit', 'Crédit'],
          data: entries.map((e) => [_dateFormat.format(e.date), e.journalId, e.pieceNumber, e.label, _currencyFormat.format(e.debit), _currencyFormat.format(e.credit)]).toList(),
          border: pw.TableBorder.all(color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    final bytes = await pdf.save();
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Trésorerie (PDF)', fileName: 'tresorerie.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
    if (path == null) return; await File(path).writeAsBytes(bytes);
    NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Trésorerie exportée (PDF).'));
  }

  Future<void> _exportBalance(String format) async {
    // Group filtered entries by account and compute totals
    final entries = _filteredJournalEntries;
    if (entries.isEmpty) {
      _showInfo('Balance', 'Aucune écriture dans la période/filtre.');
      return;
    }
    final map = <String, Map<String, num>>{}; // code -> {debit, credit}
    for (final e in entries) {
      final m = map.putIfAbsent(e.accountCode, () => {'debit': 0, 'credit': 0});
      m['debit'] = (m['debit'] ?? 0) + e.debit;
      m['credit'] = (m['credit'] ?? 0) + e.credit;
    }
    final rows = map.entries.map((kv) {
      final code = kv.key;
      final title = _accounts.firstWhere((a) => a.code == code, orElse: () => CompteComptable(id: '', code: code, title: '')).title;
      final d = (kv.value['debit'] ?? 0).toDouble();
      final c = (kv.value['credit'] ?? 0).toDouble();
      final solde = d - c;
      return {'code': code, 'title': title, 'debit': d, 'credit': c, 'balance': solde};
    }).toList()
      ..sort((a, b) => (a['code'] as String).compareTo((b['code'] as String)));

    if (format == 'CSV') {
      final sb = StringBuffer();
      sb.writeln('Code,Intitulé,Débit,Crédit,Solde');
      for (final r in rows) {
        sb.writeln("${r['code']},${r['title']},${_currencyFormat.format(r['debit'])},${_currencyFormat.format(r['credit'])},${_currencyFormat.format(r['balance'])}");
      }
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Balance (CSV)', fileName: 'balance.csv', type: FileType.custom, allowedExtensions: ['csv']);
      if (path == null) return;
      await File(path).writeAsString(sb.toString());
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Balance exportée (CSV).'));
    } else if (format == 'Excel') {
      final ex = excel_lib.Excel.createExcel();
      final sheet = ex[ex.getDefaultSheet()!];
      sheet.appendRow([
        excel_lib.TextCellValue('Code'),
        excel_lib.TextCellValue('Intitulé'),
        excel_lib.TextCellValue('Débit'),
        excel_lib.TextCellValue('Crédit'),
        excel_lib.TextCellValue('Solde'),
      ]);
      for (final r in rows) {
        sheet.appendRow([
          excel_lib.TextCellValue(r['code'] as String),
          excel_lib.TextCellValue((r['title'] as String?) ?? ''),
          excel_lib.TextCellValue(_currencyFormat.format(r['debit'])),
          excel_lib.TextCellValue(_currencyFormat.format(r['credit'])),
          excel_lib.TextCellValue(_currencyFormat.format(r['balance'])),
        ]);
      }
      final bytes = ex.encode();
      if (bytes == null) return;
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Balance (Excel)', fileName: 'balance.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
      if (path == null) return;
      await File(path).writeAsBytes(Uint8List.fromList(bytes));
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Balance exportée (Excel).'));
    }
  }

  Future<void> _exportGrandLivre(String format) async {
    // Ledger per account: ordered by date
    final entries = _filteredJournalEntries..sort((a, b) => a.date.compareTo(b.date));
    if (entries.isEmpty) { _showInfo('Grand Livre', 'Aucune écriture.'); return; }

    if (format == 'CSV') {
      final sb = StringBuffer();
      sb.writeln('Compte,Intitulé,Date,Journal,Pièce,Libellé,Débit,Crédit');
      for (final e in entries) {
        final acc = _accounts.firstWhere((a) => a.code == e.accountCode, orElse: () => CompteComptable(id: '', code: e.accountCode, title: ''));
        sb.writeln("${e.accountCode},${acc.title},${_dateFormat.format(e.date)},${e.journalId},${e.pieceNumber},${e.label},${_currencyFormat.format(e.debit)},${_currencyFormat.format(e.credit)}");
      }
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Grand Livre (CSV)', fileName: 'grand_livre.csv', type: FileType.custom, allowedExtensions: ['csv']);
      if (path == null) return;
      await File(path).writeAsString(sb.toString());
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Grand livre exporté (CSV).'));
    } else if (format == 'Excel') {
      final ex = excel_lib.Excel.createExcel();
      // One sheet per main account prefix (or single sheet)
      final sheet = ex[ex.getDefaultSheet()!];
      sheet.appendRow([
        excel_lib.TextCellValue('Compte'),
        excel_lib.TextCellValue('Intitulé'),
        excel_lib.TextCellValue('Date'),
        excel_lib.TextCellValue('Journal'),
        excel_lib.TextCellValue('Pièce'),
        excel_lib.TextCellValue('Libellé'),
        excel_lib.TextCellValue('Débit'),
        excel_lib.TextCellValue('Crédit'),
      ]);
      for (final e in entries) {
        final acc = _accounts.firstWhere((a) => a.code == e.accountCode, orElse: () => CompteComptable(id: '', code: e.accountCode, title: ''));
        sheet.appendRow([
          excel_lib.TextCellValue(e.accountCode),
          excel_lib.TextCellValue(acc.title),
          excel_lib.TextCellValue(_dateFormat.format(e.date)),
          excel_lib.TextCellValue(e.journalId),
          excel_lib.TextCellValue(e.pieceNumber),
          excel_lib.TextCellValue(e.label),
          excel_lib.TextCellValue(_currencyFormat.format(e.debit)),
          excel_lib.TextCellValue(_currencyFormat.format(e.credit)),
        ]);
      }
      final bytes = ex.encode();
      if (bytes == null) return;
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Grand Livre (Excel)', fileName: 'grand_livre.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
      if (path == null) return;
      await File(path).writeAsBytes(Uint8List.fromList(bytes));
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Grand livre exporté (Excel).'));
    }
  }

  Future<void> _exportTresorerie(String format) async {
    // Treasury: filter entries likely belonging to bank/cash or class 5
    final entries = _filteredJournalEntries.where((e) {
      final code = e.accountCode;
      final isCash = code.startsWith('5');
      final isBQ = e.journalId.toUpperCase().contains('BQ') || e.journalId.toUpperCase().contains('CA');
      return isCash || isBQ;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (entries.isEmpty) { _showInfo('Trésorerie', 'Aucune écriture de trésorerie.'); return; }

    if (format == 'CSV') {
      final sb = StringBuffer();
      sb.writeln('Date,Journal,Pièce,Libellé,Débit,Crédit');
      for (final e in entries) {
        sb.writeln("${_dateFormat.format(e.date)},${e.journalId},${e.pieceNumber},${e.label},${_currencyFormat.format(e.debit)},${_currencyFormat.format(e.credit)}");
      }
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Trésorerie (CSV)', fileName: 'tresorerie.csv', type: FileType.custom, allowedExtensions: ['csv']);
      if (path == null) return;
      await File(path).writeAsString(sb.toString());
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Trésorerie exportée (CSV).'));
    } else if (format == 'Excel') {
      final ex = excel_lib.Excel.createExcel();
      final sheet = ex[ex.getDefaultSheet()!];
      sheet.appendRow([
        excel_lib.TextCellValue('Date'),
        excel_lib.TextCellValue('Journal'),
        excel_lib.TextCellValue('Pièce'),
        excel_lib.TextCellValue('Libellé'),
        excel_lib.TextCellValue('Débit'),
        excel_lib.TextCellValue('Crédit'),
      ]);
      for (final e in entries) {
        sheet.appendRow([
          excel_lib.TextCellValue(_dateFormat.format(e.date)),
          excel_lib.TextCellValue(e.journalId),
          excel_lib.TextCellValue(e.pieceNumber),
          excel_lib.TextCellValue(e.label),
          excel_lib.TextCellValue(_currencyFormat.format(e.debit)),
          excel_lib.TextCellValue(_currencyFormat.format(e.credit)),
        ]);
      }
      final bytes = ex.encode();
      if (bytes == null) return;
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Exporter Trésorerie (Excel)', fileName: 'tresorerie.xlsx', type: FileType.custom, allowedExtensions: ['xlsx']);
      if (path == null) return;
      await File(path).writeAsBytes(Uint8List.fromList(bytes));
      NotificationService().showNotification(NotificationItem(id: DateTime.now().toString(), message: 'Trésorerie exportée (Excel).'));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _endDate = picked);
  }

  void _editAccount(CompteComptable account) {
    final codeController = TextEditingController(text: account.code);
    final titleController = TextEditingController(text: account.title);
    String? parentId = account.parentId;

    print('[DEBUG] _editAccount - Initial parentId: $parentId, type: ${parentId.runtimeType}'); // Add this line

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Modifier compte'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: codeController, decoration: InputDecoration(labelText: 'Code')),
        const SizedBox(height: 8),
        TextField(controller: titleController, decoration: InputDecoration(labelText: 'Intitulé')),
        const SizedBox(height: 8),
        Builder(builder: (ctx2) {
          // Precompute available parents and ensure the Dropdown's value matches one of the items.
          final availableParents = <String?>[null];
          final excluded = _collectDescendantIds(account.id)..add(account.id);
          availableParents.addAll(_accounts.where((a) => !excluded.contains(a.id)).map((a) => a.id));
          print('[DEBUG] Dropdown items available: $availableParents');
          final safeValue = availableParents.contains(parentId) ? parentId : null;
          return DropdownButtonFormField<String?>(
            value: safeValue,
            items: availableParents.map<DropdownMenuItem<String?>>((v) => DropdownMenuItem<String?>(value: v, child: Text(v == null ? 'Aucun (racine)' : _accounts.firstWhere((x) => x.id == v).title))).toList(),
            onChanged: (v) => parentId = v,
            decoration: InputDecoration(labelText: 'Parent'),
          );
        }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler')),
        ElevatedButton(onPressed: () async {
          final newCode = codeController.text.trim();
          final newTitle = titleController.text.trim();
          if (newTitle.isEmpty) { _showInfo('Erreur', 'Intitulé requis'); return; }

          // optimistic update
          final previous = _accounts.toList();
          setState(() {
            final idx = _accounts.indexWhere((a) => a.id == account.id);
            if (idx != -1) {
              _accounts[idx] = CompteComptable(id: account.id, code: newCode, title: newTitle, parentId: parentId, isArchived: account.isArchived);
            }
          });

          try {
            await DatabaseService().insertCompte({'id': account.id, 'code': newCode, 'title': newTitle, 'parentId': parentId});
            Navigator.pop(ctx);
            NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Compte modifié'));
          } catch (err) {
            // rollback optimistic change
            setState(() => _accounts
              ..clear()
              ..addAll(previous));
            Navigator.pop(ctx);
            NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Erreur lors de la sauvegarde', backgroundColor: Colors.redAccent));
          }
        }, child: Text('Enregistrer'))
      ],
    ));
  }

  void _deleteAccount(CompteComptable account) async {
    // check children and ecritures
    final hasChildren = await DatabaseService().hasChildAccounts(account.id);
    final ecrituresCount = await DatabaseService().countEcrituresForAccountCode(account.code);

    if (!hasChildren && ecrituresCount == 0) {
      // simple delete with undo
      showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Supprimer'), content: Text('Supprimer ${account.title} ?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler')), ElevatedButton(onPressed: () async {
        Navigator.pop(ctx);
        // snapshot the account row for undo
        final db = DatabaseService();
        final acctRow = await db.getCompteById(account.id);
        // optimistic UI update
        setState(() => _accounts.removeWhere((a) => a.id == account.id));
        try {
          await db.deleteCompte(account.id);
          // show notification with Undo
          final notifId = DateTime.now().millisecondsSinceEpoch.toString();
          NotificationService().showNotification(NotificationItem(
            id: notifId,
            message: 'Compte supprimé',
            actionLabel: 'Annuler',
            onAction: () async {
              if (acctRow != null) {
                await db.insertCompte(acctRow);
                await _loadComptaData();
                NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Suppression annulée'));
              }
            },
          ));
        } catch (err) {
          // rollback optimistic change
          final rows = await db.getPlanComptable();
          final restored = rows.map((r) => CompteComptable.fromMap(r)).toList();
          setState(() {
            _accounts.clear();
            _accounts.addAll(restored);
          });
          NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Erreur suppression — opération annulée', backgroundColor: Colors.redAccent));
        }
      }, child: Text('Supprimer'))]));
      return;
    }

    // show cascade prompt when children or linked entries exist
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Supprimer avec conséquences'),
      content: Text('Ce compte a ${hasChildren ? 'des sous-comptes' : ''}${hasChildren && ecrituresCount > 0 ? ' et ' : ''}${ecrituresCount > 0 ? '$ecrituresCount écritures' : ''}. Voulez-vous supprimer en cascade ? Les écritures auront leur compte effacé.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          // snapshot accounts and affected ecritures for undo
          final db = DatabaseService();
          final previous = _accounts.toList();
          // collect ids/codes to snapshot
          final toDeleteIds = <String>{};
          final stack = <String>[account.id];
          while (stack.isNotEmpty) {
            final cur = stack.removeLast();
            if (toDeleteIds.contains(cur)) continue;
            toDeleteIds.add(cur);
            final children = _accounts.where((a) => a.parentId == cur).map((a) => a.id).toList();
            stack.addAll(children);
          }
          // fetch account rows
          final acctRows = <Map<String, Object?>>[];
          final codes = <String>[];
          for (final idd in toDeleteIds) {
            final r = await db.getCompteById(idd);
            if (r != null) {
              acctRows.add(r);
              final code = r['code'] as String?;
              if (code != null && code.isNotEmpty) codes.add(code);
            }
          }
          // fetch affected ecritures
          final ecritures = await db.getEcrituresByAccountCodes(codes);

          // optimistic UI removal
          setState(() => _accounts.removeWhere((a) => toDeleteIds.contains(a.id)));
          try {
            await db.deleteCompteCascade(account.id);
            final notifId = DateTime.now().millisecondsSinceEpoch.toString();
            NotificationService().showNotification(NotificationItem(
              id: notifId,
              message: 'Compte et descendants supprimés',
              actionLabel: 'Annuler',
              onAction: () async {
                // restore accounts
                for (final r in acctRows) {
                  await db.insertCompte(r);
                }
                // restore ecritures' accountCode
                for (final e in ecritures) {
                  final id = e['id'] as String;
                  final accCode = e['accountCode'] as String?;
                  await db.updateEcriture(id, {'accountCode': accCode});
                }
                await _loadComptaData();
                NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Suppression annulée'));
              },
            ));
            await _loadComptaData();
          } catch (err) {
            // rollback
            setState(() {
              _accounts.clear();
              _accounts.addAll(previous);
            });
            NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Erreur suppression — opération annulée', backgroundColor: Colors.redAccent));
          }
        }, child: Text('Supprimer en cascade')),
      ],
    ));
  }

  Widget _reportCard(String title, String subtitle, IconData icon, VoidCallback onTap, [Color? iconColor]) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF061220),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? Colors.white70, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Align(alignment: Alignment.bottomRight, child: Text('Générer', style: TextStyle(color: Colors.white.withOpacity(0.8))))
          ],
        ),
      ),
    );
  }

  void _generateReport(String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Générer $name'), content: Text('Génération du rapport "$name" (placeholder)'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Fermer'))]));
  }

  void _showNewJournalEntryDialog() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, right: 8, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saisie d\'écriture comptable', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SaisieEcritureScreen(
                    accounts: _accounts,
                    journaux: _journaux,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((result) {
      if (result == true) {
        _loadComptaData();
      }
    });
  }

  Widget _buildJournalTable(List<EcritureComptable> entries, Map<String, String> journalIdToName) {
    if (entries.isEmpty) {
      return const Center(child: Text('Aucune écriture à afficher.'));
    }

    // Group entries by pieceId
    final Map<String, List<EcritureComptable>> groupedByPiece = {};
    for (final entry in entries) {
      groupedByPiece.putIfAbsent(entry.pieceId, () => []).add(entry);
    }

    // Sort groups by date (using the date of the first entry in each group)
    final sortedGroupKeys = groupedByPiece.keys.toList()
      ..sort((a, b) {
        final dateA = groupedByPiece[a]!.first.date;
        final dateB = groupedByPiece[b]!.first.date;
        return dateB.compareTo(dateA); // Sort descending, newest first
      });

    return ListView.builder(
      itemCount: sortedGroupKeys.length,
      itemBuilder: (context, index) {
        final pieceId = sortedGroupKeys[index];
        final groupEntries = groupedByPiece[pieceId]!;
        final firstEntry = groupEntries.first;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          color: const Color(0xFF1E293B), // Slightly different color for the card
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.blueGrey.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Date: ${_dateFormat.format(firstEntry.date)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Journal: ${journalIdToName[firstEntry.journalId] ?? firstEntry.journalId}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Pièce: ${firstEntry.pieceNumber}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
                      tooltip: 'Modifier l\'écriture',
                      onPressed: () {
                        // TODO: Implement edit functionality for the entire transaction
                        _showInfo('Action', 'Modifier l\'écriture complète (Pièce: ${firstEntry.pieceNumber})');
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                // Lines Table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 32,
                    dataRowMinHeight: 30,
                    dataRowMaxHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Compte')),
                      DataColumn(label: Text('Libellé')),
                      DataColumn(label: Text('Débit', textAlign: TextAlign.right)),
                      DataColumn(label: Text('Crédit', textAlign: TextAlign.right)),
                      DataColumn(label: Text('Lettrage')),
                    ],
                    rows: groupEntries.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text(e.accountCode)),
                          DataCell(Text(e.label)),
                          DataCell(Text(e.debit > 0 ? _currencyFormat.format(e.debit) : '', textAlign: TextAlign.right)),
                          DataCell(Text(e.credit > 0 ? _currencyFormat.format(e.credit) : '', textAlign: TextAlign.right)),
                          DataCell(Text(e.lettrageId ?? '-')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Comptabilité',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                // Import/Export
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: implement import/export
                  },
                  icon: const Icon(Icons.import_export, color: Colors.orangeAccent),
                  label: const Text('Importer/Exporter', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    side: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                ),
                const SizedBox(width: 8),
                // (INST migration/remove buttons removed)
                const SizedBox(width: 8),
                // Nouveau compte button with gradient background
                InkWell(
                  onTap: () {
                    _showNewAccountDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: comptaGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Nouveau compte', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tabs
          TabBar(
            tabs: [
              Tab(text: 'Plan comptable', icon: Icon(Icons.account_tree_outlined)),
              Tab(text: 'Journal', icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: 'Rapports', icon: Icon(Icons.insert_chart_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                // Plan comptable (TreeView skeleton with toolbar)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    color: const Color(0xFF0B1220),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Plan comptable', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                              IconButton(
                                tooltip: 'Ajouter une classe/compte',
                                onPressed: () => _showNewAccountDialog(),
                                icon: const Icon(Icons.add, color: Colors.white),
                              ),
                              IconButton(
                                tooltip: 'Importer',
                                onPressed: () {
                                  _showInfo('Importer', 'Fonction d\'import à implémenter');
                                },
                                icon: const Icon(Icons.upload_file, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Row(
                              children: [
                                // Left: tree
                                Flexible(
                                  flex: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF061220),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _buildAccountsTree(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right: details / actions for selected account
                                Flexible(
                                  flex: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF061220),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _buildAccountDetailPanel(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Journal (DataTable skeleton with filters)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    color: const Color(0xFF0B1220),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Builder(
                        builder: (context) {
                          final journalIdToName = {for (var j in _journaux) j['id'] as String: j['name'] as String};
                          final filteredEntries = _filteredJournalEntries;
                          final totalDebit = filteredEntries.fold<double>(0, (sum, e) => sum + e.debit);
                          final totalCredit = filteredEntries.fold<double>(0, (sum, e) => sum + e.credit);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Text('Journal des écritures', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                                  ElevatedButton.icon(
                                    onPressed: _showNewJournalEntryDialog,
                                    icon: const Icon(Icons.add, color: Colors.white),
                                    label: const Text('Saisir écriture', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(backgroundColor: comptaGradient.colors.first),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Exporter CSV',
                                    onPressed: _exportJournalCSV,
                                    icon: const Icon(Icons.download, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Lettrer',
                                    onPressed: () => _openLettrageDialog(),
                                    icon: const Icon(Icons.link, color: Colors.lightGreenAccent),
                                  ),
                                  IconButton(
                                    tooltip: 'Annuler lettrage',
                                    onPressed: () => _openUnlettrageDialog(),
                                    icon: const Icon(Icons.link_off, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Filters
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton(
                                    onPressed: _pickStartDate,
                                    child: Text(_startDate == null ? 'Date début' : _dateFormat.format(_startDate!))),
                                  ElevatedButton(
                                    onPressed: _pickEndDate,
                                    child: Text(_endDate == null ? 'Date fin' : _dateFormat.format(_endDate!))),
                                  DropdownButton<String>(
                                    value: _selectedJournal,
                                    dropdownColor: const Color(0xFF0B1220),
                                    items: [
                                      const DropdownMenuItem(value: 'Tous', child: Text('Tous les journaux')),
                                      ..._journaux.map((j) => DropdownMenuItem(value: j['id'] as String, child: Text(j['name'] as String? ?? ''))),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedJournal = v);
                                      }
                                    },
                                  ),
                                  SizedBox(
                                    width: 240,
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(hintText: 'Rechercher...', border: OutlineInputBorder()),
                                      onChanged: (v) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _buildJournalTable(filteredEntries, journalIdToName),
                              ),
                              const SizedBox(height: 12),
                              // Totals Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('Total Débit: ${_currencyFormat.format(totalDebit)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 24),
                                  Text('Total Crédit: ${_currencyFormat.format(totalCredit)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 120), // to align with the end of the table
                                ],
                              )
                            ],
                          );
                        }
                      ),
                    ),
                  ),
                ),
                // Rapports
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    color: const Color(0xFF0B1220),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rapports disponibles', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                _reportCard('Balance générale', 'Balance générale sur la période sélectionnée', Icons.grid_view, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.9,
                                        height: MediaQuery.of(context).size.height * 0.9,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Balance Générale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            const Expanded(child: BalanceGeneraleScreen()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }, Colors.purpleAccent),
                                _reportCard('Grand livre', 'Détail par compte (Grand livre)', Icons.book, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.9,
                                        height: MediaQuery.of(context).size.height * 0.9,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Grand Livre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                  Row(children: [
                                                    TextButton.icon(onPressed: () => _exportGrandLivre('CSV'), icon: const Icon(Icons.insert_drive_file), label: const Text('CSV')),
                                                    const SizedBox(width: 8),
                                                    TextButton.icon(onPressed: () => _exportGrandLivre('Excel'), icon: const Icon(Icons.table_chart), label: const Text('Excel')),
                                                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            const Expanded(child: GrandLivreScreen()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }, Colors.tealAccent),
                                _reportCard('Bilan comptable', 'Bilan actif / passif', Icons.business_center, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.9,
                                        height: MediaQuery.of(context).size.height * 0.9,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Bilan Comptable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            const Expanded(child: BilanScreen()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }, Colors.blueAccent),
                                _reportCard('Compte de résultat', 'Résultat sur la période', Icons.show_chart, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.9,
                                        height: MediaQuery.of(context).size.height * 0.9,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Compte de Résultat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                  Row(children: [
                                                    TextButton.icon(onPressed: _exportCompteResultatPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
                                                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            const Expanded(child: CompteResultatScreen()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }, Colors.greenAccent),
                                _reportCard('Journal de trésorerie', 'Flux de trésorerie', Icons.account_balance_wallet, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.9,
                                        height: MediaQuery.of(context).size.height * 0.9,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Journal de Trésorerie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                  Row(children: [
                                                    TextButton.icon(onPressed: () => _exportTresorerie('CSV'), icon: const Icon(Icons.insert_drive_file), label: const Text('CSV')),
                                                    const SizedBox(width: 8),
                                                    TextButton.icon(onPressed: () => _exportTresorerie('Excel'), icon: const Icon(Icons.table_chart), label: const Text('Excel')),
                                                    const SizedBox(width: 8),
                                                    TextButton.icon(onPressed: _exportTresoreriePdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
                                                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            const Expanded(child: TresorerieScreen()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }, Colors.orangeAccent),
                                _reportCard('Déclarations fiscales', 'Télécharger les déclarations fiscales', Icons.description, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.9,
                                        height: MediaQuery.of(context).size.height * 0.9,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Déclarations Fiscales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            const Expanded(child: DeclarationsFiscalesScreen()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }, Colors.indigoAccent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (coming soon helper removed; UI uses full skeleton)

  void _showNewAccountDialog() {
    final codeController = TextEditingController();
    final titleController = TextEditingController();
    String? parentId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code')),
            const SizedBox(height: 8),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Intitulé')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: parentId,
              items: [null, ..._accounts.map((a) => a.id)].map((v) => DropdownMenuItem(value: v, child: Text(v == null ? 'Aucun (racine)' : _accounts.firstWhere((x) => x.id == v).title))).toList(),
              onChanged: (v) => parentId = v,
              decoration: const InputDecoration(labelText: 'Parent'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final newId = DateTime.now().millisecondsSinceEpoch.toString();
                final acc = CompteComptable(id: newId, code: code, title: title, parentId: parentId);
                setState(() {
                  _accounts.add(acc);
                });
                // persist
                try {
                  await DatabaseService().insertCompte({'id': newId, 'code': code, 'title': title, 'parentId': parentId});
                  Navigator.pop(ctx);
                } catch (err) {
                  // rollback
                  setState(() => _accounts.removeWhere((a) => a.id == newId));
                  Navigator.pop(ctx);
                  NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Erreur création compte', backgroundColor: Colors.redAccent));
                }
              },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _openLettrageDialog() {
    // Simple lettrage: select multiple entries and group them under a lettrage id
    final selected = <String>{};
    showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx2, setState2) {
        return AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Lettrer des écritures')),
              IconButton(onPressed: () => Navigator.pop(ctx2), icon: Icon(Icons.close)),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              children: [
                Expanded(child: ListView(
                  children: _journalEntries.map((e) {
                    final checked = selected.contains(e.id);
                    return CheckboxListTile(
                      value: checked,
                      title: Text('${_dateFormat.format(e.date)} - ${e.pieceNumber.isNotEmpty ? e.pieceNumber + ' - ' : ''}${e.accountCode} - ${e.label}'),
                      subtitle: Text('ID: ${e.id} · D:${e.debit.toStringAsFixed(0)} C:${e.credit.toStringAsFixed(0)}'),
                      onChanged: (v) => setState2(() => v == true ? selected.add(e.id) : selected.remove(e.id)),
                    );
                  }).toList(),
                )),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: TextField(decoration: InputDecoration(labelText: 'Libellé du lettrage'))), const SizedBox(width: 8), ElevatedButton(onPressed: () async {
                  if (selected.isEmpty) { _showInfo('Erreur', 'Aucune écriture sélectionnée'); return; }
                  final lettrageId = DateTime.now().microsecondsSinceEpoch.toString();
                  // persist lettrage record
                  await DatabaseService().insertLettrage({'id': lettrageId, 'label': 'Lettrage ${DateTime.now()}', 'createdAt': DateTime.now().millisecondsSinceEpoch});
                  // assign selected ecritures to this lettrage
                  final matched = selected.toList();
                    if (matched.isNotEmpty) {
                    await DatabaseService().assignLettrageToEcritures(lettrageId, matched);
                    // reload entries so UI shows the lettrage immediately
                    await _loadComptaData();
                    Navigator.pop(ctx2);
                    NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Lettrage appliqué à ${matched.length} écritures'));
                  } else {
                    _showInfo('Lettrage', 'Aucune écriture sélectionnée');
                  }
                }, child: Text('Appliquer'))])
              ],
            ),
          ),
        );
      });
    });
  }

  void _openUnlettrageDialog() {
    showDialog(context: context, builder: (ctx) {
      return FutureBuilder<List<Map<String, Object?>>>(
        future: DatabaseService().getLettrages(),
        builder: (context, snap) {
          if (!snap.hasData) return AlertDialog(content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
          final lets = snap.data!;
          if (lets.isEmpty) return AlertDialog(title: Text('Annuler lettrage'), content: Text('Aucun lettrage trouvé'));
          return AlertDialog(
            title: Row(children: [Expanded(child: Text('Annuler lettrage')), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close))]),
            content: SizedBox(
              width: 500,
              height: 300,
              child: ListView(
                children: lets.map((l) {
                  return ListTile(
                    title: Text(l['label'] as String? ?? 'Lettrage'),
                    subtitle: Text('ID: ${l['id']} · ${DateTime.fromMillisecondsSinceEpoch(l['createdAt'] as int? ?? 0)}'),
                    trailing: ElevatedButton(onPressed: () async {
                      final id = l['id'] as String;
                      await DatabaseService().removeLettrageFromEcritures(id);
                      // reload entries so UI updates immediately
                      await _loadComptaData();
                      Navigator.pop(ctx);
                      NotificationService().showNotification(NotificationItem(id: DateTime.now().millisecondsSinceEpoch.toString(), message: 'Lettrage annulé'));
                    }, child: Text('Annuler')),
                  );
                }).toList(),
              ),
            ),
          );
        },
      );
    });
  }
}

class _AccountNode extends StatefulWidget {
  final CompteComptable model;
  final List<CompteComptable> children;
  final void Function(CompteComptable)? onSelect;
  const _AccountNode({required this.model, this.children = const [], this.onSelect, Key? key}) : super(key: key);

  @override
  _AccountNodeState createState() => _AccountNodeState();
}

class _AccountNodeState extends State<_AccountNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.children.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: hasChildren ? Icon(_expanded ? Icons.expand_more : Icons.chevron_right, color: widget.model.code.length > 2 ? Colors.tealAccent : Colors.white70) : const SizedBox(width: 24),
          title: Text('${widget.model.code.isNotEmpty ? widget.model.code + ' - ' : ''}${widget.model.title}', style: TextStyle(color: Colors.white.withOpacity(0.9))),
          onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
          onLongPress: () {
            widget.onSelect?.call(widget.model);
          },
        ),
        if (_expanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(children: widget.children.map((c) => _AccountNode(model: c, children: _buildChildren(c.id), onSelect: widget.onSelect)).toList()),
          ),
      ],
    );
  }

  List<CompteComptable> _buildChildren(String parentId) {
    final state = context.findAncestorStateOfType<_ComptabiliteScreenState>();
    if (state == null) return [];
    return state._accounts.where((a) => a.parentId == parentId).toList();
  }
}
// in-file temporary models removed — using typed models in lib/models/

// --- State fields and helpers (attached to the state via extension-like placement) ---

// Paramètres screen removed; navigation icon was deleted per request.
