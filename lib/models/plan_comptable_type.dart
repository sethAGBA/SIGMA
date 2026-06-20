/// Type de plan comptable supporté par SIGMA.
enum PlanComptableType {
  /// Plan SYSCOHADA complet (référentiel OHADA général).
  syscohada('syscohada', 'SYSCOHADA', 'lib/assets/docs/plan_comptable_syscohada.txt'),

  /// Plan RCSSFD — Référentiel Comptable Spécifique SFD (UMOA/BCEAO).
  rcssfd('rcssfd', 'RCSSFD', 'lib/assets/docs/Plan des Comptes RCSSFD.txt');

  const PlanComptableType(this.key, this.label, this.assetPath);

  final String key;
  final String label;
  final String assetPath;

  static PlanComptableType fromKey(String? key) {
    return PlanComptableType.values.firstWhere(
      (t) => t.key == key,
      orElse: () => PlanComptableType.rcssfd,
    );
  }
}
