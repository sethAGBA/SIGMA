import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigma/core/utils/loan_calculator.dart';

void main() {
  group('LoanCalculator.calculerTEG', () {
    test('sans assurance ni frais → TEG == taux nominal', () {
      final teg = LoanCalculator.calculerTEG(
        tauxNominalAnnuel: 12,
        montantPret: 100000,
        dureesMois: 12,
      );
      expect(teg, closeTo(12, 0.001));
    });

    test('avec assurance et frais dossier', () {
      final teg = LoanCalculator.calculerTEG(
        tauxNominalAnnuel: 12,
        tauxAssurance: 0.5,
        fraisDossier: 10000,
        montantPret: 100000,
        dureesMois: 12,
      );
      // 12 + 0.5 + (10000/100000)/(12/12)*100 = 12 + 0.5 + 10 = 22.5
      expect(teg, closeTo(22.5, 0.001));
    });

    test('TEG >= taux nominal (100 itérations)', () {
      final rng = Random(42);
      for (var i = 0; i < 100; i++) {
        final taux = rng.nextDouble() * 30 + 1;
        final assurance = rng.nextDouble() * 2;
        final frais = rng.nextDouble() * 50000;
        final montant = rng.nextDouble() * 5000000 + 10000;
        final duree = rng.nextInt(48) + 1;
        final teg = LoanCalculator.calculerTEG(
          tauxNominalAnnuel: taux,
          tauxAssurance: assurance,
          fraisDossier: frais,
          montantPret: montant,
          dureesMois: duree,
        );
        expect(teg, greaterThanOrEqualTo(taux));
      }
    });
  });

  group('LoanCalculator.calculerEcheancierAvecDiffere', () {
    test('différé 2 mois : capital 0 sur les 2 premières échéances', () {
      final rows = LoanCalculator.calculerEcheancierAvecDiffere(
        montant: 120000,
        duree: 12,
        tauxAnnuel: 12,
        moisDiffere: 2,
      );
      expect(rows.length, 12);
      expect(rows[0]['capital_du'], 0);
      expect(rows[1]['capital_du'], 0);
      expect(rows[2]['capital_du'], greaterThan(0));
    });

    test('somme des capitals = montant initial', () {
      final montant = 250000.0;
      final rows = LoanCalculator.calculerEcheancierAvecDiffere(
        montant: montant,
        duree: 18,
        tauxAnnuel: 15,
        moisDiffere: 3,
      );
      final somme =
          rows.fold<double>(0, (s, r) => s + (r['capital_du'] ?? 0));
      expect(somme, closeTo(montant, 0.01));
    });
  });
}
