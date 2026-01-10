class AccountingAccount {
  final int? id;
  final String numero;
  final String libelle;
  final int classe;
  final String type; // 'Actif', 'Passif', 'Charge', 'Produit', 'Capitaux'
  final String? parentAccount;
  final bool
  isTitle; // True if it's a category header (e.g. "Class 1"), not a postable account

  AccountingAccount({
    this.id,
    required this.numero,
    required this.libelle,
    required this.classe,
    required this.type,
    this.parentAccount,
    this.isTitle = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'libelle': libelle,
      'classe': classe,
      'type': type,
      'parent_account': parentAccount,
      'is_title': isTitle ? 1 : 0,
    };
  }

  factory AccountingAccount.fromMap(Map<String, dynamic> map) {
    return AccountingAccount(
      id: map['id'],
      numero: map['numero'],
      libelle: map['libelle'],
      classe: map['classe'],
      type: map['type'],
      parentAccount: map['parent_account'],
      isTitle: map['is_title'] == 1,
    );
  }
}
