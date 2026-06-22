# SIGMA Micro-Finance — Analyse du Projet

## Ce que c'est

Une application Flutter de gestion de micro-finance complète, ciblant à la fois le desktop (Windows/Linux/macOS) et le mobile. Le domaine est la gestion de crédit, épargne, caisse et comptabilité pour des IMF (Institutions de Micro-Finance) en zone UEMOA/OHADA.

---

## Architecture de déploiement cible

**Mode : Client lourd Flutter sur réseau local (LAN)**

```
┌─────────────────────────────────────────────────────────┐
│                   PC SERVEUR LOCAL                      │
│  ┌─────────────────┐     ┌──────────────────────────┐  │
│  │  Backend API    │     │  Base de données          │  │
│  │  (REST/HTTP)    │◄────│  PostgreSQL (centrale)    │  │
│  └────────┬────────┘     └──────────────────────────┘  │
│           │ Réseau local (LAN/WiFi)                     │
└───────────┼─────────────────────────────────────────────┘
            │
     ┌──────┴──────────────────────────┐
     │                                 │
┌────▼──────────┐             ┌────────▼──────────┐
│  App Flutter  │             │  App Flutter       │
│  PC Caissier  │             │  Tablette Agent    │
│  (Client)     │             │  Terrain (Client)  │
│               │             │                    │
│  Cache SQLite │             │  Cache SQLite      │
│  (offline)    │             │  (offline)         │
└───────────────┘             └────────────────────┘
```

**Implications architecturales :**

| Élément | Situation actuelle | Cible |
|---|---|---|
| **Base de données** | SQLite local par poste | PostgreSQL centralisé sur le serveur |
| **Communication** | Aucune (tout local) | API REST HTTP sur le LAN |
| **Authentification** | Inexistante | Centralisée côté serveur (tokens JWT) |
| **RBAC** | Inexistant | Géré côté serveur + appliqué dans l'UI |
| **Offline** | Permanent (tout est local) | Cache SQLite local + sync avec le serveur |
| **Backend** | Aucun | À créer : Dart `shelf`/`dart_frog`, ou Python FastAPI |

**Stack backend retenue : Python FastAPI + PostgreSQL**

| Composant | Technologie | Rôle |
|---|---|---|
| **API REST** | Python FastAPI | Expose tous les endpoints (clients, prêts, auth...) |
| **Base de données** | PostgreSQL | Base centrale sur le serveur local |
| **ORM** | SQLAlchemy + Alembic | Modèles Python + migrations BDD |
| **Authentification** | JWT (`python-jose`) | Tokens de session sécurisés |
| **Jobs nocturnes** | APScheduler | Calcul pénalités, scoring, capitalisation épargne |
| **Hashage mots de passe** | passlib + bcrypt | Stockage sécurisé des passwords |
| **Serveur ASGI** | Uvicorn | Serveur de prod sur le réseau local |
| **Cache offline Flutter** | SQLite local | Données en attente de sync |

**Structure du projet backend (dossier `/backend`) :**
```
backend/
├── main.py                  # Point d'entrée FastAPI
├── requirements.txt
├── alembic/                 # Migrations BDD
├── app/
│   ├── core/
│   │   ├── config.py        # Variables d'environnement
│   │   ├── security.py      # JWT, hachage passwords
│   │   └── database.py      # Connexion PostgreSQL
│   ├── models/              # Modèles SQLAlchemy
│   ├── schemas/             # Schémas Pydantic (validation)
│   ├── routers/             # Routes par module
│   │   ├── auth.py
│   │   ├── clients.py
│   │   ├── prets.py
│   │   ├── remboursements.py
│   │   ├── epargne.py
│   │   ├── caisse.py
│   │   ├── comptabilite.py
│   │   └── ...
│   ├── services/            # Logique métier
│   │   ├── accounting_service.py   # Pont comptable automatique
│   │   ├── penalty_service.py      # Calcul pénalités
│   │   └── scoring_service.py      # Score crédit dynamique
│   └── jobs/                # Jobs planifiés (APScheduler)
│       ├── daily_penalties.py
│       ├── monthly_interests.py
│       └── nightly_scoring.py
└── tests/
```

---

## Points forts

**Architecture UI solide** : 15 modules identifiés, tous avec leurs écrans. La structure `lib/` est bien organisée (core/models/screens/widgets) et montre une vraie réflexion sur la séparation des responsabilités.

