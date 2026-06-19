// lib/core/utils/loan_calculator.dart
//
// Calculs TEG et échéancier avec différé de capital (Phase 4).

class LoanCalculator {
  /// TEG simplifié UEMOA/OHADA.
  /// TEG = tauxNominal + tauxAssurance + (fraisDossier / montant / (dureesMois/12)) * 100
  static double calculerTEG({
    required double tauxNominalAnnuel,
    double tauxAssurance = 0,
    double fraisDossier = 0,
    required double montantPret,
    required int dureesMois,
  }) {
    if (montantPret <= 0 || dureesMois <= 0) return tauxNominalAnnuel;
    final coutFrais =
        (fraisDossier / montantPret) / (dureesMois / 12) * 100;
    return tauxNominalAnnuel + tauxAssurance + coutFrais;
  }

  /// Génère les lignes d'échéancier (capital_du, interets_dus, total_du).
  static List<Map<String, double>> calculerEcheancierAvecDiffere({
    required double montant,
    required int duree,
    required double tauxAnnuel,
    int moisDiffere = 0,
  }) {
    if (montant <= 0 || duree <= 0) return [];

    final differe = moisDiffere.clamp(0, duree - 1);
    final tauxMensuel = tauxAnnuel / 100 / 12;
    final amortMonths = duree - differe;
    final capitalMensuel = amortMonths > 0 ? montant / amortMonths : montant;

    final rows = <Map<String, double>>[];
    double capitalRestant = montant;

    for (var i = 1; i <= duree; i++) {
      final interets = montant * tauxMensuel;
      if (i <= differe) {
        rows.add({
          'capital_du': 0,
          'interets_dus': interets,
          'total_du': interets,
        });
      } else {
        final capital = capitalMensuel.clamp(0, capitalRestant).toDouble();
        capitalRestant -= capital;
        rows.add({
          'capital_du': capital,
          'interets_dus': interets,
          'total_du': capital + interets,
        });
      }
    }
    return rows;
  }
}
