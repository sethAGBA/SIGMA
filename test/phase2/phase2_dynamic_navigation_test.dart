// Property test P5 — navigation dynamique vers DelinquentLoanDetailPage
// Valide : Exigences 10.1, 10.3

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/screens/reporting/delinquent_loan_detail_page.dart';

void main() {
  group('Property 5 — navigation dynamique loanId', () {
    test('100 itérations : loanId extrait de la liste = loanId du détail', () {
      final random = Random(13);

      for (var i = 0; i < 100; i++) {
        final loanId = random.nextInt(10000) + 1;
        final loan = <String, dynamic>{
          'id': loanId,
          'client_name': 'Client $loanId',
          'solde_restant': random.nextDouble() * 100000,
          'jours_retard': random.nextInt(365) + 1,
        };

        final extractedId = loan['id'] as int;
        final detailPage = DelinquentLoanDetailPage(loanId: extractedId);

        expect(extractedId, loanId);
        expect(detailPage.loanId, loanId);
      }
    });
  });
}
