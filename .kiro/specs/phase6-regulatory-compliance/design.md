# Document de Conception — Phase 6 : Conformité Réglementaire

## Vue d'ensemble

La Phase 6 structure la conformité réglementaire en trois vagues :

1. **Vague 1 (fondations)** — Plan comptable asset, RCSSFD preset, export balance, PDF branding
2. **Vague 2 (rapports)** — CustomReportPage SQL, exports BCEAO, relevés épargne
3. **Vague 3 (contrats & archivage)** — Contrats PDF avancés, scan contrat signé

**Migration cible :** SQLite v31 → v32

---

## 1. Plans comptables (assets)

### 1.1 Fichiers assets

| Fichier | Usage |
|---------|-------|
| `lib/assets/docs/plan_comptable_syscohada.txt` | Plan OHADA complet (~1400 comptes) |
| `lib/assets/docs/Plan des Comptes RCSSFD.txt` | Plan SFD UMOA (~170 comptes clés) |

### 1.2 `PlanComptableLoader`

```dart
class PlanComptableLoader {
  static Future<String> load(PlanComptableType type);
}
```

### 1.3 `ChartOfAccountsService` refactoré

- Suppression du CSV inline
- `insertFullChartOfAccounts(db, {type})` charge via `rootBundle`
- `reseedChartOfAccounts(db, type)` : DELETE + INSERT

### 1.4 Presets comptables automatiques

| Compte | SYSCOHADA (legacy) | RCSSFD (défaut neuf) |
|--------|-------------------|----------------------|
| Prêts | 271 | 501 |
| Caisse | 571 | 530 |
| Dépôts épargne | 1651 | 521 |
| Intérêts prêts | 7712 | 701 |
| Pénalités | 7078 | 703 |
| Intérêts épargne | 6741 | 602 |

Aligné sur `backend/app/services/accounting_service.py`.

### 1.5 Configuration

```sql
-- configurations
key = 'plan_comptable_type', value = 'rcssfd' | 'syscohada'
```

Fresh install : `rcssfd` via `_seedPhase6Defaults()`.

**Bug 1 — Fix `_applyPhase6Schema()` (migration v31→v32) :**

L'implémentation initiale insérait `syscohada` sans reseeder `comptes_comptables`. Le fix corrige `_applyPhase6Schema()` pour :
1. Vérifier si `plan_comptable_type` est absent
2. Si absent : appeler `reseedChartOfAccounts(db, rcssfd)` + insérer `plan_comptable_type = 'rcssfd'`
3. Si présent : ne rien faire (idempotence)

```dart
Future<void> _applyPhase6Schema(Database db) async {
  final existing = await db.query(
    'configurations',
    where: 'key = ?',
    whereArgs: ['plan_comptable_type'],
  );
  if (existing.isEmpty) {
    // Base migrée sans plan défini → reseed RCSSFD
    await ChartOfAccountsService().reseedChartOfAccounts(
      db,
      PlanComptableType.rcssfd,
    );
    await db.insert('configurations', {
      'key': 'plan_comptable_type',
      'value': PlanComptableType.rcssfd.key,
    });
  }
  // Si déjà présent : conserver tel quel (idempotent)
}
```

---

## 1-BIS. Correction encodage assets (Bug 2)

### Cause racine

Les deux fichiers assets ont été sauvegardés en Windows-1252 mais Flutter les lit comme UTF-8 via `rootBundle.loadString()`. Cela produit un double-encoding silencieux : `é` (0xE9 en Latin-1) devient `Ã©` (0xC3 0xA9 en UTF-8 mal interprété).

### Fix

Réécrire les deux fichiers en UTF-8 sans BOM :
- `lib/assets/docs/plan_comptable_syscohada.txt` : remplacer toutes les séquences `Ã©→é`, `Ã →à`, `Ã¨→è`, `â€™→'`, `Ã®→î`, `Ã´→ô`, `Ã¹→ù`, `Ã»→û`, `Ã§→ç`, `Å"→œ`
- `lib/assets/docs/Plan des Comptes RCSSFD.txt` : remplacer tous les `?` de substitution Unicode par les caractères accentués corrects selon le contexte lexical

### Validation optionnelle dans `PlanParser`

