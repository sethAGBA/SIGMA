// Property test P1 — champs d'audit = username de session
// Valide : Exigences 4.1, 6.1, 9.2

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/models/cash_closing_model.dart';
import 'package:sigma/models/ecriture_comptable_model.dart';
import 'package:sigma/models/repayment_model.dart';

import '../helpers/test_user_factory.dart';

void main() {
  tearDown(clearAuthUser);

  group('Property 1 — champs d\'audit = username de session', () {
    test('100 itérations : username non vide → champs d\'audit identiques', () {
      final random = Random(42);

      for (var i = 0; i < 100; i++) {
        final length = random.nextInt(50) + 1;
        final username = List.generate(
          length,
          (_) => String.fromCharCode(97 + random.nextInt(26)),
        ).join();

        setAuthUser(username);

        final closing = CashClosing(
          dateCloture: DateTime.now(),
          agentCloture: AuthService().currentUsername,
          soldeInitial: 0,
          totalEntrees: 0,
          totalSorties: 0,
          soldeTheorique: 0,
          soldePhysique: 0,
          ecart: 0,
        );

        final repayment = Repayment(
          pretId: 1,
          montantTotal: 1000,
          partCapital: 800,
          partInterets: 200,
          partPenalites: 0,
          datePaiement: DateTime.now(),
          modePaiement: RepaymentMode.especes,
          numeroRecu: 'REC-TEST',
          agentCollecteur: auditFieldValue(AuthService().currentUsername),
        );

        final ecriture = EcritureComptable(
          dateComptable: DateTime.now(),
          journalCode: 'OD',
          numeroPiece: 'P-$i',
          libelle: 'Test',
          agentSaisie: auditFieldValue(AuthService().currentUsername),
          dateSaisie: DateTime.now(),
        );

        expect(closing.agentCloture, username);
        expect(repayment.agentCollecteur, username);
        expect(ecriture.agentSaisie, username);
      }
    });

    test('username vide → repli Inconnu (Repayment et EcritureComptable)', () {
      clearAuthUser();

      final collecteur = auditFieldValue(AuthService().currentUsername);
      final saisie = auditFieldValue(AuthService().currentUsername);

      expect(collecteur, 'Inconnu');
      expect(saisie, 'Inconnu');
    });
  });
}
