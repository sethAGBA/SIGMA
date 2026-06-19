# Document de Conception — Phase 4 : Fonctionnalités Métier Avancées

## Vue d'ensemble

La Phase 4 ajoute des fonctionnalités métier à des composants déjà existants. L'approche est chirurgicale : chaque modification cible un fichier précis sans restructurer l'architecture globale.

---

## 1. Champ assurance et calcul TEG

### 1.1 Modifications du modèle `ProduitFinancier`

Ajouter dans `lib/models/produit_financier_model.dart` :
```dart
final double? tauxAssurance;          // % annuel prime assurance décès/invalidité
final int? dureeMaxDiffereCapitalMois; // Durée max différé capital (si differePossible)
```

Ajouter dans `toMap()` :
```dart
'taux_assurance': tauxAssurance,
'duree_max_differe_capital_mois': dureeMaxDiffereCapitalMois,
```

Ajouter la migration SQLite dans `database_service.dart` (`_onUpgrade`, `oldVersion < 30`) :
```sql
ALTER TABLE produits_financiers ADD COLUMN taux_assurance REAL;
ALTER TABLE produits_financiers ADD COLUMN duree_max_differe_capital_mois INTEGER;
```

### 1.2 Calcul TEG — `lib/core/utils/loan_calculator.dart`