```dart
static List<AccountingAccount> parse(String content) {
  // Détection préventive de double-encoding
  if (content.contains('Ã') || content.contains('â€')) {
    debugPrint('[PlanParser] AVERTISSEMENT: Caractères suspects détectés — '
        'fichier probablement encodé en Windows-1252 lu comme UTF-8.');
  }
  // ... reste du parsing inchangé
}
```

---

## 2. Export balance (`RegulatoryExportService`)

### Format CSV

```
SIGMA Micro-Finance — Balance Générale (RCSSFD)
Institution;{raison_sociale}
N° agrément;{numero_agrement}
IFU;{numero_fiscal}
Période;{date_debut} — {date_fin}
Date export;{now}

N° Compte;Libellé;Total Débit;Total Crédit;Solde Débiteur;Solde Créditeur
...
TOTAUX;;...
```

- Encodage : UTF-8 avec BOM (`\uFEFF`)
- Séparateur : `;` (Excel FR)
- Montants : entiers FCFA, virgule décimale

---

## 3. PDF institutionnels (`InstitutionPdfBranding`)

```dart
class InstitutionPdfBranding {
  final LegalInformation legal;
  List<pw.Widget> buildHeader();
  pw.Widget buildFooter({String? generatedAt});
}
```

Source : table `configurations` via `DatabaseService.getLegalInformation()`.

Phase 6 vague 1 : branché sur `exportLoanContract()`. Vague 2 : généraliser à PAR, relevés, balance PDF.

---

## 4. Rapports dynamiques (vague 2)

### 4.1 `CustomReportQueryService`

Map indicateur → requête SQL paramétrée :

| Indicateur | Requête |
|------------|---------|
| `outstanding_volume` | `SUM(capital_restant) FROM prets WHERE statut='Actif'` |
| `par_30` | Calcul PAR depuis `echeanciers` |
| `savings_collected` | `SUM(montant) FROM transactions_epargne WHERE type='DEPOT'` |

### 4.2 Sécurité

- Whitelist d'indicateurs (pas de SQL libre utilisateur en v1)
- Paramètres bindés (dates, agence)

---

## 5. Exports BCEAO (vague 2)

### `BceaoExportService`

Fichiers plats dans `{appDocDir}/exports/bceao/` :

- `encours_credit_{date}.csv`
- `depots_{date}.csv`
- `par_{date}.csv`

Format : séparateur `|`, en-têtes normalisés instruction BCEAO.

---

## 6. Relevés épargne (vague 2)

### `SavingsStatementService`

- `generateMonthlyStatement(accountId, month, year)` → PDF
- Job optionnel le 1er du mois (complément `monthly_interests.py`)

---

## 7. Contrats & archivage (vague 3)

### Migration v33 (prévue)

```sql
ALTER TABLE prets ADD COLUMN contrat_scan_path TEXT;
ALTER TABLE prets ADD COLUMN contrat_scan_base64 TEXT;
```

### `LoanContractTemplateService`

- Template PDF avec placeholders `{client_nom}`, `{montant}`, `{teg}`, `{echeancier_table}`
- Stockage template en `configurations` ou asset

---

## Fichiers créés / modifiés (vague 1)

| Fichier | Action |
|---------|--------|
| `lib/assets/docs/plan_comptable_syscohada.txt` | Créé (extrait CSV inline) |
| `lib/assets/docs/Plan des Comptes RCSSFD.txt` | Créé |
| `lib/models/plan_comptable_type.dart` | Créé |
| `lib/core/services/plan_comptable_loader.dart` | Créé |
| `lib/core/services/regulatory_export_service.dart` | Créé |
| `lib/core/services/institution_pdf_branding.dart` | Créé |
| `lib/core/services/chart_of_accounts_service.dart` | Refactoré |
| `lib/models/accounting_config_model.dart` | `rcssfdDefault()` |
| `lib/core/services/database_service.dart` | v32, switch plan |
| `lib/screens/comptabilite/balance_generale_page.dart` | Export branché |
| `lib/screens/configuration/institution_configuration_page.dart` | Sélecteur plan |
| `lib/core/services/pdf_export_service.dart` | Branding dynamique |
| `pubspec.yaml` | Assets déclarés |
