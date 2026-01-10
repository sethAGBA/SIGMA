import 'package:afroforma/services/database_service.dart';
// import 'package:sqflite/sqflite.dart';

/// Walk all inscriptions and payments, recompute inscription.status and etudiants.paymentStatus.
Future<void> recalculateAllPaymentStatuses() async {
  final db = await DatabaseService().db;

  // Map studentId -> totals
  final Map<String, double> studentTotalPrice = {};
  final Map<String, double> studentTotalPaid = {};

  // Fetch inscriptions with formation price
  final rows = await db.rawQuery('''
    SELECT i.id as inscriptionId, i.studentId as studentId, i.formationId as formationId, COALESCE(f.price, 0) as price
    FROM inscriptions i
    LEFT JOIN formations f ON i.formationId = f.id
  ''');

  for (final r in rows) {
    final inscriptionId = (r['inscriptionId'] as String?) ?? '';
    final studentId = (r['studentId'] as String?) ?? '';
    final price = (r['price'] is num) ? (r['price'] as num).toDouble() : double.tryParse('${r['price']}') ?? 0.0;

    // sum payments for this inscription
    final payRows = await db.rawQuery('SELECT SUM(COALESCE(amount,0)) as s FROM student_payments WHERE inscriptionId = ?', [inscriptionId]);
    final sumPaid = (payRows.isNotEmpty && payRows.first['s'] != null) ? (payRows.first['s'] as num).toDouble() : 0.0;

    // compute inscription status
    String newInsStatus;
    if (sumPaid <= 0.0) newInsStatus = 'Impayé';
    else if (sumPaid < price) newInsStatus = 'Partiel';
    else newInsStatus = 'Soldé';

    await DatabaseService().updateInscriptionStatus(inscriptionId, newInsStatus);

    studentTotalPrice[studentId] = (studentTotalPrice[studentId] ?? 0.0) + price;
    studentTotalPaid[studentId] = (studentTotalPaid[studentId] ?? 0.0) + sumPaid;
  }

  // Update students overall paymentStatus based on totals
  for (final entry in studentTotalPrice.entries) {
    final studentId = entry.key;
    final totalPrice = entry.value;
    final totalPaid = studentTotalPaid[studentId] ?? 0.0;

    String studentStatus;
    if (totalPaid <= 0.0) studentStatus = 'Impayé';
    else if (totalPaid < totalPrice) studentStatus = 'Partiel';
    else studentStatus = 'À jour';

    await DatabaseService().updateStudent({'id': studentId, 'paymentStatus': studentStatus});
  }
}

/// CLI runner so you can call: `dart run lib/utils/recalculate_payment_statuses.dart`
Future<void> main() async {
  print('Recalcul des statuts de paiement...');
  await recalculateAllPaymentStatuses();
  print('Terminé.');
}
