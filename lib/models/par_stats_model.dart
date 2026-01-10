// lib/models/par_stats_model.dart

class PARStats {
  final double encoursTotal;
  final int totalPrets;
  final int pretsEnRetard;

  // Montants par catégorie de retard
  final double parSains; // 0 jour
  final double par1; // 1-30 jours
  final double par30; // 31-90 jours
  final double par90; // 91-180 jours (Douteux)
  final double par180; // > 180 jours (Compromis)

  // Nombres par catégorie
  final int nbSains;
  final int nb1;
  final int nb30;
  final int nb90;
  final int nb180;

  // Autres indicateurs
  final double tauxRemboursement;
  final double penalitesDues;
  final double provisionsConstituees;
  final double tauxCouverture;

  // Analyse par segment (Nouveau)
  final Map<String, double> parParAgence;
  final Map<String, double> parParAgent;
  final Map<String, double> parParProduit;
  final Map<String, double> parParSecteur;
  final Map<String, double> parParTranche;
  final Map<String, double> parGroupeVsIndiv;

  PARStats({
    required this.encoursTotal,
    required this.totalPrets,
    required this.pretsEnRetard,
    required this.parSains,
    required this.par1,
    required this.par30,
    required this.par90,
    required this.par180,
    required this.nbSains,
    required this.nb1,
    required this.nb30,
    required this.nb90,
    required this.nb180,
    required this.tauxRemboursement,
    required this.penalitesDues,
    required this.provisionsConstituees,
    required this.tauxCouverture,
    this.parParAgence = const {},
    this.parParAgent = const {},
    this.parParProduit = const {},
    this.parParSecteur = const {},
    this.parParTranche = const {},
    this.parGroupeVsIndiv = const {},
  });

  double get tauxPAR1 => encoursTotal > 0 ? (par1 / encoursTotal) * 100 : 0;
  double get tauxPAR30 => encoursTotal > 0 ? (par30 / encoursTotal) * 100 : 0;
  double get tauxPAR90 => encoursTotal > 0 ? (par90 / encoursTotal) * 100 : 0;
  double get tauxPAR180 => encoursTotal > 0 ? (par180 / encoursTotal) * 100 : 0;
  double get tauxRisqueGlobal => encoursTotal > 0
      ? ((par1 + par30 + par90 + par180) / encoursTotal) * 100
      : 0;
}