Nouveau fichier (ou extension de l'existant) :
```dart
/// Calcule le TEG selon la formule simplifiée UEMOA/OHADA.
/// TEG = tauxNominal + tauxAssurance + (fraisDossier / montant / (dureesMois/12)) * 100
static double calculerTEG({
  required double tauxNominalAnnuel,
  required double tauxAssurance,       // % annuel (0 si absent)
  required double fraisDossier,        // montant fixe en FCFA
  required double montantPret,
  required int dureesMois,
}) {
  if (montantPret <= 0 || dureesMois <= 0) return tauxNominalAnnuel;
  final coutFrais = (fraisDossier / montantPret) / (dureesMois / 12) * 100;
  return tauxNominalAnnuel + tauxAssurance + coutFrais;
}
```

### 1.3 Affichage TEG dans `LoanRequestFormDialog`

Ajouter un `Text` réactif à côté du taux nominal :
```dart
Text('TEG : ${teg.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.orange))
```
Recalculer à chaque changement de montant/durée/produit.

---

## 2. Différé de capital — Calcul de l'échéancier

### 2.1 Champ `moisDiffereCapital` dans le prêt

Ajouter dans `lib/models/loan_model.dart` :
```dart
final int? moisDiffereCapital;
```

Ajouter dans la migration SQLite (`oldVersion < 30`) :
```sql
ALTER TABLE prets ADD COLUMN mois_differe_capital INTEGER DEFAULT 0;
```

### 2.2 Algorithme d'amortissement avec différé

Dans `database_service.dart` → méthode de génération de l'échéancier :

```
Phase 1 — Différé (moisDiffereCapital premiers mois) :
  Pour i = 1..moisDiffereCapital :
    capital_du = 0
    interets_dus = montantInitial × tauxMensuel
    total_du = interets_dus

Phase 2 — Amortissement normal (duree - moisDiffereCapital mois restants) :
  Reprendre le calcul dégressif habituel sur le montant initial
```

---

## 3. Validation PIN superviseur

### 3.1 Widget `PinValidationDialog`

Créer `lib/widgets/dialogs/pin_validation_dialog.dart` :
- `TextField` masqué, 4 chiffres, clavier numérique
- 3 tentatives max → fermeture et log audit
- Retourne `true` (validé) ou `false`/`null` (annulé ou bloqué)

### 3.2 `AuthService.validateSupervisorPin(String pin)`

Logique : chercher dans `utilisateurs` un user avec `role IN (chefAgence, directeur, admin)` ET `pin_code == hash(pin)`. Si l'institution n'utilise pas de PIN, fallback sur la vérification du mot de passe.

### 3.3 Intégration dans le formulaire de déblocage

Dans `loan_request_form_dialog.dart` (ou `loan_detail_dialog.dart`) → méthode `_debloquer()` :
```dart
if (montant > config.seuilValidationPinFCFA) {
  final ok = await showDialog<bool>(context: context, builder: (_) => const PinValidationDialog());
  if (ok != true) return; // Annulé ou PIN incorrect
}
// Procéder au déblocage
```

---

## 4. Comptes DAT — Blocage et pénalités

### 4.1 Modifications du modèle `SavingsAccount`

Ajouter dans `lib/models/savings_account_model.dart` :
```dart
final DateTime? dateEcheanceTerme;
final double? tauxPenaliteRuptureAnt; // % des intérêts acquis
```

Migration SQLite (`oldVersion < 30`) :
```sql
ALTER TABLE comptes_epargne ADD COLUMN date_echeance_terme TEXT;
ALTER TABLE comptes_epargne ADD COLUMN taux_penalite_rupture_ant REAL;
```

### 4.2 Widget `BreakDATDialog`

Créer `lib/screens/epargne/break_dat_dialog.dart` :
- Afficher date d'échéance, intérêts acquis, pénalité calculée
- Bouton « Confirmer avec PIN superviseur » → ouvre `PinValidationDialog`
- Bouton « Annuler »

### 4.3 Logique dans `SavingsOperationDialog`

```dart
// Dans _submit() avant de procéder au retrait :
if (compte.savingsCategory == SavingsCategory.bloquee) {
  final echeance = compte.dateEcheanceTerme;
  if (echeance != null && DateTime.now().isBefore(echeance)) {
    final ok = await showDialog<bool>(context: context, builder: (_) => BreakDATDialog(account: compte));
    if (ok != true) return;
    // Appliquer la pénalité avant le retrait
    final penalite = compte.interetsAcquis * (compte.tauxPenaliteRuptureAnt ?? 0) / 100;
    // Soustraire pénalité du montant disponible
  }
}
```

---

## 5. Création automatique du compte épargne obligatoire

### 5.1 Flow post-création client

Dans `ClientFormDialog._submit()`, après l'insertion du client :
```dart
// Chercher le produit épargne obligatoire
final produits = await DatabaseService().getProduits(type: ProductType.epargne);
final obligatoire = produits.firstWhereOrNull(
  (p) => p.savingsCategory == SavingsCategory.obligatoire,
);
if (obligatoire != null) {
  final numeroCompte = 'CEP-${newClientId}-${DateFormat('yyyyMM').format(DateTime.now())}';
  await DatabaseService().insertSavingsAccount(SavingsAccount(
    clientId: newClientId,
    produitId: obligatoire.id!,
    numeroCompte: numeroCompte,
    statut: SavingsAccountStatus.actif,
    dateOuverture: DateTime.now(),
    tauxInteretApplique: obligatoire.tauxInteret,
  ));
  // SnackBar informatif
}
```

---

## 6. Upload KYC

### 6.1 Dépendance

Ajouter dans `pubspec.yaml` si absent :
```yaml
file_picker: ^8.1.6
```

### 6.2 Table SQLite `documents_clients`

Migration (`oldVersion < 30`) :
```sql
CREATE TABLE IF NOT EXISTS documents_clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL,
  type_document TEXT NOT NULL,   -- 'CNI', 'PASSEPORT', 'JUSTIF_DOMICILE', 'AUTRE'
  nom_fichier TEXT NOT NULL,
  chemin_local TEXT NOT NULL,
  date_ajout TEXT NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);
```

### 6.3 Section KYC dans `ClientFormDialog`

Nouvelle étape (ou section dans l'étape existante) :
- `ListView` des fichiers joints avec nom + taille + icône type + bouton suppression
- Bouton « + Ajouter un document » → `FilePicker.platform.pickFiles()`
- Validation : max 5 fichiers, max 10 Mo par fichier, extensions `['pdf','jpg','jpeg','png']`

---

## 7. Liaison groupe solidaire

### 7.1 Champ groupe dans `ClientFormDialog`

```dart
DropdownButtonFormField<int?>(
  value: _selectedGroupeId,
  items: [
    const DropdownMenuItem(value: null, child: Text('Aucun groupe')),
    ...groupes.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nom))),
  ],
  onChanged: (val) => setState(() => _selectedGroupeId = val),
  decoration: const InputDecoration(labelText: 'Groupe solidaire (optionnel)'),
)
```

### 7.2 Insertion dans `membres_groupe`

```dart
if (_selectedGroupeId != null) {
  await DatabaseService().addMembreGroupe(groupeId: _selectedGroupeId!, clientId: newClientId);
}
```

---

## 8. Migration SQLite version 30

Toutes les modifications de schéma Phase 4 sont regroupées dans un seul bloc `if (oldVersion < 30)` :

```sql
-- Produits
ALTER TABLE produits_financiers ADD COLUMN taux_assurance REAL;
ALTER TABLE produits_financiers ADD COLUMN duree_max_differe_capital_mois INTEGER;

-- Prêts
ALTER TABLE prets ADD COLUMN mois_differe_capital INTEGER DEFAULT 0;

-- Comptes épargne
ALTER TABLE comptes_epargne ADD COLUMN date_echeance_terme TEXT;
ALTER TABLE comptes_epargne ADD COLUMN taux_penalite_rupture_ant REAL;

-- Documents KYC
CREATE TABLE IF NOT EXISTS documents_clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL,
  type_document TEXT NOT NULL,
  nom_fichier TEXT NOT NULL,
  chemin_local TEXT NOT NULL,
  date_ajout TEXT NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);
```

---

## 9. Tests

| Test | Type | Fichier |
|------|------|---------|
| `calculerTEG()` — sans assurance ni frais → TEG = taux nominal | Unitaire | `test/utils/loan_calculator_test.dart` |
| `calculerTEG()` — avec assurance 0.5% et frais 10k → TEG correct | Unitaire | idem |
| **Propriété** : TEG ≥ tauxNominal pour tout montant/durée positifs | Property | idem |
| Différé : 2 mois → capital_du = 0 sur les 2 premières échéances | Unitaire | `test/services/loan_schedule_differe_test.dart` |
| Différé : total des capitaux du = montant initial | Property | idem |
| DAT : retrait avant terme → `BreakDATDialog` affiché | Widget | `test/screens/savings_operation_dat_test.dart` |
| Compte épargne obligatoire créé après création client | Unitaire | `test/screens/client_form_savings_test.dart` |
| Upload KYC : fichier > 10 Mo → refusé | Unitaire | `test/screens/client_form_kyc_test.dart` |
