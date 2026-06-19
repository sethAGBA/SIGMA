# Requirements Document

> **Titre :** Phase 2 — Remplacement des valeurs hardcodées — SIGMA Micro-Finance

## Introduction

L'application SIGMA Micro-Finance contient plusieurs valeurs statiques (mocks) introduites pendant le développement initial et qui doivent être remplacées par des données réelles issues de la session utilisateur (`AuthService`) et de la base de données SQLite locale. Ce document couvre le Dashboard, la Caisse, les Remboursements, la Comptabilité et le Reporting.

## Glossary

- **AuthService** : Singleton Flutter gérant la session utilisateur courante. Expose `currentUsername`, `currentUserId`, `currentRole`, `userInitials`.
- **DatabaseService** : Service d'accès à la base de données SQLite locale.
- **currentUsername** : Propriété de `AuthService` retournant `_currentUser?.username ?? ''`.
- **CashClosing** : Modèle de données représentant une clôture journalière de caisse (`agentCloture`, `soldeInitial`).
- **agentCollecteur** : Champ du modèle `Repayment` identifiant l'agent ayant encaissé le paiement.
- **agentSaisie** : Champ du modèle `EcritureComptable` identifiant l'agent ayant saisi l'écriture.
- **loanId** : Identifiant entier d'un prêt en souffrance, passé en paramètre à `DelinquentLoanDetailPage`.

## Requirements

### Requirement 1: Message de bienvenue dynamique sur le Dashboard

**User Story:** En tant qu'utilisateur connecté, je veux voir mon nom affiché dans le message de bienvenue du dashboard, afin de confirmer que la session est bien la mienne.

#### Acceptance Criteria

1. WHEN le Dashboard est affiché, THE Dashboard SHALL afficher le message de bienvenue sous la forme `'${salutation}, ${AuthService().currentUsername} 👋'` où `salutation` dépend de l'heure courante.
2. IF `AuthService().currentUsername` est vide, THEN THE Dashboard SHALL afficher `'Utilisateur'` comme nom de repli.
3. WHEN le nom affiché est calculé, THE Dashboard SHALL utiliser `AuthService().currentUser?.username` comme source unique de vérité.

---

### Requirement 2: Statistiques agrégées en bas du Dashboard

**User Story:** En tant qu'agent, je veux que la barre de statistiques du dashboard affiche l'encours total réel et la collecte du jour réelle, afin de piloter mon activité avec des données exactes.

#### Acceptance Criteria

1. WHEN le Dashboard est chargé, THE Dashboard SHALL appeler `DatabaseService().getHomeDashboardData()` pour obtenir les données de la BottomStatsBar.
2. WHEN le serveur FastAPI est disponible, THE Dashboard SHALL utiliser les données KPI renvoyées par l'API pour `encours_total` et les données locales pour la collecte du jour.
3. IF le serveur FastAPI est indisponible, THEN THE Dashboard SHALL utiliser uniquement les données locales de `DatabaseService().getHomeDashboardData()`.
4. WHEN les KPIs sont calculés, THE Dashboard SHALL afficher l'encours total et le montant de collecte du jour dans la BottomStatsBar.

---

### Requirement 3: Bouton FAB du Dashboard avec navigation réelle

**User Story:** En tant qu'agent, je veux que le bouton FAB du dashboard propose les actions « Nouveau client », « Nouveau prêt » et « Opération caisse », afin d'accéder rapidement aux flux métier principaux.

#### Acceptance Criteria

1. WHEN l'utilisateur appuie sur le bouton FAB du Dashboard, THE Dashboard SHALL afficher un menu contextuel proposant les options « Nouveau client », « Nouveau prêt » et « Opération caisse ».
2. WHEN l'utilisateur sélectionne « Nouveau client », THE Dashboard SHALL naviguer vers la page de création de client.
3. WHEN l'utilisateur sélectionne « Nouveau prêt », THE Dashboard SHALL naviguer vers la page de création de prêt.
4. WHEN l'utilisateur sélectionne « Opération caisse », THE Dashboard SHALL naviguer vers la page de saisie d'une opération de caisse.
5. WHERE l'utilisateur n'a pas les permissions requises, THE Dashboard SHALL désactiver l'option correspondante dans le menu FAB.

---

### Requirement 4: Agent de clôture de caisse dynamique

**User Story:** En tant qu'agent de caisse, je veux que mon identifiant réel soit enregistré lors de la clôture journalière, afin que le journal de clôture soit traçable et auditable.

#### Acceptance Criteria

1. WHEN l'agent valide la clôture dans CashClosingDialog, THE CashClosingDialog SHALL remplir le champ `agentCloture` du modèle CashClosing avec `AuthService().currentUsername`.
2. IF `AuthService().currentUsername` est vide au moment de la clôture, THEN THE CashClosingDialog SHALL refuser la soumission et afficher le message « Aucun utilisateur connecté. Veuillez vous reconnecter. ».

---

