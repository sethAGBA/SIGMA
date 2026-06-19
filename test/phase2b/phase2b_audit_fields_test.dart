// Phase 2b — tests des champs d'audit résiduels

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/core/utils/audit_field_utils.dart';
import 'package:sigma/models/audit_log_model.dart';
import 'package:sigma/models/savings_transaction_model.dart';

import '../helpers/test_user_factory.dart';

void main() {
  tearDown(clearAuthUser);

  group('Phase 2b — auditFieldValue', () {
    test('100 itérations : username non vide conservé', () {
      final random = Random(21);
      for (var i = 0; i < 100; i++) {
        final username = 'agent_${random.nextInt(9999)}';
        expect(auditFieldValue(username), username);
      }
    });

    test('username vide → Inconnu', () {
      expect(auditFieldValue(''), 'Inconnu');
    });
  });

  group('Phase 2b — modèles avec session', () {
    test('SavingsTransaction.agentOperation = username session', () {
      setAuthUser('caissier_01');
      final tx = SavingsTransaction(
        compteId: 1,
        type: SavingsTransactionType.depot,
        montant: 5000,
        soldeApres: 15000,
        dateOperation: DateTime.now(),
        agentOperation: auditFieldValue(AuthService().currentUsername),
      );
      expect(tx.agentOperation, 'caissier_01');
    });

    test('AuditLog.username = username session', () {
      setAuthUser('admin_audit');
      final log = AuditLog(
        id: '1',
        username: auditFieldValue(AuthService().currentUsername),
        action: 'EXPORT_DB',
        details: 'test',
        timestamp: DateTime.now(),
        severity: AuditSeverity.medium,
      );
      expect(log.username, 'admin_audit');
    });
  });
}
