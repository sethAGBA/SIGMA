import 'package:sqflite/sqflite.dart';

import '../../models/plan_comptable_type.dart';
import '../utils/plan_parser.dart';
import 'plan_comptable_loader.dart';

class ChartOfAccountsService {
  Future<void> insertFullChartOfAccounts(
    Database db, {
    PlanComptableType type = PlanComptableType.rcssfd,
  }) async {
    final content = await PlanComptableLoader.load(type);
    final accounts = PlanParser.parse(content);
    final batch = db.batch();

    for (var account in accounts) {
      batch.insert(
        'comptes_comptables',
        account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Réinitialise le plan comptable selon le type choisi (RCSSFD ou SYSCOHADA).
  Future<void> reseedChartOfAccounts(
    Database db,
    PlanComptableType type,
  ) async {
    await db.delete('comptes_comptables');
    await insertFullChartOfAccounts(db, type: type);
  }
}
