import 'dart:io';

import 'package:afroforma/models/student.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';

import '../screen/parametres/models.dart';
import '../utils/template_canvas_pdf.dart';

import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/formation.dart';
import '../services/database_service.dart';

class FacturationScreen extends StatefulWidget {
  final Animation<double> fadeAnimation;
  const FacturationScreen({Key? key, required this.fadeAnimation}) : super(key: key);

  @override
  State<FacturationScreen> createState() => _FacturationScreenState();
}

class _FacturationScreenState extends State<FacturationScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Invoice> _invoices = [];
  List<Payment> _payments = [];
  // generic invoices will be mapped into _invoices for unified handling
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');
  bool _loading = true;
  bool _applyAdvances = false; // whether to apply isCredit amounts against invoice (default: ignore advances)

  String _searchQuery = '';
  InvoiceStatus? _selectedStatus;
  final _quickPaymentAmountController = TextEditingController(); // This will be "Montant dû"
  final _quickPaymentNoteController = TextEditingController();
  final _amountGivenController = TextEditingController(); // New controller for amount given by customer
  double _changeAmount = 0.0; // New state variable for calculated change
  PaymentMethod _quickPaymentMethod = PaymentMethod.cash;

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Facturation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showNewInvoiceDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle facture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white, // Ensure text is white for contrast
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _exportInvoices,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exporter PDF'),
              ),
              const SizedBox(width: 12),
              Row(children: [
                const Text('Appliquer avances', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 6),
                Switch(
                  value: _applyAdvances,
                  onChanged: (v) async {
                    setState(() { _applyAdvances = v; });
                    try {
                      final sp = await SharedPreferences.getInstance();
                      await sp.setBool('facturation.applyAdvances', v);
                    } catch (_) {}
                    await _loadInscriptionsAsInvoices();
                  },
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPreferences().then((_) {
      _loadInscriptionsAsInvoices();
      _loadRecentPayments();
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final sp = await SharedPreferences.getInstance();
      setState(() {
        _applyAdvances = sp.getBool('facturation.applyAdvances') ?? _applyAdvances;
      });
    } catch (_) {}
  }

  Future<void> _loadInscriptionsAsInvoices() async {
    setState(() { _loading = true; });
    final db = DatabaseService();
    final rows = await db.getInscriptionsForInvoicing();
  // also load generic service invoices and map them to Invoice objects
  final genRows = await db.getInvoices(onlyGeneric: true);

    // Map rows to Invoice objects. For now use a default status (sent) and simple numbering.
    int counter = 1;
    final mapped = <Invoice>[];
    for (final r in rows) {
      final id = (r['inscriptionId'] ?? '') as String;
      final dateMs = (r['inscriptionDate'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
      final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
      final due = date.add(const Duration(days: 30));
      final clientName = (r['studentName'] ?? 'Inconnu') as String;
      final formationTitle = (r['formationTitle'] ?? 'Formation') as String;
      final unitPrice = (r['formationPrice'] as num?)?.toDouble() ?? 0.0;
      final discount = (r['discountPercent'] as num?)?.toDouble() ?? 0.0;
      final subtotal = unitPrice;
      final total = subtotal * (1 - (discount / 100.0));
      // Determine status by checking payments for this inscription
      final sums = await db.getPaymentSumsForInscription(id);
      print('Payment sums for inscription $id: $sums');
      final paidSumRaw = (sums['paid'] as num?)?.toDouble() ?? 0.0;
      final credits = (sums['credits'] as num?)?.toDouble() ?? 0.0;
      final effectivePaid = _applyAdvances ? (paidSumRaw + credits) : paidSumRaw;
      InvoiceStatus status = InvoiceStatus.sent;
      // An invoice is overdue if the due date is passed and it's not fully paid.
      if (DateTime.now().isAfter(due) && effectivePaid < total) {
        status = InvoiceStatus.overdue;
      }
      // A paid invoice will override the overdue status.
      if (effectivePaid >= total) {
        status = InvoiceStatus.paid;
      }
      print('Invoice ID: $id, Client: $clientName, Total: $total, Paid: $effectivePaid, Due: ${DateFormat('dd/MM/yyyy').format(due)}, Status: $status');

      mapped.add(Invoice(
        id: id,
        number: 'INS-${DateTime.now().year}-${counter.toString().padLeft(4, '0')}',
        clientName: '$clientName',
        studentId: (r['studentId'] ?? '') as String?,
        formationId: (r['formationId'] ?? '') as String?,
        date: date,
        dueDate: due,
        subtotal: subtotal,
        discount: discount,
        taxRate: 0,
        total: total,
        status: status,
        items: [InvoiceItem(description: formationTitle, quantity: 1, unitPrice: unitPrice)],
      ));
      counter++;
    }
    // Map generic invoices and append after inscription-based invoices
    for (final g in genRows) {
      try {
        final amt = (g['amount'] as num?)?.toDouble() ?? 0.0;
        final date = DateTime.tryParse((g['date'] as String?) ?? '') ?? DateTime.now();
        final due = DateTime.tryParse((g['dueDate'] as String?) ?? '') ?? date.add(const Duration(days: 30));
        final statusStr = (g['status'] as String?) ?? 'sent';
        InvoiceStatus status = InvoiceStatus.sent;
        if (statusStr == 'paid') status = InvoiceStatus.paid;
        if (statusStr == 'overdue') status = InvoiceStatus.overdue;
        if (statusStr == 'draft') status = InvoiceStatus.draft;
        if (statusStr == 'cancelled') status = InvoiceStatus.cancelled;

        mapped.add(Invoice(
          id: (g['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
          number: (g['number'] as String?) ?? (g['id'] as String?) ?? '',
          clientName: (g['clientName'] as String?) ?? (g['client'] as String?) ?? 'Client',
          studentId: null,
          formationId: null,
          date: date,
          dueDate: due,
          subtotal: amt,
          discount: 0,
          taxRate: (g['taxRate'] as num?)?.toDouble() ?? 0,
          total: amt,
          status: status,
          currency: (g['currency'] as String?) ?? 'FCFA',
          items: [InvoiceItem(description: (g['description'] as String?) ?? '', quantity: 1, unitPrice: amt)],
        ));
      } catch (_) {}
    }

    _invoices = mapped;
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.fadeAnimation,
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesList(),
                _buildPaymentTracking(),
                _buildQuickPayment(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1E293B),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF3B82F6),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: const [
          Tab(icon: Icon(Icons.receipt_long), text: 'Factures'),
          Tab(icon: Icon(Icons.timeline), text: 'Suivi Paiements'),
          Tab(icon: Icon(Icons.point_of_sale), text: 'Encaissement'),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    List<Invoice> filteredInvoices = _invoices;
    if (_searchQuery.isNotEmpty) {
      filteredInvoices = filteredInvoices
          .where((invoice) =>
              invoice.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              invoice.number.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedStatus != null) {
      filteredInvoices = filteredInvoices.where((invoice) => invoice.status == _selectedStatus).toList();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // unified invoices list (inscription-based + service invoices)
          _buildInvoiceStats(),
          const SizedBox(height: 16),
          _buildInvoiceFilters(),
          const SizedBox(height: 16),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, idx) => _buildInvoiceCard(filteredInvoices[idx]),
                ),
        ],
      ),
    );
  }

  // generic-specific card removed; generic invoices are now mapped to Invoice and use _buildInvoiceCard

  // Editing generic invoices is still supported via invoice details / edit flow - kept at a single entry point

  void _exportInvoicePdfForModel(Invoice invoice) async {
    final db = DatabaseService();
    try {
      final templates = await db.getDocumentTemplates();

      if (templates.isNotEmpty) {
        // Ask user to choose a template
        DocumentTemplate? selected = templates.firstWhere((t) => t.type == 'facture', orElse: () => templates.first);
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(builder: (ctx2, setStateDialog) {
              return AlertDialog(
                title: const Text('Choisir un modèle de facture'),
                content: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: templates.map((t) {
                        return RadioListTile<DocumentTemplate>(
                          value: t,
                          groupValue: selected,
                          title: Text(t.name ?? t.id),
                          subtitle: Text(t.type ?? ''),
                          onChanged: (v) => setStateDialog(() => selected = v),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (selected != null) {
                        final data = {
                          'invoice_number': invoice.number,
                          'invoice_date': DateFormat('dd/MM/yyyy').format(invoice.date),
                          'due_date': DateFormat('dd/MM/yyyy').format(invoice.dueDate),
                          'client_name': invoice.clientName,
                          'student_id': invoice.studentId ?? '',
                          'formation_name': invoice.items.isNotEmpty ? invoice.items.first.description : '',
                          'unit_price': invoice.items.isNotEmpty ? invoice.items.first.unitPrice.toStringAsFixed(0) : invoice.subtotal.toStringAsFixed(0),
                          'line_total': invoice.total.toStringAsFixed(0),
                          'subtotal': invoice.subtotal.toStringAsFixed(0),
                          'tax': invoice.taxRate == 0 ? 'Non applicable' : invoice.taxAmount.toStringAsFixed(0),
                          'total': invoice.total.toStringAsFixed(0),
                        };
                        try {
                          final bytes = await generatePdfFromCanvasTemplate(selected!, data);
                          final filePath = await FilePicker.platform.saveFile(
                            dialogTitle: 'Sauvegarder la facture',
                            fileName: 'Facture-${invoice.number}.pdf',
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                          if (filePath != null) {
                            final file = File(filePath);
                            await file.writeAsBytes(bytes);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facture sauvegardée dans $filePath')));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sauvegarde annulée.')));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la génération du PDF: $e')));
                        }
                      }
                    },
                    child: const Text('Exporter avec modèle'),
                  ),
                ],
              );
            });
          },
        );
        return;
      }

      // No templates: build a nicer fallback PDF with company logo and totals
      final company = await db.getCompanyInfo();
      final pdf = pw.Document();

      pw.Widget header = pw.Column(children: [pw.Text('Facture ${invoice.number}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 6)]);
      if (company != null && company.logoPath != null && company.logoPath!.isNotEmpty) {
        try {
          final f = File(company.logoPath!);
          if (await f.exists()) {
            final logo = pw.MemoryImage(await f.readAsBytes());
            header = pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(company.name ?? '', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(company.address ?? ''),
                if (company.phone != null) pw.Text('Tél: ${company.phone}'),
              ]),
              pw.Container(width: 80, height: 80, child: pw.Image(logo, fit: pw.BoxFit.contain)),
            ]);
          }
        } catch (_) {}
      } else if (company != null) {
        header = pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(company.name ?? '', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(company.address ?? ''),
            if (company.phone != null) pw.Text('Tél: ${company.phone}'),
          ]),
          pw.SizedBox(width: 80),
        ]);
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return [
            header,
            pw.SizedBox(height: 12),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Facturé à:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(invoice.clientName),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Date: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(invoice.date)}'),
                pw.Text('Échéance: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(invoice.dueDate)}'),
              ]),
            ]),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              context: ctx,
              data: <List<String>>[
                ['Désignation', 'Qté', 'PU', 'Total'],
                ...invoice.items.map((it) => [it.description, it.quantity.toString(), _currencyFormat.format(it.unitPrice), _currencyFormat.format(it.total)]),
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 12),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Column(children: [
                pw.Row(children: [pw.Text('Sous-total: '), pw.SizedBox(width: 8), pw.Text(_currencyFormat.format(invoice.subtotal))]),
                pw.Row(children: [pw.Text('TVA: '), pw.SizedBox(width: 8), pw.Text(_currencyFormat.format(invoice.taxAmount))]),
                pw.Divider(),
                pw.Row(children: [pw.Text('Total: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), pw.SizedBox(width: 8), pw.Text(_currencyFormat.format(invoice.total), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
              ])
            ])
          ];
        },
      ));

      final bytes = await pdf.save();
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Sauvegarder la facture',
        fileName: 'Facture-${invoice.number}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (filePath != null) {
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facture sauvegardée dans $filePath')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sauvegarde annulée.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export PDF: $e')));
    }
  }

  Widget _buildInvoiceStats() {
    final totalAmount = _invoices.where((i) => i.status != InvoiceStatus.cancelled).fold<double>(0, (sum, invoice) => sum + invoice.total);
    final paidAmount = _invoices.where((i) => i.status == InvoiceStatus.paid).fold<double>(0, (sum, invoice) => sum + invoice.total);
    final overdueAmount = _invoices.where((i) => i.status == InvoiceStatus.overdue).fold<double>(0, (sum, invoice) => sum + invoice.total);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Total facturé', totalAmount, Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Encaissé', paidAmount, Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('En retard', overdueAmount, Colors.red),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, double amount, Color color) {
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '${_currencyFormat.format(amount)} FCFA',
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Rechercher une facture...',
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<InvoiceStatus?>(
          value: _selectedStatus,
          hint: const Text('Statut', style: TextStyle(color: Colors.white60)),
          dropdownColor: const Color(0xFF1E293B),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: Colors.white))),
            ...InvoiceStatus.values.map((status) => DropdownMenuItem(
              value: status,
              child: Text(_getStatusText(status), style: const TextStyle(color: Colors.white)),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      color: const Color(0xFF0F172A),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      invoice.clientName,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_currencyFormat.format(invoice.total)} ${invoice.currency}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    _buildStatusChip(invoice.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Émise le ${DateFormat('dd/MM/yyyy').format(invoice.date)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  'Échéance : ${DateFormat('dd/MM/yyyy').format(invoice.dueDate)}',
                  style: TextStyle(
                    color: invoice.status == InvoiceStatus.overdue ? Colors.red : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showInvoiceDetails(invoice),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Détails'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: invoice.status != InvoiceStatus.paid ? () => _recordPayment(invoice) : null,
                    icon: const Icon(Icons.payment),
                    label: const Text('Encaisser'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _sendReminder(invoice),
                  icon: const Icon(Icons.send, color: Colors.orange),
                ),
                IconButton(
                  onPressed: () => _exportInvoicePdfForModel(invoice),
                  icon: const Icon(Icons.share, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(InvoiceStatus status) {
    Color color;
    switch (status) {
      case InvoiceStatus.paid:
        color = Colors.green;
        break;
      case InvoiceStatus.overdue:
        color = Colors.red;
        break;
      case InvoiceStatus.sent:
        color = Colors.blue;
        break;
      case InvoiceStatus.draft:
        color = Colors.grey;
        break;
      case InvoiceStatus.cancelled:
        color = Colors.red.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildPaymentTracking() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline des paiements',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._invoices.map(_buildPaymentTimeline),
        ],
      ),
    );
  }

  Widget _buildPaymentTimeline(Invoice invoice) {
    return Card(
      color: const Color(0xFF0F172A),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${invoice.number} - ${invoice.clientName}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(invoice.status),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineStep('Facture créée', invoice.date, true, Colors.blue),
            _buildTimelineStep('Envoyée au client', invoice.date, invoice.status != InvoiceStatus.draft, Colors.orange),
            _buildTimelineStep('Échéance', invoice.dueDate, false, invoice.status == InvoiceStatus.overdue ? Colors.red : Colors.grey),
            if (invoice.status == InvoiceStatus.paid)
              _buildTimelineStep('Paiement reçu', DateTime.now(), true, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String title, DateTime date, bool completed, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? color : Colors.grey,
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: completed ? Colors.white : Colors.white60,
                    fontWeight: completed ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPayment() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Encaissement rapide',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildQuickPaymentForm(),
          const SizedBox(height: 24),
          _buildPaymentHistory(),
        ],
      ),
    );
  }

  Widget _buildQuickPaymentForm() {
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nouveau paiement',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quickPaymentAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Montant dû',
                      prefixText: 'FCFA ',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<PaymentMethod>(
                    value: _quickPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Mode',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: PaymentMethod.values.map((method) => DropdownMenuItem(
                      value: method,
                      child: Text(_getPaymentMethodText(method), style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _quickPaymentMethod = value ?? PaymentMethod.cash;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quickPaymentNoteController,
              decoration: const InputDecoration(
                labelText: 'Note (facultatif)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountGivenController,
              decoration: const InputDecoration(
                labelText: 'Montant donné par le client',
                prefixText: 'FCFA ',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Monnaie à rendre: ${_currencyFormat.format(_changeAmount)} FCFA',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _calculateChange,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculer monnaie'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveQuickPayment,
                    icon: const Icon(Icons.print),
                    label: const Text('Encaisser & Imprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique des encaissements',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_payments.isEmpty)
              const Text(
                'Aucun paiement enregistré aujourd\'hui',
                style: TextStyle(color: Colors.white70),
              )
            else
              ..._payments.take(5).map((payment) => ListTile(
                leading: Icon(
                  _getPaymentMethodIcon(payment.method),
                  color: Colors.green,
                ),
                title: Text(
                  '${_currencyFormat.format(payment.amount)} FCFA',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _getPaymentMethodText(payment.method),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Text(
                  DateFormat('HH:mm').format(payment.date),
                  style: const TextStyle(color: Colors.white60),
                ),
              )),
          ],
        ),
      ),
    );
  }

  // Méthodes utilitaires
  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Brouillon';
      case InvoiceStatus.sent: return 'Envoyée';
      case InvoiceStatus.paid: return 'Payée';
      case InvoiceStatus.overdue: return 'En retard';
      case InvoiceStatus.cancelled: return 'Annulée';
    }
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash: return 'Espèces';
      case PaymentMethod.check: return 'Chèque';
      case PaymentMethod.transfer: return 'Virement';
      case PaymentMethod.mobileMoney: return 'Mobile Money';
      case PaymentMethod.card: return 'Carte';
    }
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash: return Icons.money;
      case PaymentMethod.check: return Icons.receipt;
      case PaymentMethod.transfer: return Icons.account_balance;
      case PaymentMethod.mobileMoney: return Icons.phone_android;
      case PaymentMethod.card: return Icons.credit_card;
    }
  }

  // Actions
  void _showNewInvoiceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => const NewInvoiceDialog(),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture créée avec succès')),
      );
  // Recharger les données
  await _loadInscriptionsAsInvoices();
    }
  }

  void _exportInvoices() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Préparation de l\'export PDF...')),
    );

    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Sélectionner un dossier pour l\'export des factures',
    );

    if (directoryPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export annulé: aucun dossier sélectionné.')),
      );
      return;
    }

    int exportedCount = 0;
    final db = DatabaseService();

    for (final invoice in _invoices) {
      try {
        Uint8List? bytes;
        final templates = await db.getDocumentTemplates();

        if (templates.isNotEmpty) {
          // Use the first available invoice template for batch export
          DocumentTemplate? selectedTemplate;
          try {
            selectedTemplate = templates.firstWhere((t) => t.type == 'facture');
          } catch (e) {
            // No matching template found, selectedTemplate remains null
          }
          if (selectedTemplate != null) {
            final data = {
              'invoice_number': invoice.number,
              'invoice_date': DateFormat('dd/MM/yyyy').format(invoice.date),
              'due_date': DateFormat('dd/MM/yyyy').format(invoice.dueDate),
              'client_name': invoice.clientName,
              'student_id': invoice.studentId ?? '',
              'formation_name': invoice.items.isNotEmpty ? invoice.items.first.description : '',
              'unit_price': invoice.items.isNotEmpty ? invoice.items.first.unitPrice.toStringAsFixed(0) : invoice.subtotal.toStringAsFixed(0),
              'line_total': invoice.total.toStringAsFixed(0),
              'subtotal': invoice.subtotal.toStringAsFixed(0),
              'tax': invoice.taxRate == 0 ? 'Non applicable' : invoice.taxAmount.toStringAsFixed(0),
              'total': invoice.total.toStringAsFixed(0),
            };
            bytes = await generatePdfFromCanvasTemplate(selectedTemplate, data);
          }
        }

        if (bytes == null) {
          // Fallback to generic PDF generation if no template or template failed
          final company = await db.getCompanyInfo();
          final pdf = pw.Document();

          pw.Widget header = pw.Column(children: [pw.Text('Facture ${invoice.number}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 6)]);
          if (company != null && company.logoPath != null && company.logoPath!.isNotEmpty) {
            try {
              final f = File(company.logoPath!); // Assuming company.logoPath is a valid file path
              if (await f.exists()) {
                final logo = pw.MemoryImage(await f.readAsBytes());
                header = pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(company.name ?? '', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(company.address ?? ''),
                    if (company.phone != null) pw.Text('Tél: ${company.phone}'),
                  ]),
                  pw.Container(width: 80, height: 80, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                ]);
              }
            } catch (_) {}
          } else if (company != null) {
            header = pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(company.name ?? '', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(company.address ?? ''),
                if (company.phone != null) pw.Text('Tél: ${company.phone}'),
              ]),
              pw.SizedBox(width: 80),
            ]);
          }

          pdf.addPage(pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) {
              return [
                header,
                pw.SizedBox(height: 12),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Facturé à:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(invoice.clientName),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Date: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(invoice.date)}'),
                    pw.Text('Échéance: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(invoice.dueDate)}'),
                  ]),
                ]),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(
                  context: ctx,
                  data: <List<String>>[
                    ['Désignation', 'Qté', 'PU', 'Total'],
                    ...invoice.items.map((it) => [it.description, it.quantity.toString(), _currencyFormat.format(it.unitPrice), _currencyFormat.format(it.total)]),
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 12),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                  pw.Column(children: [
                    pw.Row(children: [pw.Text('Sous-total: '), pw.SizedBox(width: 8), pw.Text(_currencyFormat.format(invoice.subtotal))]),
                    pw.Row(children: [pw.Text('TVA: '), pw.SizedBox(width: 8), pw.Text(_currencyFormat.format(invoice.taxAmount))]),
                    pw.Divider(),
                    pw.Row(children: [pw.Text('Total: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), pw.SizedBox(width: 8), pw.Text(_currencyFormat.format(invoice.total), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
                  ])
                ])
              ];
            },
          ));
          bytes = await pdf.save();
        }

        if (bytes != null) {
          final fileName = 'Facture-${invoice.number.replaceAll('/', '_')}.pdf'; // Sanitize filename
          final file = File('$directoryPath/$fileName');
          await file.writeAsBytes(bytes);
          exportedCount++;
        }
      } catch (e) {
        print('Erreur lors de l\'export de la facture ${invoice.number}: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$exportedCount factures exportées vers $directoryPath')),
    );
  }

  void _showInvoiceDetails(Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<Map<String, Object?>>> (
        future: DatabaseService().getPaymentsByStudent(invoice.studentId ?? '', inscriptionId: invoice.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
          }
          final payments = snap.data ?? [];
          return AlertDialog(
            title: Text('Détails facture ${invoice.number}'),
            content: SizedBox(
              width: double.maxFinite,
              child: payments.isEmpty
                ? const Text('Aucun paiement enregistré')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_,__) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final p = payments[i];
                      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                      final isCredit = ((p['isCredit'] as int?) == 1);
                      final created = p['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(p['createdAt'] as int) : null;
                      return ListTile(
                        leading: Icon(isCredit ? Icons.account_balance_wallet : Icons.payment, color: isCredit ? Colors.orange : Colors.green),
                        title: Text('${_currencyFormat.format(amount)} FCFA'),
                        subtitle: Text('${p['method'] ?? ''} • ${created != null ? DateFormat('dd/MM/yyyy HH:mm').format(created) : ''}'),
                        trailing: isCredit ? const Text('Avance', style: TextStyle(color: Colors.orange)) : null,
                      );
                    },
                  ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ],
          );
        },
      ),
    );
  }

  void _recordPayment(Invoice invoice) async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (ctx) {
        final _amountCtrl = TextEditingController(text: invoice.total.toStringAsFixed(0));
        bool isAdvance = false;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Enregistrer un paiement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
                ),
                Row(
                  children: [
                    Checkbox(value: isAdvance, onChanged: (v) => setStateDialog(() => isAdvance = v ?? false)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Paiement comme avance (isCredit)')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              TextButton(onPressed: () => Navigator.pop(ctx, {'amount': double.tryParse(_amountCtrl.text), 'isCredit': isAdvance}), child: const Text('Enregistrer')),
            ],
          );
        });
      },
    );

    if (result == null) return;
    final amount = (result['amount'] as double?);
    final isCredit = (result['isCredit'] as bool?) ?? false;
    if (amount == null) return;
    final db = DatabaseService();
    final payment = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'studentId': invoice.studentId ?? '',
      'inscriptionId': invoice.id,
      'formationId': invoice.formationId ?? null,
      'amount': amount,
      'method': 'cash',
      'isCredit': isCredit ? 1 : 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await db.insertPayment(payment);
    // Reload invoices
    await _loadInscriptionsAsInvoices();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement enregistré')));
  }

  void _sendReminder(Invoice invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Relance envoyée pour ${invoice.number}')),
    );
  }

  Future<void> _loadRecentPayments() async {
    final db = DatabaseService();
    final paymentsRaw = await db.getRecentPayments();
    final payments = paymentsRaw.map((p) => Payment.fromMap(p)).toList();
    if (mounted) {
      setState(() {
        _payments = payments;
      });
    }
  }

  void _calculateChange() {
    final amountDue = double.tryParse(_quickPaymentAmountController.text) ?? 0.0;
    final amountGiven = double.tryParse(_amountGivenController.text) ?? 0.0;

    if (amountGiven < amountDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le montant donné est insuffisant.'), backgroundColor: Colors.red),
      );
      setState(() {
        _changeAmount = 0.0;
      });
      return;
    }

    setState(() {
      _changeAmount = amountGiven - amountDue;
    });
  }

  void _saveQuickPayment() async {
    final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
    final amount = double.tryParse(_quickPaymentAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide.'), backgroundColor: Colors.red),
      );
      return;
    }

    final payment = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'studentId': null,
      'inscriptionId': null,
      'formationId': null,
      'amount': amount,
      'method': _quickPaymentMethod.name,
      'note': _quickPaymentNoteController.text,
      'isCredit': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    final db = DatabaseService();
    await db.insertPayment(payment);

    // Clear form and reload history
    _quickPaymentAmountController.clear();
    _quickPaymentNoteController.clear();
    _amountGivenController.clear(); // Clear amount given as well
    setState(() {
      _changeAmount = 0.0; // Reset change amount
    });
    await _loadRecentPayments();

    // Create a temporary Invoice object for the receipt
    final now = DateTime.now();
    final receiptNumber = 'REC-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(now.millisecondsSinceEpoch.toString().length - 4)}';
    final tempInvoice = Invoice(
      id: paymentId,
      number: receiptNumber,
      clientName: 'Client Divers', // Or add a field for client name in quick payment
      studentId: null,
      formationId: null,
      date: now,
      dueDate: now, // Not really applicable for a receipt
      subtotal: amount,
      discount: 0,
      taxRate: 0,
      total: amount,
      status: InvoiceStatus.paid,
      currency: 'FCFA', // Assuming default currency
      items: [InvoiceItem(description: 'Paiement rapide', quantity: 1, unitPrice: amount)],
    );

    // Call the PDF export function
    _exportInvoicePdfForModel(tempInvoice);

    // _showReceiptDialog(); // No longer needed
  }

  void _showReceiptDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reçu généré', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Paiement enregistré avec succès', style: TextStyle(color: Colors.white)),
            Text('Reçu imprimé', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class NewInvoiceDialog extends StatefulWidget {
  const NewInvoiceDialog({Key? key}) : super(key: key);

  @override
  State<NewInvoiceDialog> createState() => _NewInvoiceDialogState();
}

class _NewInvoiceDialogState extends State<NewInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clientController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = 'FCFA';
  double _taxRate = 18.0;
  double _discount = 0.0;
  bool _isVatApplicable = true;
  String _mode = 'inscription'; // or 'service'
  String? _selectedFormationId;
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouvelle facture',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Type', labelStyle: TextStyle(color: Colors.white70)),
                items: const [
                  DropdownMenuItem(value: 'inscription', child: Text('Inscription')),
                  DropdownMenuItem(value: 'service', child: Text('Service')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'inscription'),
              ),
              const SizedBox(height: 12),
              if (_mode == 'inscription')
                Autocomplete<Student>(
                  displayStringForOption: (Student option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Student>.empty();
                    }
                    final students = await DatabaseService().getStudents();
                    return students.where((Student option) {
                      final searchLower = textEditingValue.text.toLowerCase();
                      return option.name.toLowerCase().contains(searchLower) ||
                             option.studentNumber.toLowerCase().contains(searchLower);
                    });
                  },
                  onSelected: (Student selection) {
                    setState(() {
                      _clientController.text = selection.name;
                      _selectedStudentId = selection.id;
                    });
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    return TextFormField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Etudiant',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                )
              else
                TextFormField(
                  controller: _clientController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du client / bénéficiaire',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => v?.trim().isEmpty == true ? 'Client requis' : null,
                ),
              const SizedBox(height: 12),
              if (_mode == 'inscription')
                FutureBuilder<List<Map<String, Object?>>>(
                  future: DatabaseService().getFormations().then((fs) => fs.map((f) => f.toMap()).toList()),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();
                    final items = snap.data!;
                    return DropdownButtonFormField<String>(
                      value: _selectedFormationId,
                      decoration: const InputDecoration(labelText: 'Formation', labelStyle: TextStyle(color: Colors.white70)),
                      items: items.map((f) => DropdownMenuItem(value: f['id'] as String?, child: Text(f['title'] as String? ?? ''))).toList(),
                      onChanged: (v) => setState(() => _selectedFormationId = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Sélectionner une formation' : null,
                    );
                  },
                )
              else
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description du service',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Montant HT',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      validator: (v) {
                        final amount = double.tryParse(v ?? '');
                        return amount == null || amount <= 0 ? 'Montant invalide' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Monnaie',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      items: ['FCFA', 'EUR', 'USD'].map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Appliquer la TVA', style: TextStyle(color: Colors.white)),
                value: _isVatApplicable,
                onChanged: (value) {
                  setState(() {
                    _isVatApplicable = value;
                  });
                },
              ),
              if (_isVatApplicable)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _taxRate.toString(),
                        decoration: const InputDecoration(
                          labelText: 'TVA (%)',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => _taxRate = double.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _discount.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Remise',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => _discount = double.tryParse(v) ?? 0,
                      ),
                    ),
                  ],
                )
              else
                TextFormField(
                  initialValue: _discount.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Remise',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => _discount = double.tryParse(v) ?? 0,
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() == true) {
                        final db = DatabaseService();
                        if (_mode == 'inscription') {
                          if (_selectedStudentId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez sélectionner un étudiant.'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          final forms = await db.getFormations();
                          Formation? form;
                          try {
                            form = forms.firstWhere((f) => f.id == _selectedFormationId);
                          } catch (_) {
                            form = null;
                          }
                          final price = form != null ? form.price : 0.0;
                          final title = form != null ? form.title : '';

                          final inscriptionId = DateTime.now().millisecondsSinceEpoch.toString();
                          await db.addInscription({
                            'id': inscriptionId,
                            'studentId': _selectedStudentId!,
                            'formationId': _selectedFormationId ?? '',
                            'formationTitle': title,
                            'price': price,
                            'discountPercent': _discount,
                            'inscriptionDate': DateTime.now().millisecondsSinceEpoch,
                            'status': 'Impayé',
                          });

                        } else {
                          final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
                          final taxRate = _isVatApplicable ? _taxRate : 0.0;
                          final invId = DateTime.now().millisecondsSinceEpoch.toString();
                          final number = await db.getNextPieceNumberForJournal('INVOICE');
                          final inv = {
                            'id': invId,
                            'number': number,
                            'clientName': _clientController.text.trim(),
                            'description': _descriptionController.text.trim(),
                            'amount': amount,
                            'currency': _currency,
                            'date': DateTime.now().toIso8601String(),
                            'dueDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                            'status': 'sent',
                            'isInscription': 0,
                            'relatedInscriptionId': null,
                            'createdAt': DateTime.now().toIso8601String(),
                          };
                          await db.insertInvoice(inv);
                        }

                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('Créer facture'),
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
