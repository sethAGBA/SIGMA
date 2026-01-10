// lib/models/cash_closing_model.dart

class CashClosing {
  final int? id;
  final DateTime dateCloture;
  final String agentCloture;
  final double soldeInitial;
  final double totalEntrees;
  final double totalSorties;
  final double soldeTheorique;
  final double soldePhysique;
  final double ecart;
  final String? observations;
  final String? billetage; // JSON string for detail of banknotes

  CashClosing({
    this.id,
    required this.dateCloture,
    required this.agentCloture,
    required this.soldeInitial,
    required this.totalEntrees,
    required this.totalSorties,
    required this.soldeTheorique,
    required this.soldePhysique,
    required this.ecart,
    this.observations,
    this.billetage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_cloture': dateCloture.toIso8601String(),
      'agent_cloture': agentCloture,
      'solde_initial': soldeInitial,
      'total_entrees': totalEntrees,
      'total_sorties': totalSorties,
      'solde_theorique': soldeTheorique,
      'solde_physique': soldePhysique,
      'ecart': ecart,
      'observations': observations,
      'billetage': billetage,
    };
  }

  factory CashClosing.fromMap(Map<String, dynamic> map) {
    return CashClosing(
      id: map['id'],
      dateCloture: DateTime.parse(map['date_cloture']),
      agentCloture: map['agent_cloture'] ?? '',
      soldeInitial: (map['solde_initial'] as num).toDouble(),
      totalEntrees: (map['total_entrees'] as num).toDouble(),
      totalSorties: (map['total_sorties'] as num).toDouble(),
      soldeTheorique: (map['solde_theorique'] as num).toDouble(),
      soldePhysique: (map['solde_physique'] as num).toDouble(),
      ecart: (map['ecart'] as num).toDouble(),
      observations: map['observations'],
      billetage: map['billetage'],
    );
  }
}
