# Requirements Document

> **Titre :** Phase 2 — Corrections UI & Données Réelles — SIGMA Micro-Finance

## Introduction

La Phase 2 élimine les dernières valeurs simulées et les actions non implémentées identifiées lors de l'audit du code. Elle couvre cinq zones : la `BottomStatsBar` (données hardcodées), l'export CSV clients (simulé), le SMS groupé (simulé), les métriques des groupes solidaires (placeholders) et le bouton Scan de la `SaisieComptablePage` (non fonctionnel). Ces corrections ne nécessitent pas de nouvelle architecture : elles branchent les sources de données existantes (`DatabaseService`, `GroupApiService`, `file_picker`) sur les widgets concernés.

## Glossary

- **BottomStatsBar** : Barre persistante en bas de la `MainLayout` affichant l'encours total, la collecte du jour et le PAR > 30j.
- **DashboardNotifier** : `ChangeNotifier` Provider gérant le cache des données du Dashboard (`DashboardData`).
- **DashboardData** : Modèle retourné par `DatabaseService().getHomeDashboardData()` contenant `encours`, `collecteJour`, `par30`.
- **GroupApiService** : Service singleton fournissant `getGroupActiveLoansTotal(int groupId)` et `getGroupRepaymentRate(int groupId)`.
- **DatabaseService** : Service d'accès à SQLite local. Expose `getHomeDashboardData()`, `getGroupLoans()`, `getGroupRepayments()`.
- **ClientApiService** : Service exposant `searchClients()` et `getGroupMembers()`.
- **file_picker** : Package Flutter `file_picker: ^8.x` pour ouvrir un sélecteur de fichier natif.
- **SmsSendingPage** : Écran existant `lib/screens/communications/sms_sending_page.dart` permettant l'envoi de SMS à un client ciblé.
- **BatchActionBar** : Barre d'actions groupées dans `ClientListPage` apparaissant lors de la sélection multiple.

---

## Requirements

### Requirement 1: BottomStatsBar branchée sur des données réelles

**User Story:** En tant qu'utilisateur de l'application, je veux que la barre de statistiques en bas de l'écran affiche l'encours total réel, la collecte du jour réelle et le PAR > 30j réel, afin de prendre des décisions basées sur des données exactes.

#### Acceptance Criteria

1. WHEN l'application démarre, THE `BottomStatsBar` SHALL charger ses données via `DashboardNotifier` (déjà initialisé dans `main.dart`).
2. WHEN `DashboardNotifier` expose `cachedData`, THE `BottomStatsBar` SHALL afficher `cachedData.encours` formaté en FCFA, `cachedData.collecteJour` formaté en FCFA, et `cachedData.par30` formaté en pourcentage.
3. IF `cachedData` est `null` (données non encore chargées), THEN THE `BottomStatsBar` SHALL afficher des indicateurs de chargement (`--` ou `CircularProgressIndicator` de petite taille) à la place des valeurs.
4. WHEN le serveur FastAPI est disponible, THE `BottomStatsBar` SHALL utiliser `encours_total` issu du backend pour `encours` et les données locales SQLite pour `collecteJour` et `par30`.
5. IF le serveur FastAPI est indisponible, THEN THE `BottomStatsBar` SHALL utiliser exclusivement les données de `DatabaseService().getHomeDashboardData()` pour les trois indicateurs.
6. WHEN les données sont mises à jour via `DashboardNotifier.refresh()`, THE `BottomStatsBar` SHALL se mettre à jour de façon réactive sans nécessiter de rechargement de la page.

---

### Requirement 2: Export CSV réel depuis la liste des clients sélectionnés

**User Story:** En tant qu'agent ou directeur, je veux exporter la liste des clients sélectionnés en fichier CSV, afin d'analyser les données dans un tableur externe.

#### Acceptance Criteria