**Modèle de données riche** : 30+ modèles Dart couvrant la quasi-totalité du domaine métier (prêts, échéanciers, épargne, comptabilité, audit...). C'est clairement du travail sérieux.

**Stack pertinente** : `sqflite` + `sqflite_common_ffi` pour le support multi-plateforme, `fl_chart` pour les graphiques, `pdf`/`printing` pour les exports — les bons outils pour le contexte offline-first.

**Documentation existante** : L'`audit_fonctionnel.md` et le `GEMINI.md` montrent que le projet est bien documenté et que les lacunes sont déjà identifiées avec précision.

---

## Dette technique (par criticité)

### 🔴 Bloquant en production

| Élément | Description |
|---|---|
| ~~**Pas d'écran de login**~~ | ✅ `LoginPage` implémentée (`lib/screens/auth/login_page.dart`) |
| ~~**Pas de RBAC**~~ | ✅ Sidebar RBAC dynamique — masquage modules par rôle via `canAccessModule()` dans `AuthService` |
| ~~**SQLite non chiffré**~~ | ⚠️ `KeyDerivationService` + `sqflite_sqlcipher` intégrés ; chiffrement actif Android/iOS. Sur desktop (`sqflite_common_ffi`), SQLCipher non supporté — avertissement UI affiché. Recommandation : FileVault/BitLocker au niveau système. |

### 🟠 Fonctionnel mais incomplet

| Élément | Description |
|---|---|
| ~~**Dashboard avec mocks**~~ | ✅ `BottomStatsBar` branchée sur `DashboardNotifier` (encours, collecte, PAR dynamiques) |
| ~~**Pas de state management**~~ | ✅ `DashboardNotifier` avec Provider — cache transparent, refresh, `clearCache` sur logout |
| ~~**Pont comptable absent**~~ | ✅ `AutomaticAccountingService` Flutter + Python branché dans déblocage, remboursement, dépôt, retrait, provisions |
| **Migration Flutter DB→HTTP** | ⚠️ ~55-60% — clients, prêts, épargne, caisse, agences, produits, groupes, comptabilité migrés vers API ; demandes de prêt, remboursements, détail prêt, communications encore sur `DatabaseService` direct |
| **SMS groupé** | ⚠️ UI pré-sélection fonctionnelle (`SmsSendingPage` + `_isBulkMode`), mais envoi simulé (`Future.delayed` + SnackBar "Simulé") — API SMS externe non branchée |

### 🟡 Améliorations importantes

| Élément | Description |
|---|---|
| ~~**Mode offline terrain**~~ | ✅ `SyncService` + `ConnectivityMonitor` + `SyncSupervisorScreen` implémentés |
| ~~**Pénalités automatiques**~~ | ✅ `PenaltyService` + `daily_penalties.py` job à 00h05 via APScheduler |
| ~~**Plan comptable RCSSFD**~~ | ✅ Asset + preset 501/530/521, sélecteur SYSCOHADA/RCSSFD, export réglementaire `RegulatoryExportService` |
| ~~**Export BCEAO/Coban**~~ | ✅ `BceaoExportService` — 3 fichiers plats CSV (encours crédit, dépôts épargne, PAR) avec séparateur `\|` et BOM UTF-8 |
| ~~**Contrats prêt PDF**~~ | ✅ `LoanContractTemplateService` — génération PDF dynamique depuis variables SQL (client, produit, échéancier, branding institution) |
| ~~**Archivage légal contrat**~~ | ✅ Import scan (FilePicker), stockage fichier local + Base64 BDD, affiché dans `LoanDetailDialog` |
| ~~**Relevés épargne PDF**~~ | ✅ `SavingsStatementService` — génération manuelle fonctionnelle ; ❌ déclenchement automatique mensuel planifié absent |
| **APIs externes** | ❌ SMS (simulation), Mobile Money webhooks (absent), notifications push Flutter (package absent) |

---

## Feuille de route détaillée

---

### Phase 0 — Infrastructure serveur *(prérequis de tout)*
> Backend Python FastAPI + PostgreSQL sur le PC serveur local