### Requirement 5: Report du solde de la veille dans la clôture de caisse

**User Story:** En tant qu'agent de caisse, je veux que le solde initial de la clôture corresponde au solde physique constaté lors de la dernière clôture, afin que les arrêtés de caisse soient continus.

#### Acceptance Criteria

1. WHEN CashClosingDialog s'initialise, THE CashClosingDialog SHALL interroger DatabaseService pour obtenir la dernière clôture enregistrée dans la table `clotures_caisse`.
2. WHEN une clôture précédente existe, THE CashClosingDialog SHALL remplir le champ `soldeInitial` du modèle CashClosing avec le `soldePhysique` de cette clôture.
3. IF aucune clôture précédente n'existe, THEN THE CashClosingDialog SHALL utiliser `0.0` comme `soldeInitial`.

---

### Requirement 6: Agent collecteur dynamique dans les remboursements

**User Story:** En tant qu'agent de crédit, je veux que mon nom soit enregistré comme agent collecteur lors de chaque encaissement, afin que l'historique de collecte soit traçable.

#### Acceptance Criteria

1. WHEN le RepaymentFormDialog soumet un paiement, THE RepaymentFormDialog SHALL remplir le champ `agentCollecteur` du modèle Repayment avec `AuthService().currentUsername`.
2. IF `AuthService().currentUsername` est vide, THEN THE RepaymentFormDialog SHALL utiliser `'Inconnu'` comme valeur de repli pour `agentCollecteur`.

---

### Requirement 7: En-tête de collecte dynamique dans DailyCollectionPage

**User Story:** En tant qu'agent de crédit, je veux voir mon nom affiché dans l'en-tête de la page de collecte journalière, afin de confirmer que je travaille sous ma propre session.

#### Acceptance Criteria

1. WHEN la DailyCollectionPage est affichée, THE DailyCollectionPage SHALL afficher `'COLLECTE DU JOUR — Agent : ${AuthService().currentUsername}'` dans l'en-tête.
2. IF `AuthService().currentUsername` est vide, THEN THE DailyCollectionPage SHALL afficher `'COLLECTE DU JOUR — Agent : Inconnu'` dans l'en-tête.

---

### Requirement 8: Filtre « Retard » actif dans DailyCollectionPage

**User Story:** En tant qu'agent de crédit, je veux activer le filtre « Filtrer par retard » sur la liste des échéances, afin de prioriser les clients en impayé.

#### Acceptance Criteria

1. WHEN l'utilisateur appuie sur « Filtrer par retard » dans la DailyCollectionPage, THE DailyCollectionPage SHALL basculer le filtre retard et recharger la liste.
2. WHILE le filtre retard est actif, THE DailyCollectionPage SHALL afficher uniquement les échéances dont `joursRetard > 0`.
3. WHEN le filtre est désactivé, THE DailyCollectionPage SHALL afficher toutes les échéances en attente.
4. WHEN le filtre retard est actif, THE DailyCollectionPage SHALL indiquer visuellement son état actif via une couleur ou icône différente.

---

### Requirement 9: Agent de saisie comptable dynamique

**User Story:** En tant qu'agent comptable, je veux que mon nom soit enregistré comme agent de saisie dans chaque écriture comptable, afin de garantir la traçabilité des saisies.

#### Acceptance Criteria

1. WHEN la SaisieComptablePage affiche le champ « Agent de saisie », THE SaisieComptablePage SHALL afficher `AuthService().currentUsername` dans ce champ en lecture seule.
2. WHEN la SaisieComptablePage valide et persiste l'écriture, THE SaisieComptablePage SHALL remplir le champ `agentSaisie` de EcritureComptable avec `AuthService().currentUsername`.
3. IF `AuthService().currentUsername` est vide, THEN THE SaisieComptablePage SHALL utiliser `'Inconnu'` comme valeur de repli pour `agentSaisie`.

---

### Requirement 10: Navigation dynamique vers le détail d'un prêt en souffrance

**User Story:** En tant qu'agent de recouvrement, je veux que le tap sur un prêt en souffrance ouvre le détail du prêt correspondant, afin de consulter les informations spécifiques à ce dossier.

#### Acceptance Criteria

1. WHEN l'utilisateur appuie sur un prêt dans la liste DelinquentLoansListPage, THE DelinquentLoansListPage SHALL passer l'identifiant réel du prêt (`loan['id']`) au constructeur de DelinquentLoanDetailPage.
2. THE DelinquentLoanDetailPage SHALL recevoir un `loanId` obligatoire non nul de type `int`.
3. WHEN DelinquentLoanDetailPage charge les données, THE DelinquentLoanDetailPage SHALL appeler `DatabaseService().getDelinquentLoanDetails(loanId)` avec le `loanId` reçu en paramètre.
4. IF `loanId` ne correspond à aucun prêt dans la base, THEN THE DelinquentLoanDetailPage SHALL afficher le message « Dossier introuvable ».
