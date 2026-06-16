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
| **Pas d'écran de login** | L'app démarre directement sur le dashboard. C'est le chantier #1 absolu. |
| **Pas de RBAC** | N'importe quel utilisateur voit tout. |
| **SQLite non chiffré** | Le fichier `.db` est lisible en clair sur le disque Windows. |

### 🟠 Fonctionnel mais incomplet

| Élément | Description |
|---|---|
| **Dashboard avec mocks** | Valeurs codées en dur au lieu de vraies agrégations SQL. |
| **Pas de state management** | Pas de Provider/Riverpod/Bloc — les requêtes lourdes sont recalculées à chaque navigation. |
| **Pont comptable absent** | Les remboursements ne génèrent pas d'écritures comptables automatiques. |

### 🟡 Améliorations importantes

| Élément | Description |
|---|---|
| **Mode offline terrain** | Sync différée pour les agents de collecte. |
| **Pénalités automatiques** | Job nocturne manquant pour calculer les retards. |
| **Plan comptable RCSSFD** | Référentiel réglementaire non encore intégré. |
| **APIs externes** | SMS et Mobile Money non branchés. |

---

## Feuille de route détaillée

---

### Phase 0 — Infrastructure serveur *(prérequis de tout)*
> Backend Python FastAPI + PostgreSQL sur le PC serveur local

- [ ] Installer et configurer PostgreSQL sur le PC serveur
- [ ] Créer le projet backend `backend/` avec FastAPI + SQLAlchemy + Alembic
- [ ] Migrer le schéma SQLite vers PostgreSQL (32 tables)
- [ ] Configurer le réseau local (adresse IP fixe pour le serveur)
- [ ] Créer les premières routes API REST (auth, clients, prêts)
- [ ] Adapter l'app Flutter : remplacer les appels `DatabaseService` directs → appels HTTP via `ApiService`
- [ ] Implémenter le cache SQLite local côté Flutter (mode offline de base)

---

### Phase 1 — Sécurité *(priorité absolue)*
> Bloquer l'accès non authentifié et contextualiser chaque action

- [ ] **LoginPage** : créer l'écran de connexion username/password
- [ ] **AuthService** côté serveur : génération de tokens JWT + refresh token
- [ ] **AuthService** côté Flutter : stocker le token (`shared_preferences`), intercepteur HTTP
- [ ] **Remplacer les 8+ valeurs hardcodées** : `'Jean'`, `'Admin'`, `'SYSTÈME'`, `'Agent Connecté'` → utilisateur de la session courante
- [ ] **Sidebar RBAC** : masquage dynamique des modules selon le rôle (Agent Terrain, Caissier, Chef Agence, Directeur, Admin)
- [ ] **Timeout de session** : `Timer` global sur `GestureDetector` racine — déconnexion après X minutes d'inactivité
- [ ] Chiffrement du cache SQLite local via `sqflite_sqlcipher`

---

### Phase 2 — Corrections UI immédiates *(valeurs hardcodées et simulations)*
> Éliminer tous les mocks et `SnackBar` simulés identifiés lors de l'audit du code

**Dashboard**
- [ ] Brancher le nom d'utilisateur sur la salutation (`'Bonjour, Jean 👋'`)
- [ ] Brancher `BottomStatsBar` sur les vraies agrégations SQL (Encours, Collecte)
- [ ] Ajouter le bouton FAB d'actions rapides (Nouveau client, Nouveau prêt, Opération caisse)

**Clients**
- [ ] Remplacer export CSV simulé → vrai export CSV depuis la liste filtrée
- [ ] Remplacer SMS groupé simulé → brancher sur le module Communications

**Groupes Solidaires**
- [ ] Calculer dynamiquement l'encours du groupe (somme des prêts actifs des membres)
- [ ] Calculer dynamiquement la performance du groupe (taux de remboursement réel)
- [ ] Ajouter l'interface de suivi des réunions de groupe (présence, ordre du jour, compte-rendu)
- [ ] Implémenter le mécanisme de caution solidaire : transfert de dette ou saisie automatique de l'épargne bloquée des membres en cas de défaut

**Caisse**
- [ ] Report du solde de la veille dans la clôture (solde initial réel)
- [ ] Remplacer `'Agent Connecté'` par l'utilisateur de session

**Remboursements**
- [ ] Activer le filtre "Filtrer par retard" dans `DailyCollectionPage`
- [ ] Brancher `agentCollecteur` sur l'utilisateur connecté

**Comptabilité**
- [ ] Remplacer `'Admin'` (×2) dans `SaisieComptablePage` par l'utilisateur connecté
- [ ] Remplacer le bouton "Scan" simulé par l'ouverture d'un `file_picker`

**Reporting**
- [ ] Corriger `DelinquentLoanDetailPage(loanId: 1)` — ID hardcodé → ID dynamique du prêt sélectionné

---

### Phase 3 — Logique métier centrale *(cœur fonctionnel)*