1. WHEN l'utilisateur sélectionne un ou plusieurs clients et appuie sur « Exporter » dans la `BatchActionBar`, THE `ClientListPage` SHALL générer un fichier CSV contenant les colonnes : `N° Client`, `Nom`, `Prénoms`, `Téléphone`, `Risque`, `Score`, `Statut`.
2. WHEN le CSV est généré, THE `ClientListPage` SHALL ouvrir le sélecteur de sauvegarde natif via `FilePicker.platform.saveFile()` avec le nom de fichier par défaut `clients_export_AAAA-MM-JJ.csv` et le filtre `.csv`.
3. WHEN le fichier est sauvegardé avec succès, THE `ClientListPage` SHALL afficher un `SnackBar` de confirmation : `'Export réussi : N clients exportés'`.
4. IF l'utilisateur annule le sélecteur de fichier, THEN THE `ClientListPage` SHALL ne rien faire (pas d'erreur affichée).
5. IF une erreur survient lors de la génération ou sauvegarde, THEN THE `ClientListPage` SHALL afficher un `SnackBar` d'erreur avec le message `'Erreur lors de l\'export : [message]'`.
6. WHEN le CSV est généré, THE `ClientListPage` SHALL encoder le fichier en UTF-8 avec BOM pour assurer la compatibilité Excel.

---

### Requirement 3: SMS groupé naviguant vers SmsSendingPage avec pré-sélection

**User Story:** En tant qu'agent, je veux envoyer un SMS à un ou plusieurs clients sélectionnés depuis la liste clients, afin de les contacter rapidement sans changer manuellement d'écran.

#### Acceptance Criteria

1. WHEN l'utilisateur sélectionne un ou plusieurs clients et appuie sur « SMS » dans la `BatchActionBar`, THE `ClientListPage` SHALL naviguer vers `SmsSendingPage` en passant la liste des IDs de clients sélectionnés.
2. WHEN `SmsSendingPage` reçoit une liste de clients pré-sélectionnés contenant exactement 1 client, THE `SmsSendingPage` SHALL pré-remplir le champ destinataire avec ce client.
3. WHEN `SmsSendingPage` reçoit une liste de clients pré-sélectionnés contenant plus de 1 client, THE `SmsSendingPage` SHALL afficher un mode envoi groupé listant tous les destinataires sélectionnés.
4. IF `SmsSendingPage` est ouverte sans pré-sélection (navigation directe depuis la sidebar), THEN THE `SmsSendingPage` SHALL fonctionner normalement sans pré-remplissage.
5. WHEN le mode envoi groupé est actif, THE `SmsSendingPage` SHALL envoyer le même message à chaque client de la liste et afficher un résumé (`N envoyés / N total`).

---

### Requirement 4: Encours total dynamique dans les cartes de groupes solidaires

**User Story:** En tant qu'agent, je veux que la carte d'un groupe solidaire affiche l'encours total réel (somme des prêts actifs des membres), afin d'évaluer rapidement l'exposition financière du groupe.

#### Acceptance Criteria

1. WHEN la `GroupListPage` affiche une carte de groupe, THE `GroupListPage` SHALL appeler `DatabaseService().getGroupActiveLoansTotal(groupId)` pour obtenir la somme des capitaux restants dus de tous les prêts actifs des membres du groupe.
2. WHEN la valeur d'encours est disponible, THE `GroupListPage` SHALL l'afficher dans la métrique `ENCOURS` de la carte, formatée en FCFA (ex : `'1.2 M FCFA'` pour les montants ≥ 1 000 000, sinon `'350 000 FCFA'`).
3. IF aucun prêt actif n'existe pour le groupe, THEN THE `GroupListPage` SHALL afficher `'0 FCFA'` dans la métrique `ENCOURS`.
4. WHEN les cartes de groupes sont chargées, THE `GroupListPage` SHALL charger les encours en parallèle (via `Future.wait`) pour ne pas bloquer l'affichage de la grille.

---

### Requirement 5: Taux de remboursement dynamique dans les cartes de groupes solidaires

**User Story:** En tant qu'agent, je veux que la carte d'un groupe solidaire affiche le taux de remboursement réel du groupe, afin d'identifier les groupes à risque.

#### Acceptance Criteria

1. WHEN la `GroupListPage` affiche une carte de groupe, THE `GroupListPage` SHALL calculer le taux de remboursement via `DatabaseService().getGroupRepaymentRate(groupId)` : `(montant_total_payé / montant_total_dû) × 100`.
2. WHEN le taux de remboursement est disponible, THE `GroupListPage` SHALL l'afficher dans la métrique `PERF.` de la carte, formaté en pourcentage entier (ex : `'97%'`).
3. WHEN le taux de remboursement est ≥ 90%, THE `GroupListPage` SHALL afficher la valeur en couleur `AppColors.success` (vert).
4. WHEN le taux de remboursement est entre 70% et 89%, THE `GroupListPage` SHALL afficher la valeur en couleur `AppColors.warning` (orange).
5. WHEN le taux de remboursement est < 70%, THE `GroupListPage` SHALL afficher la valeur en couleur `AppColors.error` (rouge).
6. IF aucun prêt n'existe pour le groupe, THEN THE `GroupListPage` SHALL afficher `'N/A'` pour la performance.

---

### Requirement 6: Métriques dynamiques dans le détail de groupe (onglet Performance)

**User Story:** En tant que chef d'agence, je veux que l'onglet Performance du dialogue de détail d'un groupe affiche des indicateurs calculés depuis les données réelles, afin de prendre des décisions de gestion basées sur des faits.

#### Acceptance Criteria

1. WHEN l'onglet Performance de `GroupDetailDialog` est affiché, THE `GroupDetailDialog` SHALL charger `getGroupActiveLoansTotal(groupId)`, `getGroupRepaymentRate(groupId)` et `getGroupMembers(groupId)` en parallèle.
2. WHEN les données sont disponibles, THE `GroupDetailDialog` SHALL afficher : `Encours total` (somme capitaux restants), `Taux de remboursement` (pourcentage), `Nombre de prêts actifs` (count), `Durée d'ancienneté` (en mois depuis `dateCreation`).
3. WHEN l'onglet Prêts collectifs de `GroupDetailDialog` est affiché, THE `GroupDetailDialog` SHALL afficher la liste des prêts actifs des membres via `DatabaseService().getGroupLoans(groupId)`.
4. IF aucune donnée n'est disponible pour un indicateur, THEN THE `GroupDetailDialog` SHALL afficher `'—'` (tiret) comme valeur de repli.