- [x] Installer et configurer PostgreSQL sur le PC serveur *(script `install_serveur.bat` + doc ; déploiement client dépendant)*
- [x] Créer le projet backend `backend/` avec FastAPI + SQLAlchemy + Alembic *(dossier `backend/` complet, 13 routers)*
- [x] Migrer le schéma SQLite vers PostgreSQL *(10 fichiers `alembic/versions/*.py` — tables clients, prêts, épargne, caisse, comptabilité, utilisateurs...)*
- [ ] Configurer le réseau local (adresse IP fixe pour le serveur) *(documentation uniquement)*
- [x] Créer les premières routes API REST (auth, clients, prêts) *(toutes les routes existent côté serveur)*
- [ ] Adapter l'app Flutter : remplacer les appels `DatabaseService` directs → appels HTTP via `ApiService` *(~55-60% fait : clients, prêts, épargne, caisse, agences, produits, groupes, comptabilité migrés ; demandes de prêt, remboursements, détail prêt, communications encore sur SQLite direct)*
- [x] Implémenter le cache SQLite local côté Flutter (mode offline de base) *(`SyncService` + file d'attente SQLite)*

---

### Phase 1 — Sécurité *(priorité absolue)*
> Bloquer l'accès non authentifié et contextualiser chaque action

- [x] **LoginPage** : créer l'écran de connexion username/password
- [x] **AuthService** côté serveur : génération de tokens JWT + refresh token *(backend `auth.py` — `/login`, `/refresh`)*
- [x] **AuthService** côté Flutter : token JWT persisté via `flutter_secure_storage`, intercepteur HTTP 401→refresh automatique, `tryRefresh()` dans `ApiService` *(Phase 1 — complet)*
- [x] **Remplacer les 8+ valeurs hardcodées** : `'Jean'`, `'Admin'`, `'SYSTÈME'`, `'Agent Connecté'` → utilisateur de la session courante *(Phase 2 + 2b — ~95% fait)*
- [x] **Sidebar RBAC** : masquage dynamique des modules selon le rôle via `canAccessModule()` — matrice `_rbacMatrix` par `SystemRole` (AgentCredit, ChefAgence, Directeur...) *(Phase 1 — complet)*
- [x] **Timeout de session** : `Timer` global sur `GestureDetector` racine — déconnexion après X minutes d'inactivité *(`SessionManager` + `WarningDialog` implémentés)*
- [ ] Chiffrement du cache SQLite local via `sqflite_sqlcipher` *(`KeyDerivationService` + `sqflite_sqlcipher` intégrés ; actif sur mobile ; contrainte desktop `sqflite_common_ffi` irrésolue — mitigation : FileVault/BitLocker recommandé)*

---

### Phase 2 — Corrections UI immédiates *(valeurs hardcodées et simulations)*
> Éliminer tous les mocks et `SnackBar` simulés identifiés lors de l'audit du code

**Dashboard**
- [x] Brancher le nom d'utilisateur sur la salutation (`'Bonjour, Jean 👋'`)
- [x] Brancher `BottomStatsBar` sur les vraies agrégations SQL (Encours, Collecte, PAR) *(Consumer<DashboardNotifier>, formatage FCFA dynamique)*
- [x] Ajouter le bouton FAB d'actions rapides (Nouveau client, Nouveau prêt, Opération caisse)

**Clients**
- [x] Remplacer export CSV simulé → vrai export CSV depuis la liste filtrée *(FilePicker.saveFile, UTF-8 BOM, colonnes réglementaires)*
- [x] Remplacer SMS groupé simulé → navigation vers `SmsSendingPage` avec pré-sélection IDs *(⚠️ envoi encore simulé — API SMS non branchée)*

**Groupes Solidaires**
- [x] Calculer dynamiquement l'encours du groupe (`getGroupActiveLoansTotal`) *(FutureBuilder + Future.wait)*
- [x] Calculer dynamiquement la performance du groupe (`getGroupRepaymentRate`) *(couleur verte/orange/rouge selon seuils)*
- [ ] Ajouter l'interface de suivi des réunions de groupe (présence, ordre du jour, compte-rendu) *(onglet Documents dans `GroupDetailDialog` : données hardcodées statiques, bouton "Ajouter un document" vide)*
- [ ] Implémenter le mécanisme de caution solidaire : transfert de dette ou saisie automatique de l'épargne bloquée des membres en cas de défaut *(onglet Garanties : affichage statique "Aucune intervention enregistrée")*

**Caisse**
- [x] Report du solde de la veille dans la clôture (solde initial réel)
- [x] Remplacer `'Agent Connecté'` par l'utilisateur de session

**Remboursements**
- [x] Activer le filtre "Filtrer par retard" dans `DailyCollectionPage`
- [x] Brancher `agentCollecteur` sur l'utilisateur connecté

**Comptabilité**
- [x] Remplacer `'Admin'` (×2) dans `SaisieComptablePage` par l'utilisateur connecté
- [x] Remplacer le bouton "Scan" simulé par l'ouverture d'un `file_picker` *(icône `attach_file_rounded`, affichage nom fichier + bouton ×, stockage dans `pieceJointe`)*

**Reporting**
- [x] Corriger `DelinquentLoanDetailPage(loanId: 1)` — ID hardcodé → ID dynamique du prêt sélectionné

---

### Phase 3 — Logique métier centrale *(cœur fonctionnel)* ✅ 100%

**Pont comptable automatique Flutter** *(branché dans `database_service.dart`)*
- [x] `AutomaticAccountingService` Flutter — `createLoanDisbursementEntry()` appelé dans `insertLoan()`
- [x] `AutomaticAccountingService` Flutter — `createLoanRepaymentEntry()` appelé dans `insertRepayment()`
- [x] `AutomaticAccountingService` Flutter — `createSavingsDepositEntry()` / `createSavingsWithdrawalEntry()` appelés dans `insertSavingsTransaction()`
- [x] Gestion des provisions ; erreurs comptables isolées (try/catch) sans bloquer la transaction principale

**Pont comptable automatique Python backend** *(branché dans les routers)*
- [x] `AutomaticAccountingService` Python — `on_deblocage_pret()` appelé dans `prets.py` : `Débit 501 / Crédit 530`
- [x] `AutomaticAccountingService` Python — `on_remboursement()` appelé dans `remboursements.py` : `Débit 530 / Crédit 501 + 701 + 703`
- [x] `AutomaticAccountingService` Python — `on_depot_epargne()` appelé dans `epargne.py` : `Débit 530 / Crédit 521`
- [x] `AutomaticAccountingService` Python — `on_retrait_epargne()` appelé dans `epargne.py` : `Débit 521 / Crédit 530`

**Jobs nocturnes (APScheduler — démarré dans `main.py` lifespan)**
- [x] `daily_penalties.py` : scanner les `echeanciers` non soldés et calculer `capital_restant × taux × jours_retard` — déclenché à **00h05**
- [x] `nightly_scoring.py` : recalculer le score crédit de chaque client (barème base 60, clamp 0-100, seuils 70/40) — déclenché à **02h00**
- [x] `monthly_interests.py` : capitaliser les intérêts épargne (`solde × taux / 100 / 12`), écriture `Débit 602 / Crédit 521` — déclenché le **1er du mois à 01h00**
- [x] Scheduler APScheduler initialisé dans `backend/app/jobs/scheduler.py` avec `replace_existing=True` sur chaque job

**Dashboard & State Management**
- [x] `DashboardNotifier` avec Provider (`ChangeNotifier`) — cache transparent, `load()` / `refresh()` / `clearCache()`
- [x] `MultiProvider` dans `main.dart`, `Consumer<DashboardNotifier>` dans `DashboardPage`
- [x] `clearCache()` appelé dans `AuthService.logout()` — pas de données résiduelles entre sessions

**Tests Phase 3**
- [x] 37 tests passent — property tests équilibre comptable (`sum(débits) == sum(crédits)`) + tests `DashboardNotifier`

---

### Phase 4 — Fonctionnalités métier avancées ✅ 100%

**Produits & Prêts**
- [x] Ajouter le champ assurance (% décès/invalidité) dans le formulaire produit
- [x] Implémenter le calcul du TEG (taux effectif global incluant frais annexes)
- [x] Ajouter la gestion du différé de capital dans le calcul d'amortissement (crédit agricole)

**Comité de crédit**
- [x] Validation par PIN/signature électronique pour les montants > seuil défini
- [x] Conditionner le déblocage à la signature du contrat PDF *(checkbox obligatoire + `PdfExportService.exportLoanContract()` + flag `contrat_signe`)*

**Épargne**
- [x] Bloquer les retraits sur les comptes DAT en cours de terme
- [x] Appliquer les pénalités de rupture anticipée sur les DAT

**Caisse**
- [x] Écran de décompte par coupures physiques (billets 10k, 5k, 2k, 1k, pièces 500...) *(`CashDenominationDialog` intégré dans `CashClosingDialog`)*
- [x] Calcul automatique de l'écart physique vs théorique par coupure
- [x] Validation double clé pour les transferts coffre (caissier + superviseur) *(`PinValidationDialog` dans `CashTransferDialog`)*

**Clients**
- [x] Finaliser l'upload KYC dans `ClientFormDialog` (`file_picker`, stockage local)
- [x] Liaison groupe solidaire dynamique dans le formulaire client
- [x] Création automatique du compte épargne obligatoire à la création du client
- [x] Intégration caméra pour prise de photo du client en direct (`image_picker` — caméra + galerie)
- [ ] Scan de CNI avec OCR *(FilePicker fonctionnel, lecture OCR ML non implémentée)*

---

### Phase 5 — Mode terrain & synchronisation ✅ 100%

- [x] Mode offline agent terrain : verrouiller les données du matin, saisie sans réseau *(`FieldModeService` + bouton « Préparer ma tournée»)*
- [x] File de synchronisation différée (queue locale SQLite → sync serveur le soir) *(`sync_queue` + `flushPendingOperations()` — livré Phase sync)*
- [x] Résolution de conflits lors de la resynchronisation (last-write-wins + résolution manuelle via `ConflictResolutionDialog`)
- [x] Intégration GPS (`geolocator`) pour géolocalisation des visites et collectes
- [x] Intégration caméra (`image_picker`) pour photos clients et pièces justificatives *(visites prêt + justificatif remboursement)*

---

### Phase 6 — Conformité réglementaire *(~80% — vague 2 livrée)*

- [x] Intégrer le plan comptable RCSSFD complet (fichier `lib/assets/docs/Plan des Comptes RCSSFD.txt`)
- [x] Mapper/remplacer le plan comptable actuel avec les comptes RCSSFD (preset 501/530/521 + sélecteur institution)
- [x] Export Excel/CSV de la balance au format SYSCOHADA/RCSSFD (`RegulatoryExportService`)
- [x] En-têtes PDF dynamiques depuis `InstitutionConfiguration` (`InstitutionPdfBranding` → contrat prêt)
- [x] Constructeur de rapports dynamiques dans `CustomReportPage` *(vraies requêtes SQL `rawQuery` — filtres date, journal, compte, montant)*
- [x] Export BCEAO/Coban (fichiers plats CSV `|`-séparés avec BOM UTF-8) *(3 rapports : encours crédit, dépôts épargne, PAR portefeuille — `BceaoExportService`)*
- [x] Relevés mensuels d'épargne générés en PDF (`SavingsStatementService`) — ⚠️ déclenchement manuel seulement ; ❌ génération automatique mensuelle planifiée absente
- [x] Génération PDF dynamique des contrats de prêt (`LoanContractTemplateService` — variables SQL : client, produit, TEG, échéancier, branding)
- [x] Archivage légal : contrat signé scanné attaché au prêt (FilePicker + stockage fichier local + Base64 BDD dans `LoanDetailDialog`)

---

### Phase 7 — Intégrations externes

- [ ] API SMS (Infobip, Twilio ou agrégateur local africain) — approbation prêt, rappels échéances *(UI pré-sélection prête dans `SmsSendingPage` ; envoi simulé)*
- [ ] WhatsApp Business API — messages templates pour rappels de paiement
- [ ] Webhooks Mobile Money (Orange/MTN/Moov) — validation automatique des remboursements *(absent)*
- [ ] Notifications locales planifiées (échéances du jour, alertes PAR) *(package `flutter_local_notifications` absent)*
- [ ] Calcul des commissions agents (volume recouvré, nouvelle épargne captée)
- [ ] Alertes push via WebSockets ou notifications locales planifiées (PAR critique, échéances du jour)
- [ ] Génération automatique mensuelle des relevés épargne (job planifié Flutter ou APScheduler backend)

---

## Conclusion

C'est un projet en **phase avancée d'implémentation** — la grande majorité des fonctionnalités métier sont opérationnelles. La fondation (auth, RBAC, comptabilité automatique, sync offline, conformité réglementaire) est solide et bien couverte par les tests (105 tests passent).

**Ce qui reste à faire :**

| Priorité | Item |
|---|---|
| 🟠 Important | Finaliser la migration Flutter DB→API (~40% restant : demandes prêt, remboursements, détail prêt, communications) |
| 🟠 Important | Brancher une vraie API SMS (Infobip/Twilio) — l'UI est prête |
| 🟡 Utile | Suivi des réunions de groupes solidaires (onglet Documents fonctionnel) |
| 🟡 Utile | Caution solidaire : transfert de dette automatique en cas de défaut membre |
| 🟡 Utile | Génération automatique mensuelle des relevés épargne (job planifié) |
| 🔵 Optionnel | Scan CNI avec OCR |
| 🔵 Optionnel | Webhooks Mobile Money |
| 🔵 Optionnel | Notifications push locales (flutter_local_notifications) |