**Pont comptable automatique** *(le plus critique)*
- [ ] Créer `AutomaticAccountingService` côté serveur
- [ ] Générer les écritures lors d'un **déblocage de prêt** : `Débit 501 / Crédit 530`
- [ ] Générer les écritures lors d'un **remboursement** : `Débit 530 / Crédit 501 + 701 + 703`
- [ ] Générer les écritures lors d'un **dépôt épargne** : `Débit 530 / Crédit 521`
- [ ] Générer les écritures lors d'un **retrait épargne** : `Débit 521 / Crédit 530`

**Jobs nocturnes (APScheduler)**
- [ ] `daily_penalties.py` : scanner les `echeanciers` non soldés et calculer `jours_retard × taux`
- [ ] `nightly_scoring.py` : recalculer le score crédit de chaque client selon l'historique des retards
- [ ] `monthly_interests.py` : capitaliser les intérêts sur les comptes d'épargne (solde moyen × taux / 12)

**Dashboard**
- [ ] Mettre en place Provider/Riverpod pour le cache du dashboard (éviter les recalculs à chaque navigation)

---

### Phase 4 — Fonctionnalités métier avancées

**Produits & Prêts**
- [ ] Ajouter le champ assurance (% décès/invalidité) dans le formulaire produit
- [ ] Implémenter le calcul du TEG (taux effectif global incluant frais annexes)
- [ ] Ajouter la gestion du différé de capital dans le calcul d'amortissement (crédit agricole)

**Comité de crédit**
- [ ] Validation par PIN/signature électronique pour les montants > seuil défini
- [ ] Conditionner le déblocage à la signature du contrat PDF

**Épargne**
- [ ] Bloquer les retraits sur les comptes DAT en cours de terme
- [ ] Appliquer les pénalités de rupture anticipée sur les DAT

**Caisse**
- [ ] Écran de décompte par coupures physiques (billets 10k, 5k, 2k, 1k, pièces 500...)
- [ ] Calcul automatique de l'écart physique vs théorique par coupure
- [ ] Validation double clé pour les transferts coffre (caissier + superviseur)

**Clients**
- [ ] Finaliser l'upload KYC dans `ClientFormDialog` (`file_picker`, stockage serveur)
- [ ] Liaison groupe solidaire dynamique dans le formulaire client
- [ ] Création automatique du compte épargne obligatoire à la création du client
- [ ] Intégration caméra pour prise de photo du client en direct (`image_picker`)
- [ ] Scan de CNI avec OCR (optionnel)

---

### Phase 5 — Mode terrain & synchronisation

- [ ] Mode offline agent terrain : verrouiller les données du matin, saisie sans réseau
- [ ] File de synchronisation différée (queue locale SQLite → sync serveur le soir)
- [ ] Résolution de conflits lors de la resynchronisation (last-write-wins ou manuelle)
- [ ] Intégration GPS (`geolocator`) pour géolocalisation des visites et collectes
- [ ] Intégration caméra (`image_picker`) pour photos clients et pièces justificatives

---

### Phase 6 — Conformité réglementaire

- [ ] Intégrer le plan comptable RCSSFD complet (fichier `lib/assets/docs/Plan des Comptes RCSSFD.txt`)
- [ ] Mapper/remplacer le plan comptable actuel avec les comptes RCSSFD (ex: 1011 BCEAO)
- [ ] Vérifier la conformité de l'export Excel de la balance au format SYSCOHADA/RCSSFD (pour auditeurs externes)
- [ ] En-têtes et pieds de page PDF dynamiques (depuis `InstitutionConfiguration` en base)
- [ ] Constructeur de rapports dynamiques dans `CustomReportPage` (vraies requêtes SQL)
- [ ] Export BCEAO/Coban (fichiers plats CSV structurés avec séparateurs spécifiques)
- [ ] Relevés mensuels d'épargne générés automatiquement (PDF)
- [ ] Génération PDF dynamique des contrats de prêt (mapper variables SQL sur layout contrat officiel)
- [ ] Archivage légal : attacher le contrat signé scanné à l'enregistrement du prêt (Blob/Base64)

---

### Phase 7 — Intégrations externes

- [ ] API SMS (Infobip, Twilio ou agrégateur local africain) — approbation prêt, rappels échéances
- [ ] WhatsApp Business API — messages templates pour rappels de paiement
- [ ] Webhooks Mobile Money (Orange/MTN/Moov) — validation automatique des remboursements
- [ ] Notifications locales planifiées (échéances du jour, alertes PAR)
- [ ] Calcul des commissions agents (volume recouvré, nouvelle épargne captée)
- [ ] Alertes push via WebSockets ou notifications locales planifiées (PAR critique, échéances du jour)

---

## Conclusion

C'est un projet en **phase avancée de prototypage UI** mais encore en début de phase de "logique métier". La fondation est solide. Il faut maintenant combler les couches fonctionnelles : authentification, RBAC, comptabilité automatique, et calculs financiers réels.

Le point de départ logique est le **système d'authentification** — il débloque le RBAC, la sécurité, et donne un contexte utilisateur à tous les autres modules.