---

### Requirement 7: Bouton Scan fonctionnel dans SaisieComptablePage

**User Story:** En tant qu'agent comptable, je veux pouvoir scanner ou importer une pièce justificative directement depuis la saisie comptable, afin d'attacher le justificatif à l'écriture sans quitter l'écran.

#### Acceptance Criteria

1. WHEN l'utilisateur appuie sur le bouton « Scan » dans `SaisieComptablePage`, THE `SaisieComptablePage` SHALL ouvrir le sélecteur de fichier via `FilePicker.platform.pickFiles()` avec les types autorisés : PDF, PNG, JPG, JPEG.
2. WHEN l'utilisateur sélectionne un fichier, THE `SaisieComptablePage` SHALL afficher le nom du fichier sélectionné sous le bouton (ex : `'📎 facture_001.pdf'`).
3. WHEN l'écriture est validée avec un fichier attaché, THE `SaisieComptablePage` SHALL stocker le chemin absolu du fichier dans le champ `piecesJointes` de `EcritureComptable` (ou un champ dédié si absent du modèle).
4. IF l'utilisateur annule le sélecteur, THEN THE `SaisieComptablePage` SHALL conserver l'état précédent sans afficher d'erreur.
5. IF l'utilisateur sélectionne un fichier de taille > 10 Mo, THEN THE `SaisieComptablePage` SHALL afficher un `SnackBar` d'avertissement : `'Fichier volumineux (> 10 Mo) — l\'import peut être lent.'` mais l'autoriser quand même.
6. WHEN un fichier est attaché, THE `SaisieComptablePage` SHALL afficher un bouton `×` permettant de supprimer la pièce jointe sélectionnée.
