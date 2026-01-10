
import 'package:afroforma/services/database_service.dart';

class FinancialAnalysisService {
  final DatabaseService _dbService = DatabaseService();

  Future<Map<String, double>> getMonthlyRevenue(int year) async {
    final db = await _dbService.db;
    final Map<String, double> monthlyRevenue = {};

    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1).millisecondsSinceEpoch;
      final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
      final rows = await db.rawQuery(
          'SELECT SUM(amount) as s FROM student_payments WHERE createdAt >= ? AND createdAt < ?',
          [start, end]);
      final revenue = (rows.first['s'] as num?)?.toDouble() ?? 0.0;
      monthlyRevenue[month.toString()] = revenue;
    }

    return monthlyRevenue;
  }

  Future<Map<String, double>> getRevenueByFormation() async {
    final db = await _dbService.db;
    final rows = await db.rawQuery('''
      SELECT f.title, SUM(p.amount) as revenue
      FROM student_payments p
      JOIN formations f ON p.formationId = f.id
      GROUP BY f.title
    ''');

    final Map<String, double> revenueByFormation = {};
    for (final row in rows) {
      revenueByFormation[row['title'] as String] = (row['revenue'] as num?)?.toDouble() ?? 0.0;
    }

    return revenueByFormation;
  }

  Future<double> getRecoveryRate() async {
    return _dbService.getRecoveryRate();
  }
}
