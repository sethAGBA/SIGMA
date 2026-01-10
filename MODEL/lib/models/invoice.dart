
// ...existing code...

// Models
class Invoice {
  final String id;
  final String number;
  final String clientName;
  final String? studentId;
  final String? formationId;
  final DateTime date;
  final DateTime dueDate;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double total;
  final InvoiceStatus status;
  final String currency;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.number,
    required this.clientName,
    this.studentId,
    this.formationId,
    required this.date,
    required this.dueDate,
    required this.subtotal,
    this.discount = 0,
    this.taxRate = 0,
    required this.total,
    required this.status,
    this.currency = 'FCFA',
    this.items = const [],
  });

  double get taxAmount => (subtotal - discount) * taxRate / 100;
  double get totalWithTax => subtotal - discount + taxAmount;
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });
}

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }
