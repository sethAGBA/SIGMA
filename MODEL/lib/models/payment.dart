enum PaymentMethod { cash, check, transfer, mobileMoney, card }

class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String? reference;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.date,
    this.reference,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      invoiceId: map['invoiceId'] ?? '',
      amount: map['amount'],
      method: PaymentMethod.values.firstWhere((e) => e.toString() == 'PaymentMethod.${map['method']}', orElse: () => PaymentMethod.cash),
      date: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      reference: map['note'],
    );
  }
}
