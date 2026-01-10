# Application de Gestion de Micro-Finance
## Système d'Information Complet
Flutter Desktop/Mobile + SQLite (Mode Offline/Online)

---

## Architecture Technique

### Base de données SQLite

**Tables principales:**
- **clients** (informations personnelles et professionnelles)
- **groupes_solidaires** (groupements de clients)
- **garanties** (cautions et garanties des prêts)
- **produits_financiers** (types de prêts et épargne)
- **demandes_pret** (dossiers de crédit)
- **prets** (crédits débloqués et en cours)
- **echeanciers** (calendriers de remboursement)
- **remboursements** (paiements effectués)
- **penalites** (retards et frais)
- **comptes_epargne** (livrets et comptes)
- **transactions_epargne** (dépôts et retraits)
- **operations_caisse** (mouvements journaliers)
- **clotures_caisse** (arrêtés de caisse)
- **transferts** (mouvements inter-agences)
- **comptabilite** (écritures comptables)
- **journaux_comptables** (grand livre)
- **comptes_comptables** (plan comptable)
- **agents** (employés et gestionnaires)
- **agences** (points de service)
- **scoring_client** (évaluation crédit)
- **garanties_sociales** (cautions solidaires)
- **assurances** (couverture crédit/vie)
- **taux_interet** (grilles tarifaires)
- **commissions** (frais et charges)
- **rapports_par** (Portfolio At Risk)
- **historique_credit** (antécédents clients)
- **notifications** (alertes et rappels)
- **sms_emails** (communications clients)
- **documents_clients** (KYC et pièces)
- **parametres_institution**
- **utilisateurs_systeme**
- **audit_logs** (traçabilité complète)

### Structure de navigation

- **Sidebar** : Navigation principale entre modules micro-finance
- **AppBar** : Barre d'outils avec actions rapides et profil utilisateur
- **Body** : Zone de contenu avec onglets contextuels
- **Bottom Bar** : Statistiques temps réel et alertes PAR

---

## Modules & Écrans Détaillés

### 1. TABLEAU DE BORD GÉNÉRAL

**Écran principal avec indicateurs clés**

**Widgets dashboard:**
- **Portefeuille global** : Encours total, nombre de prêts actifs, clients actifs
- **Qualité du portefeuille** : PAR 30, PAR 90, taux de remboursement, créances douteuses
- **Graphiques** : Évolution encours 12 mois, taux de croissance, répartition par produit
- **Alertes critiques** : Échéances du jour, retards importants, clients à risque, caisse à régulariser
- **Indicateurs de performance** : Taux de pénétration, productivité agents, coût par client
- **Collecte du jour** : Montant collecté vs prévu, nombre de remboursements, retards

**Actions rapides:**
- Bouton FAB : "Nouveau client", "Nouveau prêt", "Opération caisse"
- Barre de recherche globale (client/prêt/compte)
- Notifications système (échéances, alertes PAR, anniversaires clients)
- Statut temps réel des agences

**Métriques financières temps réel:**
```
┌─────────────────────────────────────────────────────────┐
│ Encours Total: 15,450,000 FCFA  | Clients Actifs: 1,247 │
│ Collecte Jour: 2,340,000 FCFA   | Décaissements: 3      │
│ PAR > 30j: 2.3% ⚠️               | Taux Remb.: 97.8% ✓   │
└─────────────────────────────────────────────────────────┘
```

---

### 2. GESTION DES CLIENTS

**Écran principal : Registre clients**

**DataTable avec colonnes:**
- Photo, N° Client, Nom complet, Téléphone, Groupe solidaire, Score crédit, Encours, Statut, Actions

**Filtres:**
- Par agence, type client (individuel/groupe), statut (actif/inactif/blacklisté)
- Par score crédit, niveau de risque, ancienneté
- Clients avec retard, clients éligibles nouveau prêt

**Recherche avancée:**
- Nom, numéro client, téléphone, CNI, activité professionnelle

**Actions en lot:**
- Export liste clients, envoi SMS groupé, mise à jour scoring, génération attestations

**Écran détail client (Dossier complet)**

**Tabs:**

```
├── Informations personnelles
│   ├── État civil (nom, prénom, date naissance, lieu)
│   ├── Photo d'identité
│   ├── Pièces d'identité (CNI, passeport, carte électeur)
│   ├── Adresse précise (avec géolocalisation)
│   ├── Contacts (téléphone, WhatsApp, email)
│   ├── Situation familiale (statut, nombre enfants)
│   ├── Personnes références (contacts urgence)
│   ├── Logement (propriétaire/locataire, description)
│   └── Langues parlées
│
├── Informations socio-économiques
│   ├── Activité principale (profession détaillée)
│   ├── Activités secondaires
│   ├── Revenus mensuels (estimés/déclarés)
│   ├── Charges mensuelles
│   ├── Capacité de remboursement calculée
│   ├── Ancienneté activité
│   ├── Lieu d'exercice activité
│   ├── Description activité économique
│   └── Biens et patrimoine
│
├── Groupe solidaire (si applicable)
│   ├── Nom du groupe
│   ├── Autres membres
│   ├── Responsable groupe
│   ├── Caution solidaire active
│   ├── Historique groupe
│   └── Performance collective
│
├── Historique crédit
│   ├── Prêts en cours
│   ├── Prêts remboursés
│   ├── Prêts en retard/contentieux
│   ├── Montants totaux empruntés
│   ├── Performance remboursement (%)
│   ├── Plus long retard enregistré
│   ├── Nombre de restructurations
│   └── Blacklist d'autres IMF (si partagé)
│
├── Scoring & Évaluation
│   ├── Score crédit actuel (0-100)
│   ├── Niveau de risque (Faible/Moyen/Élevé)
│   ├── Facteurs positifs/négatifs
│   ├── Historique scoring
│   ├── Capacité d'endettement
│   ├── Taux d'endettement actuel
│   ├── Montant maximum autorisé
│   └── Date dernière évaluation
│
├── Comptes & Épargne
│   ├── Comptes d'épargne actifs
│   ├── Soldes disponibles
│   ├── Épargne obligatoire (% prêt)
│   ├── Historique transactions
│   ├── Intérêts cumulés
│   └── Blocages/nantissements
│
├── Garanties & Cautions
│   ├── Garanties matérielles
│   │   ├── Type bien (terrain, maison, moto)
│   │   ├── Valeur estimée
│   │   ├── Documents propriété
│   │   └── Photos du bien
│   ├── Cautions personnelles
│   │   ├── Nom caution
│   │   ├── Relation avec client
│   │   ├── Coordonnées complètes
│   │   ├── Capacité financière
│   │   └── Engagement signé
│   └── Caution solidaire groupe
│
├── Documents & KYC
│   ├── Photocopie CNI (recto/verso)
│   ├── Justificatif domicile
│   ├── Photo commerce/activité
│   ├── Contrat de prêt signé
│   ├── Fiche de renseignements
│   ├── Formulaire demande prêt
│   ├── Documents garanties
│   ├── Attestations diverses
│   └── Photos domicile client
│
├── Visites & Suivi terrain
│   ├── Historique visites domicile
│   ├── Visites lieu d'activité
│   ├── Rapports agents terrain
│   ├── Photos et observations
│   ├── Géolocalisation visites
│   ├── Prochaine visite prévue
│   └── Fréquence contact
│
└── Communications
    ├── Historique SMS envoyés
    ├── Appels téléphoniques
    ├── Emails envoyés
    ├── Notifications push
    ├── Rappels de paiement
    └── Messages WhatsApp
```

**Formulaire nouveau client**

**Wizard en étapes:**
1. **Identification** → État civil et contacts
2. **Activité économique** → Profession et revenus
3. **Références** → Contacts urgence et cautions
4. **Documents** → Upload pièces KYC
5. **Évaluation** → Scoring initial
6. **Épargne** → Ouverture compte (optionnel)
7. **Validation** → Vérification et création

**Fonctionnalités:**
- Validation temps réel des champs
- Vérification absence doublons (téléphone, CNI)
- Génération automatique numéro client
- Capture photo client et activité
- Géolocalisation automatique
- Scoring crédit initial
- Création compte épargne obligatoire

---

### 3. GESTION DES GROUPES SOLIDAIRES

**Écran groupes**

**Cards groupe avec:**
- Nom groupe, Responsable, Nombre membres, Encours total, Performance

**Filtres:**
- Par agence, taille groupe, statut (actif/inactif), performance

**Actions:**
- Créer groupe, dissoudre groupe, ajouter/retirer membre

**Écran détail groupe**

**Tabs:**

```
├── Membres du groupe
│   ├── Liste des membres
│   ├── Responsable et trésorier
│   ├── Date adhésion chaque membre
│   ├── Statut dans le groupe
│   └── Performance individuelle
│
├── Prêts collectifs
│   ├── Prêts en cours
│   ├── Répartition par membre
│   ├── Taux de remboursement groupe
│   ├── Retards éventuels
│   └── Historique prêts groupe
│
├── Caution solidaire
│   ├── Mécanisme caution
│   ├── Engagement solidaire signé
│   ├── Cas d'activation caution
│   ├── Historique interventions
│   └── Montant garanti
│
├── Épargne collective
│   ├── Compte épargne groupe
│   ├── Cotisations régulières
│   ├── Solde disponible
│   ├── Répartition par membre
│   └── Objectifs d'épargne
│
└── Performance & Indicateurs
    ├── Taux remboursement global
    ├── Ancienneté du groupe
    ├── Stabilité membres
    ├── Montant total emprunté
    └── Niveau de risque groupe
```

**Règles de gestion:**
- Minimum 3-5 membres par groupe
- Caution solidaire obligatoire
- Responsable et trésorier désignés
- Réunions régulières documentées

---

### 4. PRODUITS FINANCIERS

**Catalogue produits**

**Types de produits:**

```
├── Produits de crédit
│   ├── Crédit individuel
│   │   ├── Montant min/max
│   │   ├── Durée min/max
│   │   ├── Taux d'intérêt
│   │   ├── Mode calcul intérêt
│   │   ├── Fréquence remboursement
│   │   └── Conditions d'éligibilité
│   │
│   ├── Crédit groupe solidaire
│   │   ├── Montant par membre
│   │   ├── Caution solidaire requise
│   │   ├── Taux préférentiel
│   │   └── Modalités spécifiques
│   │
│   ├── Crédit activité génératrice revenu (AGR)
│   │   ├── Secteurs éligibles
│   │   ├── Montants adaptés
│   │   ├── Différé possible
│   │   └── Accompagnement technique
│   │
│   ├── Crédit équipement
│   │   ├── Matériel finançable
│   │   ├── Durée amortissement
│   │   └── Garantie sur équipement
│   │
│   ├── Crédit urgence/social
│   │   ├── Montants limités
│   │   ├── Procédure accélérée
│   │   ├── Taux solidaire
│   │   └── Remboursement court terme
│   │
│   └── Crédit agricole/saisonnier
│       ├── Calendrier agricole
│       ├── Différé remboursement
│       ├── Remboursement après récolte
│       └── Crédit intrants
│
└── Produits d'épargne
    ├── Épargne libre
    │   ├── Versements libres
    │   ├── Retraits à vue
    │   ├── Taux d'intérêt
    │   └── Solde minimum
    │
    ├── Épargne obligatoire (prêt)
    │   ├── % du montant prêt
    │   ├── Bloquée durée prêt
    │   ├── Libération conditions
    │   └── Taux bonifié
    │
    ├── Épargne programmée
    │   ├── Objectif défini
    │   ├── Versements réguliers
    │   ├── Prime d'épargne
    │   └── Échéance fixée
    │
    ├── Épargne bloquée (DAT)
    │   ├── Durée blocage
    │   ├── Taux préférentiel
    │   ├── Pénalité retrait anticipé
    │   └── Minimum dépôt
    │
    └── Épargne éducation/projet
        ├── But spécifique
        ├── Plan versements
        ├── Bonus gouvernemental (si applicable)
        └── Accompagnement conseil
```

**Configuration produit:**
- Paramètres financiers (taux, durée, montants)
- Conditions d'éligibilité
- Documents requis
- Circuit d'approbation
- Frais et commissions
- Assurances obligatoires

---

### 5. DEMANDES DE PRÊT

**Tableau demandes**

**États workflow:**
- **Brouillon** → En cours de saisie
- **Soumise** → En attente analyse
- **En analyse** → Étude dossier
- **En comité** → Décision comité crédit
- **Approuvée** → Validée pour déblocage
- **Rejetée** → Refusée avec motif
- **Débloquée** → Fonds versés

**Filtres:**
- Par agence, agent, statut, produit, montant, date

**Écran nouvelle demande**

**Formulaire complet:**

```
├── Sélection client
│   ├── Recherche client existant
│   ├── Création nouveau client
│   └── Vérification éligibilité
│
├── Choix du produit
│   ├── Type de crédit
│   ├── Montant demandé
│   ├── Durée souhaitée
│   ├── Fréquence remboursement
│   └── Objet du prêt
│
├── Simulation
│   ├── Calcul échéancier
│   ├── Montant mensualité
│   ├── Total à rembourser
│   ├── Coût du crédit
│   └── Taux effectif global (TEG)
│
├── Analyse financière
│   ├── Revenus mensuels
│   ├── Charges mensuelles
│   ├── Capacité remboursement
│   ├── Taux d'effort (%)
│   ├── Autres dettes
│   └── Reste à vivre
│
├── Garanties
│   ├── Type garantie (matérielle/personnelle)
│   ├── Description bien
│   ├── Valeur estimée
│   ├── Photos/documents
│   ├── Cautions personnelles
│   └── Engagement solidaire
│
├── Documents joint
│   ├── Formulaire demande signé
│   ├── Pièces identité
│   ├── Justificatifs activité
│   ├── Photos commerce/domicile
│   ├── Documents garanties
│   └── Autres pièces
│
├── Visite terrain
│   ├── Rapport visite domicile
│   ├── Rapport visite activité
│   ├── Photos géolocalisées
│   ├── Observations agent
│   └── Recommandations
│
├── Scoring & Risque
│   ├── Score crédit client
│   ├── Historique remboursement
│   ├── Niveau risque
│   ├── Facteurs décisionnels
│   └── Recommandation système
│
└── Décision
    ├── Avis agent terrain
    ├── Avis chef agence
    ├── Décision comité crédit
    ├── Conditions particulières
    └── Motifs si rejet
```

**Workflow d'approbation:**

1. **Agent terrain** → Saisie et instruction dossier
2. **Chef d'agence** → Validation première (montants < seuil)
3. **Comité crédit** → Décision collégiale (montants > seuil)
4. **Direction** → Validation finale (très gros montants)

**Notification automatique** à chaque étape

---

### 6. GESTION DES PRÊTS

**Tableau prêts actifs**

**Vue d'ensemble:**
- N° prêt, Client, Produit, Montant, Solde restant, Échéance prochaine, Jours retard, Statut

**Statuts prêt:**
- 🟢 À jour (aucun retard)
- 🟡 Alerte (1-30 jours retard)
- 🟠 Retard (31-90 jours)
- 🔴 Contentieux (> 90 jours)
- ⚫ Passé en perte

**Filtres:**
- Par statut, agence, agent, produit, niveau risque

**Écran détail prêt**

**Tabs:**

```
├── Informations générales
│   ├── N° contrat et date
│   ├── Client bénéficiaire
│   ├── Produit de crédit
│   ├── Montant octroyé
│   ├── Taux d'intérêt appliqué
│   ├── Durée et fréquence
│   ├── Date déblocage
│   ├── Date échéance finale
│   ├── Agent gestionnaire
│   └── Agence de gestion
│
├── Échéancier
│   ├── Tableau amortissement complet
│   │   ├── N° échéance
│   │   ├── Date prévue
│   │   ├── Capital
│   │   ├── Intérêts
│   │   ├── Total dû
│   │   ├── Capital restant
│   │   └── Statut (payé/impayé)
│   ├── Total capital restant dû
│   ├── Total intérêts restants
│   ├── Prochaine échéance
│   └── Montant mensuel
│
├── Remboursements
│   ├── Historique paiements
│   │   ├── Date paiement
│   │   ├── Montant payé
│   │   ├── Capital remboursé
│   │   ├── Intérêts payés
│   │   ├── Pénalités payées
│   │   ├── N° reçu
│   │   └── Agent collecteur
│   ├── Total remboursé à date
│   ├── Avance/Retard paiement
│   ├── Performance remboursement (%)
│   └── Graphique évolution
│
├── Pénalités & Frais
│   ├── Pénalités de retard
│   │   ├── Taux pénalité
│   │   ├── Jours de retard
│   │   ├── Montant calculé
│   │   ├── Montant payé
│   │   └── Reste dû
│   ├── Frais dossier
│   ├── Frais assurance
│   ├── Autres frais
│   └── Total frais
│
├── Garanties
│   ├── Garanties enregistrées
│   ├── Valeur totale garanties
│   ├── Taux couverture (%)
│   ├── Documents garanties
│   └── Mainlevée prévue
│
├── Suivi & Alertes
│   ├── Jours de retard actuels
│   ├── Historique retards
│   ├── Actions de recouvrement
│   ├── Visites effectuées
│   ├── SMS/Appels de relance
│   ├── Mises en demeure
│   ├── Promesses de paiement
│   └── Notes suivi terrain
│
├── Restructuration
│   ├── Demandes restructuration
│   ├── Nouveaux termes proposés
│   ├── Historique modifications
│   ├── Raisons restructuration
│   └── Approbations nécessaires
│
└── Documents contrat
    ├── Contrat de prêt signé
    ├── Échéancier remis
    ├── Conditions générales
    ├── Actes de garantie
    ├── Assurances
    └── Correspondances
```

**Actions rapides:**
- Enregistrer remboursement
- Envoyer rappel SMS
- Planifier visite
- Restructurer prêt
- Imprimer échéancier
- Générer attestation

**Calcul automatique:**
- Intérêts journaliers
- Pénalités de retard
- Capital amorti
- Solde restant dû

---

### 7. REMBOURSEMENTS & COLLECTE

**Écran collecte du jour**

**Vue agent collecteur:**

```
┌─────────────────────────────────────────────────────────┐
│ COLLECTE DU JOUR - Agent: Jean KOUASSI                  │
│ Date: 08/01/2026                                         │
├─────────────────────────────────────────────────────────┤
│ Prévisions: 25 clients | 1,250,000 FCFA                 │
│ Collecté:   18 clients |   980,000 FCFA (78%)           │
│ En attente:  7 clients |   270,000 FCFA                 │
└─────────────────────────────────────────────────────────┘
```

**Liste échéances du jour:**
- Client, N° prêt, Montant dû, Retard (jours), Statut collecte, Actions

**Enregistrement remboursement:**

```
├── Identification
│   ├── Client (scan/recherche)
│   ├── Prêt concerné
│   └── Échéance à payer
│
├── Montant
│   ├── Montant dû
│   ├── Montant payé
│   ├── Avance/Retard
│   ├── Pénalités incluses
│   └── Solde après paiement
│
├── Mode paiement
│   ├── Espèces
│   ├── Mobile Money (Orange/MTN/Moov)
│   ├── Virement bancaire
│   ├── Chèque
│   └── Mixte
│
├── Affectation paiement
│   ├── Répartition automatique:
│   │   ├── 1. Pénalités
│   │   ├── 2. Intérêts
│   │   └── 3. Capital
│   └── Ajustement manuel possible
│
└── Validation
    ├── Reçu imprimé/SMS
    ├── Signature client
    ├── Mise à jour échéancier
    └── Synchronisation comptabilité
```

**Reçu de paiement:**
- N° reçu unique
- Date et heure
- Client et N° prêt
- Montant et répartition
- Solde restant
- Prochaine échéance
- Signature/tampon agent

**Collecte mobile:**
- Application mobile agent terrain
- Mode offline (sync ultérieure)
- Géolocalisation collecte
- Photo justificatif si besoin
- Envoi SMS automatique client

---

### 8. GESTION DE L'ÉPARGNE

**Tableau comptes épargne**

**Vue d'ensemble:**
- N° compte, Client, Type épargne, Solde, Dernier mouvement, Statut

**Types de comptes:**
- Épargne libre
- Épargne obligatoire (liée prêt)
- Épargne programmée
- Épargne bloquée (DAT)

**Écran détail compte épargne**

**Tabs:**

```
├── Informations compte
│   ├── N° compte
│   ├── Titulaire
│   ├── Type épargne
│   ├── Date ouverture
│   ├── Taux d'intérêt
│   ├── Solde actuel
│   ├── Intérêts acquis
│   └── Statut (actif/bloqué/fermé)
│
├── Transactions
│   ├── Historique mouvements
│   │   ├── Date
│   │   ├── Type (dépôt/retrait)
│   │   ├── Montant
│   │   ├── Solde après
│   │   ├── Agent opération
│   │   └── N° pièce
│   ├── Dépôts totaux
│   ├── Retraits totaux
│   └── Graphique évolution
│
├── Intérêts
│   ├── Taux applicable
│   ├── Mode calcul
│   ├── Intérêts cumulés
│   ├── Dernière capitalisation
│   ├── Prochaine capitalisation
│   └── Historique crédits intérêts
│
├── Conditions & Règles
│   ├── Solde minimum
│   ├── Montant minimum dépôt
│   ├── Montant maximum retrait
│   ├── Fréquence retraits
│   ├── Pénalités retrait anticipé
│   └── Frais de tenue compte
│
└── Documents
    ├── Contrat d'épargne
    ├── Relevés mensuels
    ├── Certificats de blocage
    └── Attestations solde
```

**Opération dépôt:**
- Sélection compte
- Montant versé
- Mode paiement (espèces/virement)
- Bordereau de dépôt
- Mise à jour solde temps réel

**Opération retrait:**
- Vérification identité client
- Solde disponible
- Respect conditions retrait
- Signature client obligatoire
- Reçu de retrait
- SMS notification

---

### 9. CAISSE & TRÉSORERIE

**Tableau de bord caisse**

**État de caisse temps réel:**

```
┌─────────────────────────────────────────────────────────┐
│ CAISSE - Agence Centrale                                │
│ Date: 08/01/2026 - Caissier: Marie DIALLO               │
├─────────────────────────────────────────────────────────┤
│ Solde initial:      2,500,000 FCFA                      │
│ Encaissements:     +3,450,000 FCFA                      │
│ Décaissements:     -2,800,000 FCFA                      │
│ Solde actuel:       3,150,000 FCFA                      │
│                                                           │
│ Plafond caisse:     5,000,000 FCFA                      │
│ Disponible:         1,850,000 FCFA ✓                    │
└─────────────────────────────────────────────────────────┘
```

**Journal de caisse:**

```
├── Encaissements
│   ├── Remboursements prêts
│   ├── Dépôts épargne
│   ├── Frais et commissions
│   ├── Transferts reçus
│   └── Autres recettes
│
├── Décaissements
│   ├── Déblocages prêts
│   ├── Retraits épargne
│   ├── Salaires et frais
│   ├── Transferts envoyés
│   └── Autres dépenses
│
└── Opérations diverses
    ├── Change espèces
    ├── Corrections d'erreur
    └── Ajustements
```

**Opération de caisse:**

```
├── Encaissement
│   ├── Type opération
│   │   ├── Remboursement prêt
│   │   ├── Dépôt épargne
│   │   ├── Frais divers
│   │   └── Autres
│   ├── Client/Bénéficiaire
│   ├── N° prêt/compte
│   ├── Montant encaissé
│   ├── Mode paiement
│   ├── N° reçu généré
│   └── Pièce comptable
│
└── Décaissement
    ├── Type opération
    │   ├── Déblocage prêt
    │   ├── Retrait épargne
    │   ├── Remboursement frais
    │   └── Autres
    ├── Bénéficiaire
    ├── Montant à payer
    ├── Mode paiement
    ├── Pièces justificatives
    ├── Double signature (si montant élevé)
    └── Bordereau décaissement
```

**Clôture de caisse:**

**Processus quotidien:**
1. **Arrêt des opérations** (heure fixe)
2. **Décompte physique espèces** (par coupures)
3. **Rapprochement comptable** (théorique vs physique)
4. **Traitement écarts** (justification obligatoire)
5. **Édition brouillard de caisse**
6. **Validation chef agence**
7. **Transfert excédent coffre-fort**
8. **Report solde jour suivant**

**Rapport clôture:**
```
┌─────────────────────────────────────────────────────────┐
│ CLÔTURE DE CAISSE                                        │
│ Date: 08/01/2026 - Agence: Centrale                     │
├─────────────────────────────────────────────────────────┤
│ DÉCOMPTE ESPÈCES:                                        │
│   Billets 10,000 x 150 = 1,500,000                      │
│   Billets  5,000 x 200 = 1,000,000                      │
│   Billets  2,000 x  80 =   160,000                      │
│   Billets  1,000 x 300 =   300,000                      │
│   Pièces    500 x 380 =   190,000                       │
│   ─────────────────────────────────                     │
│   TOTAL PHYSIQUE:        3,150,000 FCFA                 │
│                                                           │
│ SOLDE COMPTABLE:         3,150,000 FCFA                 │
│ ÉCART:                           0 FCFA ✓               │
│                                                           │
│ Signatures:                                              │
│ Caissier: ___________  Chef agence: ___________         │
└─────────────────────────────────────────────────────────┘
```

**Transferts inter-agences:**
- Demande transfert
- Validation direction
- Émission bordereau
- Réception et confirmation
- Traçabilité complète

**Gestion coffre-fort:**
- Solde coffre séparé caisse
- Double clé (caissier + chef)
- Mouvements documentés
- Inventaires périodiques

---

### 10. COMPTABILITÉ

**Plan comptable micro-finance**

**Classes comptables:**

```
├── Classe 1 - Capitaux propres
│   ├── 10 - Capital social
│   ├── 11 - Réserves
│   ├── 12 - Report à nouveau
│   └── 13 - Résultat de l'exercice
│
├── Classe 2 - Immobilisations
│   ├── 21 - Immobilisations incorporelles
│   ├── 22 - Terrains
│   ├── 23 - Bâtiments
│   ├── 24 - Matériel et mobilier
│   └── 28 - Amortissements
│
├── Classe 3 - Stocks (si applicable)
│
├── Classe 4 - Comptes de tiers
│   ├── 40 - Fournisseurs
│   ├── 41 - Clients divers
│   ├── 42 - Personnel
│   ├── 43 - Organismes sociaux
│   └── 44 - État
│
├── Classe 5 - Comptes financiers
│   ├── 50 - Prêts à la clientèle
│   │   ├── 501 - Crédits sains
│   │   ├── 502 - Crédits en retard
│   │   ├── 503 - Crédits douteux
│   │   └── 509 - Provisions pour créances
│   ├── 51 - Banques et établissements financiers
│   ├── 52 - Épargne de la clientèle
│   │   ├── 521 - Épargne à vue
│   │   ├── 522 - Épargne à terme
│   │   └── 523 - Épargne obligatoire
│   ├── 53 - Caisses agences
│   └── 54 - Régies d'avances
│
├── Classe 6 - Charges d'exploitation
│   ├── 60 - Charges d'exploitation bancaire
│   │   ├── 601 - Intérêts sur emprunts
│   │   ├── 602 - Intérêts sur épargne
│   │   └── 609 - Dotations provisions
│   ├── 61 - Achats et variations stocks
│   ├── 62 - Transports et déplacements
│   ├── 63 - Services extérieurs
│   ├── 64 - Impôts et taxes
│   ├── 65 - Autres charges
│   ├── 66 - Charges de personnel
│   └── 68 - Dotations amortissements
│
└── Classe 7 - Produits d'exploitation
    ├── 70 - Produits d'exploitation bancaire
    │   ├── 701 - Intérêts sur prêts
    │   ├── 702 - Commissions et frais
    │   ├── 703 - Pénalités de retard
    │   └── 709 - Reprises provisions
    ├── 71 - Production vendue
    ├── 75 - Autres produits
    └── 77 - Produits financiers
```

**Journal des écritures**

**Écran saisie comptable:**

```
├── En-tête écriture
│   ├── Date comptable
│   ├── N° pièce justificative
│   ├── Libellé opération
│   ├── Journal (Caisse/Banque/OD)
│   └── Agent saisie
│
├── Lignes d'écriture
│   ├── N° compte débité
│   ├── Libellé débit
│   ├── Montant débit
│   ├── N° compte crédité
│   ├── Libellé crédit
│   ├── Montant crédit
│   ├── Client/Tiers
│   └── Analytique (agence/produit)
│
└── Validation
    ├── Équilibre débit/crédit
    ├── Vérification comptes
    ├── Pièce jointe scannée
    └── Validation comptable
```

**Écritures automatiques:**

**Déblocage prêt:**
```
Débit:  501 Crédits à la clientèle    XXX
Crédit: 530 Caisse                    XXX
```

**Remboursement prêt:**
```
Débit:  530 Caisse                    XXX
Crédit: 501 Crédits (capital)         XXX
Crédit: 701 Intérêts sur prêts        XXX
Crédit: 703 Pénalités                 XXX
```

**Dépôt épargne:**
```
Débit:  530 Caisse                    XXX
Crédit: 521 Épargne à vue             XXX
```

**Grand livre & Balance**

**Grand livre par compte:**
- N° compte
- Libellé
- Mouvements chronologiques (débit/crédit)
- Soldes intermédiaires
- Solde final

**Balance générale:**
- Liste tous comptes utilisés
- Totaux débits/crédits
- Soldes débiteurs/créditeurs
- Équilibre obligatoire
- Export Excel/PDF

**États financiers**

```
├── Bilan
│   ├── ACTIF
│   │   ├── Actif immobilisé
│   │   ├── Actif circulant
│   │   │   ├── Portefeuille crédits
│   │   │   ├── Provisions créances
│   │   │   ├── Trésorerie
│   │   │   └── Autres actifs
│   │   └── Total actif
│   │
│   └── PASSIF
│       ├── Capitaux propres
│       ├── Dettes financières
│       ├── Épargne clientèle
│       ├── Autres dettes
│       └── Total passif
│
├── Compte de résultat
│   ├── Produits d'exploitation
│   │   ├── Intérêts sur prêts
│   │   ├── Commissions
│   │   ├── Pénalités
│   │   └── Autres produits
│   ├── Charges d'exploitation
│   │   ├── Intérêts sur épargne
│   │   ├── Charges personnel
│   │   ├── Charges fonctionnement
│   │   ├── Dotations provisions
│   │   └── Autres charges
│   └── RÉSULTAT NET
│
├── Tableau flux de trésorerie
│   ├── Flux activités opérationnelles
│   ├── Flux activités investissement
│   ├── Flux activités financement
│   └── Variation nette trésorerie
│
└── Annexes
    ├── Méthodes comptables
    ├── Détail provisions
    ├── Engagements hors bilan
    └── Notes explicatives
```

**Écritures de fin de période:**
- Calcul et comptabilisation intérêts courus
- Dotation provisions créances douteuses
- Régularisation charges/produits
- Amortissements
- Clôture exercice

---

### 11. PORTFOLIO AT RISK (PAR)

**Tableau de bord PAR**

**Indicateurs de qualité du portefeuille:**

```
┌─────────────────────────────────────────────────────────┐
│ QUALITÉ DU PORTEFEUILLE - Au 08/01/2026                 │
├─────────────────────────────────────────────────────────┤
│ Encours total:              125,450,000 FCFA            │
│                                                           │
│ PAR 1  (1-30 jours):          2,145,000 FCFA (1.71%)    │
│ PAR 30 (31-90 jours):         2,890,000 FCFA (2.30%) ⚠️ │
│ PAR 90 (> 90 jours):          1,256,000 FCFA (1.00%)    │
│                                                           │
│ Taux de remboursement:                97.8% ✓           │
│ Nombre prêts en retard:               147 / 1,834       │
│ Montant pénalités dues:               345,000 FCFA      │
│                                                           │
│ Provisions constituées:              1,890,000 FCFA     │
│ Taux de couverture:                        150%         │
└─────────────────────────────────────────────────────────┘
```

**Classification des crédits:**

```
├── Crédits sains (0 jour retard)
│   ├── Encours
│   ├── Nombre
│   └── % du portefeuille
│
├── Crédits sous surveillance (1-30j)
│   ├── Alerte précoce
│   ├── Actions préventives
│   └── Suivi rapproché
│
├── Crédits en retard (31-90j)
│   ├── Recouvrement amiable intensif
│   ├── Restructuration possible
│   └── Provision 25%
│
├── Crédits douteux (91-180j)
│   ├── Mise en demeure
│   ├── Activation garanties
│   ├── Négociation arrangement
│   └── Provision 50%
│
└── Crédits compromis (> 180j)
    ├── Procédures contentieuses
    ├── Saisie garanties
    ├── Provision 100%
    └── Passage en perte envisagé
```

**Analyse PAR par segment:**
- PAR par agence
- PAR par agent
- PAR par produit
- PAR par secteur d'activité
- PAR par tranche de montant
- PAR groupes vs individuel

**Écran détail créances en souffrance:**

```
├── Identification
│   ├── Client et contact
│   ├── N° prêt
│   ├── Agent gestionnaire
│   └── Agence
│
├── Situation financière
│   ├── Solde dû
│   ├── Échéances impayées
│   ├── Jours de retard
│   ├── Pénalités accumulées
│   └── Provision constituée
│
├── Historique retards
│   ├── Premier retard
│   ├── Évolution
│   ├── Paiements partiels
│   └── Promesses non tenues
│
├── Actions recouvrement
│   ├── Relances téléphoniques
│   ├── Visites domicile
│   ├── SMS/Courriers
│   ├── Mises en demeure
│   ├── Réunions familiales
│   └── Médiation groupe
│
├── Garanties disponibles
│   ├── Type et valeur
│   ├── Réalisabilité
│   ├── Procédure activation
│   └── Estimation récupération
│
└── Décision recommandée
    ├── Poursuite recouvrement
    ├── Restructuration
    ├── Contentieux
    └── Passage en perte
```

**Stratégies de recouvrement:**

**Phase amiable (0-90 jours):**
1. **J+1** : SMS rappel automatique
2. **J+3** : Appel téléphonique
3. **J+7** : Visite domicile/activité
4. **J+15** : Convocation agence
5. **J+30** : Engagement écrit paiement
6. **J+45** : Réunion avec caution/groupe
7. **J+60** : Dernière mise en garde
8. **J+90** : Passage contentieux

**Outils de recouvrement:**
- Système de rappels automatiques
- Planning visites terrain
- Scripts d'appels standardisés
- Modèles de courriers
- Suivi promesses de paiement
- Tableau de bord agent recouvrement

---

### 12. REPORTING & TABLEAUX DE BORD

**Dashboard direction**

**Widgets analytics:**

```
├── Indicateurs d'activité
│   ├── Nombre clients actifs
│   ├── Nouveaux clients mois
│   ├── Clients sortis
│   ├── Taux de pénétration zone
│   └── Fidélisation (%)
│
├── Portefeuille crédit
│   ├── Encours total
│   ├── Nombre prêts actifs
│   ├── Montant moyen prêt
│   ├── Croissance mensuelle (%)
│   ├── Décaissements mois
│   ├── Remboursements mois
│   └── Encours par produit
│
├── Qualité du portefeuille
│   ├── PAR 30 (%)
│   ├── Taux de remboursement
│   ├── Taux de perte (write-off)
│   ├── Provisions / Encours
│   ├── Évolution PAR 6 mois
│   └── Créances douteuses
│
├── Épargne mobilisée
│   ├── Total épargne collectée
│   ├── Nombre comptes
│   ├── Épargne moyenne
│   ├── Croissance épargne
│   ├── Ratio épargne/crédit
│   └── Répartition par type
│
├── Performance financière
│   ├── Produits financiers
│   │   ├── Intérêts perçus
│   │   ├── Commissions
│   │   └── Pénalités
│   ├── Charges d'exploitation
│   │   ├── Charges personnel
│   │   ├── Intérêts épargne
│   │   └── Fonctionnement
│   ├── Résultat net
│   ├── ROA (Return on Assets)
│   ├── ROE (Return on Equity)
│   └── Autosuffisance opérationnelle
│
├── Productivité & Efficience
│   ├── Clients par agent
│   ├── Portefeuille par agent
│   ├── Ratio charges/produits
│   ├── Coût par client
│   ├── Coût par FCFA prêté
│   └── Taux d'utilisation fonds
│
├── Indicateurs sociaux
│   ├── % femmes clientes
│   ├── % clients ruraux
│   ├── Secteurs financés
│   ├── Emplois créés/maintenus
│   └── Impact social mesuré
│
└── Trésorerie & Liquidité
    ├── Solde caisses + banques
    ├── Besoins financement
    ├── Ratio liquidité
    ├── Échéances à venir 30j
    └── Capacité décaissement
```

**Graphiques & Visualisations:**
- Évolution encours sur 12 mois
- Courbe PAR et taux remboursement
- Répartition géographique (carte)
- Top 10 agents performance
- Produits les plus demandés
- Profil clients (âge, sexe, activité)

**Rapports standard:**

```
├── Rapports opérationnels
│   ├── Rapport journalier d'activité
│   ├── Situation hebdomadaire
│   ├── Rapport mensuel complet
│   ├── Rapport trimestriel direction
│   └── Rapport annuel
│
├── Rapports portefeuille
│   ├── État du portefeuille
│   ├── Analyse PAR détaillée
│   ├── Suivi remboursements
│   ├── Performances agents
│   └── Analyse par produit
│
├── Rapports financiers
│   ├── Situation comptable
│   ├── États financiers
│   ├── Analyse rentabilité
│   ├── Suivi budget
│   └── Prévisions trésorerie
│
├── Rapports réglementaires
│   ├── Déclaration autorité tutelle
│   ├── Statistiques centrale risques
│   ├── Rapports audit
│   └── Conformité réglementaire
│
└── Rapports bailleurs
    ├── Indicateurs de performance
    ├── Impact social
    ├── Utilisation fonds
    └── Rapports narratifs
```

**Rapport mensuel type:**

```
═══════════════════════════════════════════════════════════
RAPPORT MENSUEL D'ACTIVITÉ - Décembre 2025
═══════════════════════════════════════════════════════════

I. SYNTHÈSE EXÉCUTIVE
   • Encours total: 128,5 M FCFA (+4,2%)
   • PAR 30: 2,1% (objectif < 3%)
   • Taux remboursement: 98,1%
   • Nouveaux clients: 87
   • Résultat net: 4,2 M FCFA

II. ACTIVITÉ CRÉDIT
   • Demandes reçues: 156
   • Prêts approuvés: 142 (91%)
   • Montant décaissé: 42,3 M FCFA
   • Montant remboursé: 38,1 M FCFA
   • Encours fin mois: 128,5 M FCFA

III. QUALITÉ DU PORTEFEUILLE
   • PAR 1-30j: 1,8% (stable)
   • PAR 31-90j: 2,1% (↓0,3%)
   • PAR > 90j: 0,9% (↓0,1%)
   • Créances passées en perte: 450K

IV. ÉPARGNE
   • Solde épargne: 45,2 M FCFA (+2,1M)
   • Nouveaux comptes: 92
   • Ratio épargne/crédit: 35,2%

V. PERFORMANCE FINANCIÈRE
   • Produits financiers: 8,7 M FCFA
   • Charges d'exploitation: 4,5 M FCFA
   • Résultat net: 4,2 M FCFA
   • ROA: 3,8% | ROE: 12,5%

VI. RECOMMANDATIONS
   • Intensifier recouvrement agence Nord
   • Former 3 nouveaux agents
   • Lancer produit crédit agricole
═══════════════════════════════════════════════════════════
```

**Personnalisation rapports:**
- Générateur de rapports visuels
- Sélection indicateurs personnalisés
- Filtres multiples (période/agence/produit)
- Planification envois automatiques
- Formats : PDF, Excel, Word
- Diffusion email automatique

---

### 13. GESTION DES AGENCES

**Réseau d'agences**

**Vue d'ensemble:**

```
┌─────────────────────────────────────────────────────────┐
│ RÉSEAU - 5 AGENCES                                       │
├─────────────────────────────────────────────────────────┤
│ Agence Centrale      | 545 clients | Enc: 52M | PAR: 1.8%│
│ Agence Nord          | 312 clients | Enc: 28M | PAR: 3.2%│
│ Agence Sud           | 245 clients | Enc: 23M | PAR: 1.5%│
│ Agence Est           | 189 clients | Enc: 15M | PAR: 2.1%│
│ Agence Ouest         | 156 clients | Enc: 10M | PAR: 2.8%│
└─────────────────────────────────────────────────────────┘
```

**Écran détail agence:**

```
├── Informations générales
│   ├── Nom et code agence
│   ├── Adresse complète
│   ├── Téléphone/Email
│   ├── Géolocalisation
│   ├── Zone de couverture
│   ├── Date d'ouverture
│   └── Statut (active/fermée)
│
├── Équipe
│   ├── Chef d'agence
│   ├── Agents de crédit
│   ├── Caissiers
│   ├── Back-office
│   └── Effectif total
│
├── Portefeuille
│   ├── Nombre clients actifs
│   ├── Encours total
│   ├── Encours par produit
│   ├── Nombre prêts actifs
│   ├── Montant moyen prêt
│   └── PAR agence
│
├── Épargne
│   ├── Nombre comptes
│   ├── Solde total épargne
│   ├── Épargne moyenne
│   └── Nouveaux comptes mois
│
├── Performance
│   ├── Produits financiers
│   ├── Charges fonctionnement
│   ├── Résultat agence
│   ├── ROA agence
│   ├── Productivité agents
│   └── Taux de pénétration zone
│
├── Caisse & Trésorerie
│   ├── Solde caisse
│   ├── Plafond autorisé
│   ├── Coffre-fort
│   ├── Dernière clôture
│   └── Régularité
│
└── Infrastructures
    ├── Locaux (propriété/location)
    ├── Équipements informatiques
    ├── Mobilier de bureau
    ├── Coffre-fort et sécurité
    └── État général
```

**Objectifs par agence:**
- Objectifs mensuels/trimestriels/annuels
- Suivi réalisation vs objectifs
- Indicateurs clés de performance (KPI)
- Primes et incitations liées

**Comparaison inter-agences:**
- Benchmarking performance
- Classement agences
- Meilleures pratiques
- Plans d'amélioration

---

### 14. GESTION DES AGENTS

**Équipe terrain**

**Rôles et profils:**

```
├── Direction
│   ├── Directeur Général
│   ├── Directeur des Opérations
│   └── Directeur Financier
│
├── Chefs d'agence
│   ├── Supervision équipe agence
│   ├── Validation prêts (seuils)
│   ├── Gestion caisse agence
│   └── Reporting hiérarchique
│
├── Agents de crédit
│   ├── Prospection clients
│   ├── Instruction dossiers
│   ├── Suivi portefeuille
│   ├── Collecte remboursements
│   └── Recouvrement amiable
│
├── Caissiers
│   ├── Opérations caisse
│   ├── Encaissements/Décaissements
│   ├── Clôture journalière
│   └── Tenue registres
│
├── Back-office
│   ├── Saisie données
│   ├── Archivage documents
│   ├── Comptabilité
│   └── Reporting
│
└── Recouvrement
    ├── Suivi créances douteuses
    ├── Négociations clients
    ├── Procédures contentieuses
    └── Activation garanties
```

**Écran détail agent:**

```
├── Informations personnelles
│   ├── Nom, prénom, photo
│   ├── Contacts
│   ├── Date d'embauche
│   ├── Fonction/Poste
│   └── Agence affectation
│
├── Portefeuille géré
│   ├── Nombre clients assignés
│   ├── Encours sous gestion
│   ├── Nombre prêts actifs
│   ├── PAR du portefeuille
│   └── Performance remboursement
│
├── Activité mensuelle
│   ├── Nouveaux clients acquis
│   ├── Prêts débloqués
│   ├── Montant décaissé
│   ├── Collecte réalisée
│   ├── Visites terrain effectuées
│   └── Taux d'atteinte objectifs
│
├── Performance
│   ├── PAR du portefeuille (%)
│   ├── Taux de remboursement
│   ├── Productivité (prêts/mois)
│   ├── Qualité instruction dossiers
│   ├── Délai traitement demandes
│   └── Satisfaction clients (si mesuré)
│
├── Objectifs & Primes
│   ├── Objectifs mensuels
│   ├── Réalisation (%)
│   ├── Primes sur performance
│   ├── Bonus qualité portefeuille
│   └── Historique rémunération variable
│
└── Formation & Développement
    ├── Formations suivies
    ├── Certifications obtenues
    ├── Évaluations annuelles
    └── Plan de développement
```

**Système de primes:**
- Prime sur nouveaux clients
- Prime sur décaissements
- Prime sur qualité portefeuille (PAR < seuil)
- Bonus atteinte objectifs
- Malus si PAR élevé

**Planning & Affectations:**
- Zones géographiques par agent
- Planning visites clients
- Tournées de collecte
- Répartition équilibrée portefeuille

---

### 15. COMMUNICATIONS & NOTIFICATIONS

**Système de notifications**

**Notifications automatiques:**

```
├── Rappels clients
│   ├── Échéance dans 3 jours (SMS)
│   ├── Échéance aujourd'hui (SMS)
│   ├── Retard J+1 (SMS)
│   ├── Retard J+7 (SMS + Appel)
│   ├── Retard J+15 (Courrier)
│   └── Retard J+30 (Mise en demeure)
│
├── Notifications internes
│   ├── Nouvelle demande prêt
│   ├── Validation requise
│   ├── Déblocage approuvé
│   ├── Alerte PAR agence
│   ├── Caisse à régulariser
│   ├── Échéances non collectées
│   └── Objectifs non atteints
│
├── Alertes système
│   ├── Plafond caisse atteint
│   ├── Documents expirés
│   ├── Scoring client dégradé
│   ├── Prêt éligible renouvellement
│   ├── Anniversaire client
│   └── Erreurs synchronisation
│
└── Communications marketing
    ├── Nouveaux produits
    ├── Promotions spéciales
    ├── Événements IMF
    └── Éducation financière
```

**Gestion SMS:**

**Templates SMS:**
```
├── Rappels échéances
│   "Bonjour {NOM}. Votre échéance de {MONTANT} FCFA 
│    est due le {DATE}. Merci de votre ponctualité."
│
├── Confirmation paiement
│   "Bonjour {NOM}. Paiement de {MONTANT} FCFA reçu 
│    le {DATE}. Solde restant: {SOLDE} FCFA. Merci!"
│
├── Retard paiement
│   "Bonjour {NOM}. Votre paiement est en retard de 
│    {JOURS} jours. Merci de régulariser rapidement."
│
├── Déblocage prêt
│   "Félicitations {NOM}! Votre prêt de {MONTANT} FCFA 
│    est approuvé. Passez à l'agence pour retrait."
│
└── Vœux & Relations client
    "Joyeux anniversaire {NOM}! Toute l'équipe vous 
     souhaite une excellente journée."
```

**Tableau de bord communications:**
- SMS envoyés aujourd'hui/mois
- Taux de lecture (si disponible)
- Coût communications
- Crédit SMS restant
- Historique par client

**Intégration Mobile Money:**
- Collecte via Orange Money/MTN/Moov
- Notifications paiement reçu
- Rapprochement automatique
- Historique transactions

---

### 16. PARAMÈTRES & CONFIGURATION

**Configuration institution**

```
├── Informations légales
│   ├── Raison sociale
│   ├── Forme juridique
│   ├── N° d'agrément
│   ├── Registre de commerce
│   ├── N° fiscal (IFU)
│   ├── Adresse siège social
│   ├── Contacts officiels
│   └── Logo institution
│
├── Paramètres financiers
│   ├── Exercice fiscal
│   ├── Devise de référence
│   ├── Taux de change (si multi-devises)
│   ├── Plafonds caisses
│   ├── Seuils d'approbation
│   └── Frais de dossier standard
│
├── Paramètres crédit
│   ├── Taux d'intérêt par défaut
│   ├── Modes de calcul intérêts
│   │   ├── Linéaire
│   │   ├── Dégressif
│   │   └── Amortissement constant
│   ├── Fréquences remboursement
│   │   ├── Quotidien
│   │   ├── Hebdomadaire
│   │   ├── Bimensuel
│   │   ├── Mensuel
│   │   └── Trimestriel
│   ├── Taux pénalités retard (%)
│   ├── Délai de grâce maximum
│   ├── Épargne obligatoire (%)
│   └── Ratio endettement maximum
│
├── Paramètres épargne
│   ├── Taux d'intérêt épargne
│   ├── Solde minimum compte
│   ├── Frais tenue compte
│   ├── Fréquence capitalisation
│   └── Plafonds retraits
│
├── Scoring crédit
│   ├── Grille de notation
│   ├── Poids des critères
│   ├── Seuils d'acceptation
│   └── Règles automatiques
│
└── Règles de gestion
    ├── Circuit validation prêts
    ├── Autorités signatures
    ├── Procédures obligatoires
    └── Workflows personnalisés
```

**Gestion utilisateurs & sécurité**

**Profils d'accès:**

```
├── Super Administrateur
│   └── Accès total système + configuration
│
├── Directeur Général
│   ├── Tous modules consultation
│   ├── Validation prêts tous montants
│   ├── Reporting complet
│   ├── Gestion paramètres institution
│   └── Validation budgets
│
├── Directeur Opérations
│   ├── Gestion clients et prêts
│   ├── Supervision agences
│   ├── Validation prêts > seuil
│   ├── Suivi portefeuille
│   └── Reporting opérationnel
│
├── Directeur Financier
│   ├── Comptabilité complète
│   ├── États financiers
│   ├── Caisse et trésorerie
│   ├── Contrôle de gestion
│   └── Reporting financier
│
├── Chef d'agence
│   ├── Gestion agence uniquement
│   ├── Validation prêts < seuil
│   ├── Supervision agents
│   ├── Caisse agence
│   └── Reporting agence
│
├── Agent de crédit
│   ├── Portefeuille assigné uniquement
│   ├── Saisie demandes prêts
│   ├── Collecte remboursements
│   ├── Suivi clients
│   └── Visites terrain
│
├── Caissier
│   ├── Opérations caisse
│   ├── Encaissements/Décaissements
│   ├── Consultation clients
│   └── Clôture caisse
│
├── Comptable
│   ├── Saisie écritures
│   ├── États comptables
│   ├── Rapprochements
│   └── Déclarations
│
├── Contrôleur interne
│   ├── Consultation tous modules
│   ├── Audit trails
│   ├── Rapports contrôle
│   └── Aucune modification
│
└── Client (Portail web/mobile)
    ├── Consultation soldes
    ├── Historique transactions
    ├── Demande prêt en ligne
    ├── Relevés et documents
    └── Profil personnel
```

**Sécurité & Audit:**

```
├── Authentification
│   ├── Login/mot de passe
│   ├── Authentification 2 facteurs (2FA)
│   ├── Biométrie (empreinte/visage)
│   ├── Expiration session
│   └── Verrouillage après échecs
│
├── Traçabilité
│   ├── Logs toutes actions
│   ├── Qui a fait quoi, quand
│   ├── Modifications données sensibles
│   ├── Connexions/déconnexions
│   ├── Tentatives échouées
│   └── Exports de données
│
├── Sauvegarde
│   ├── Backup automatique quotidien
│   ├── Backup incrémental continu
│   ├── Stockage sécurisé externe
│   ├── Rétention 90 jours minimum
│   ├── Tests restauration mensuels
│   └── Plan de reprise d'activité
│
├── Conformité RGPD
│   ├── Consentement clients
│   ├── Droit d'accès données
│   ├── Droit de rectification
│   ├── Droit à l'oubli (anonymisation)
│   ├── Portabilité données
│   └── Politique confidentialité
│
└── Contrôles internes
    ├── Séparation des tâches
    ├── Double validation montants élevés
    ├── Limites par rôle
    ├── Réconciliations obligatoires
    └── Revues périodiques accès
```

**Gestion des sessions:**
- Sessions multiples interdites (1 user = 1 session)
- Timeout inactivité (15-30 min)
- Déconnexion automatique fin journée
- Historique connexions

---

### 17. DOCUMENTS & CONTRATS

**Bibliothèque documentaire**

```
├── Contrats types
│   ├── Contrat de prêt individuel
│   ├── Contrat de prêt groupe
│   ├── Contrat d'épargne
│   ├── Acte de caution solidaire
│   ├── Engagement personnel caution
│   ├── Reconnaissance de dette
│   └── Avenant modification contrat
│
├── Formulaires
│   ├── Demande de prêt
│   ├── Fiche de renseignements client
│   ├── Demande d'ouverture compte
│   ├── Demande de retrait épargne
│   ├── Bordereau versement
│   └── Réclamation client
│
├── Documents garanties
│   ├── Acte de nantissement
│   ├── Attestation propriété
│   ├── Procuration vente bien
│   └── Photos biens en garantie
│
├── Reçus et bordereaux
│   ├── Reçu de remboursement
│   ├── Reçu de dépôt épargne
│   ├── Bordereau décaissement
│   ├── Reçu de déblocage
│   └── Relevé de compte
│
├── Attestations
│   ├── Attestation de non-engagement
│   ├── Attestation de bonne fin
│   ├── Certificat de solde
│   ├── Attestation de paiement
│   └── Quitus final
│
├── Courriers types
│   ├── Lettre d'approbation prêt
│   ├── Lettre de refus motivé
│   ├── Rappel échéance
│   ├── Mise en demeure 1, 2, 3
│   ├── Convocation agence
│   └── Félicitations bonne gestion
│
└── Documents internes
    ├── Rapport d'instruction
    ├── Rapport visite terrain
    ├── Fiche d'évaluation garantie
    ├── Procès-verbal comité crédit
    └── Rapport d'incident
```

**Génération automatique:**
- Remplissage automatique champs
- Fusion données client/prêt
- Numérotation séquentielle
- QR code traçabilité
- Signature électronique
- Export PDF
- Impression directe

**Archivage numérique:**
- Scan documents signés
- Classification automatique
- Recherche full-text
- Indexation métadonnées
- Conservation légale (10 ans)
- Coffre-fort numérique

---

### 18. MOBILE & SYNCHRONISATION

**Application mobile agent**

**Fonctionnalités offline:**

```
├── Consultation clients
│   ├── Fiche client complète
│   ├── Historique prêts
│   ├── Échéancier actuel
│   └── Contacts et adresse
│
├── Collecte remboursements
│   ├── Enregistrement paiement
│   ├── Génération reçu
│   ├── Calcul automatique répartition
│   ├── Capture géolocalisation
│   └── Mode offline complet
│
├── Visites terrain
│   ├── Checklist visite
│   ├── Prise de photos
│   ├── Notes vocales
│   ├── Géolocalisation
│   └── Rapport pré-rempli
│
├── Nouvelle demande
│   ├── Saisie formulaire
│   ├── Capture documents (scan)
│   ├── Photos client/activité
│   ├── Signature électronique
│   └── Upload différé
│
└── Consultation planning
    ├── Clients à visiter aujourd'hui
    ├── Échéances à collecter
    ├── Itinéraire optimisé
    └── Statistiques personnelles
```

**Synchronisation:**
- Sync bidirectionnelle automatique
- Sync sur connexion WiFi/4G
- Résolution conflits intelligente
- Indicateur statut sync
- Historique synchronisations
- Mode manuel si besoin

**Application client (portail)**

```
├── Mon espace
│   ├── Solde prêt en cours
│   ├── Prochaine échéance
│   ├── Historique paiements
│   ├── Solde épargne
│   └── Documents personnels
│
├── Demande en ligne
│   ├── Simulateur prêt
│   ├── Formulaire demande
│   ├── Upload documents
│   ├── Suivi statut demande
│   └── Notifications avancement
│
├── Paiements
│   ├── Paiement Mobile Money
│   ├── Historique transactions
│   ├── Reçus électroniques
│   └── Rappels automatiques
│
└── Services
    ├── Prise rendez-vous agence
    ├── Chat support
    ├── FAQ
    └── Localisation agences
```

---

### 19. ANALYTICS & BUSINESS INTELLIGENCE

**Tableaux de bord avancés**

```
├── Vue Direction (CEO Dashboard)
│   ├── KPI stratégiques en temps réel
│   ├── Tendances long terme
│   ├── Alertes critiques
│   ├── Comparaisons secteur
│   └── Projections futures
│
├── Vue Opérationnelle
│   ├── Performance agences
│   ├── Productivité agents
│   ├── Qualité portefeuille
│   ├── Pipeline prêts
│   └── Collecte quotidienne
│
├── Vue Financière
│   ├── Rentabilité produits
│   ├── Structure coûts
│   ├── Marges nettes
│   ├── Ratios financiers
│   └── Trésorerie prévisionnelle
│
├── Vue Risque
│   ├── Cartographie risques
│   ├── Concentration portefeuille
│   ├── Stress tests
│   ├── Early warning signals
│   └── Provisions nécessaires
│
└── Vue Client
    ├── Segmentation clientèle
    ├── Comportements d'emprunt
    ├── Taux rétention
    ├── Satisfaction mesurée
    └── Potentiel cross-selling
```

**Analyses prédictives:**
- Prédiction probabilité défaut
- Scoring prédictif client
- Prévision croissance portefeuille
- Anticipation besoins trésorerie
- Identification clients à risque

**Data Mining:**
- Profils clients performants
- Corrélations PAR et variables
- Saisonnalité activité
- Optimisation processus
- Opportunités marché

---

### 20. INTÉGRATIONS & API

**Intégrations externes**

```
├── Mobile Money
│   ├── Orange Money
│   ├── MTN Mobile Money
│   ├── Moov Money
│   ├── API paiement
│   └── Webhooks notifications
│
├── SMS Gateway
│   ├── Envoi SMS masse
│   ├── SMS transactionnels
│   ├── Rapports délivrabilité
│   └── Gestion crédit SMS
│
├── Services bancaires
│   ├── Virements SWIFT
│   ├── Prélèvements automatiques
│   ├── Rapprochement bancaire auto
│   └── Consultation soldes
│
├── Bureaux de crédit
│   ├── Consultation historique crédit
│   ├── Déclaration incidents paiement
│   ├── Partage données (avec consentement)
│   └── Score bureau national
│
├── Autorité de régulation
│   ├── Reporting réglementaire
│   ├── Télé-déclarations
│   ├── Statistiques secteur
│   └── Conformité temps réel
│
├── Comptabilité externe
│   ├── Export écritures
│   ├── Import pièces
│   ├── Formats standards (SAGE, etc.)
│   └── Liasses fiscales
│
└── Cartographie
    ├── Géolocalisation clients
    ├── Optimisation tournées
    ├── Carte portefeuille
    └── Analyse géographique
```

**API REST propre:**
- Documentation Swagger
- Authentification JWT
- Rate limiting
- Webhooks événements
- SDK disponibles

---

## MAQUETTES D'ÉCRANS

### Écran Dashboard Principal

```
┌────────────────────────────────────────────────────────────────┐
│ ☰ LOGO IMF          [🔍 Recherche...]      👤 Jean K.  🔔(5)   │
├────┬───────────────────────────────────────────────────────────┤
│📊  │ TABLEAU DE BORD - 08 Janvier 2026, 14:35                  │
│🏠  ├───────────────────────────────────────────────────────────┤
│    │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│👥  │ │ CLIENTS  │ │ ENCOURS  │ │ PAR 30   │ │ COLLECTE │     │
│Cli │ │  1,247   │ │  125.4M  │ │  2.3%    │ │  2.34M   │     │
│    │ │  +12     │ │  +4.2%   │ │  ⚠️ -0.1%│ │  78%     │     │
│💰  │ └──────────┘ └──────────┘ └──────────┘ └──────────┘     │
│Prê ├───────────────────────────────────────────────────────────┤
│    │ ÉVOLUTION ENCOURS (12 MOIS)                               │
│💳  │     ▆                                                      │
│Épa │   ▅ █ ▆                                                    │
│    │ ▃ █ █ █ ▇ █                                               │
│📥  │▂█ █ █ █ █ █ ▆ █ ▇ █ ▆ █                                   │
│Cai │J F M A M J J A S O N D                                    │
│    ├──────────────────────────┬────────────────────────────────┤
│📊  │ ALERTES DU JOUR (8)      │ TOP 5 AGENTS                   │
│Rep │ • 3 prêts>90j retard ⚠️  │ 1. Marie D.    📊 98.5%       │
│    │ • Caisse Nord non clôt.  │ 2. Jean K.     📊 97.8%       │
│⚙️  │ • 5 échéances impayées   │ 3. Fatou S.    📊 96.2%       │
│Par │ • Budget dépassé Ouest   │ 4. Ibrahim T.  📊 95.1%       │
│    │                          │ 5. Aïcha B.    📊 94.8%       │
└────┴──────────────────────────┴────────────────────────────────┘
```

### Écran Fiche Client

```
┌────────────────────────────────────────────────────────────────┐
│ ← Retour   CLIENT #CL-001247 - KOUADIO Adjoua Marie            │
├────────────────────────────────────────────────────────────────┤
│ [📷]  NOM: KOUADIO Adjoua Marie     📞 +225 07 XX XX XX XX    │
│ Photo SEXE: Féminin  ÂGE: 34 ans    📧 kouadio.m@email.com    │
│       CNI: CI-XXXX-XXXX             📍 Cocody, Angré 8ème      │
│       MEMBRE DEPUIS: 15/03/2022 (3 ans 9 mois)                 │
│       SCORE CRÉDIT: 78/100 ⭐⭐⭐⭐  RISQUE: Faible              │
├────────────────────────────────────────────────────────────────┤
│ [Infos] [Économique] [Crédits] [Épargne] [Docs] [Historique]  │
├────────────────────────────────────────────────────────────────┤
│ INFORMATIONS SOCIO-ÉCONOMIQUES                                 │
│                                                                 │
│ Activité principale: Commerce de tissus                        │
│ Lieu d'activité: Marché d'Adjamé, Box 127                     │
│ Ancienneté activité: 8 ans                                     │
│                                                                 │
│ Revenus mensuels estimés: 450,000 FCFA                        │
│ Charges mensuelles: 180,000 FCFA                              │
│ Capacité remboursement: 135,000 FCFA/mois                     │
│ Taux d'effort actuel: 22% (Excellent ✓)                       │
│                                                                 │
│ PRÊTS EN COURS                                                  │
│ ┌─────────────────────────────────────────────────────────────┐│
│ │ Prêt #PR-2024-08945 | AGR Commerce | 2,500,000 FCFA        ││
│ │ Débloqué: 15/09/2024 | Durée: 12 mois | Mensualité: 55,000 ││
│ │ Échéance: 15/01/2026 | Solde: 1,250,000 | Retard: 0 jour 🟢││
│ │ [Voir détails] [Échéancier] [Historique paiements]         ││
│ └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│ ÉPARGNE                                                         │
│ Compte #EP-001247 | Solde: 185,000 FCFA | Intérêts: 3,250    │
│ Épargne obligatoire bloquée: 125,000 FCFA                     │
│                                                                 │
│ [➕ Nouveau Prêt] [💰 Remboursement] [📄 Documents]            │
└────────────────────────────────────────────────────────────────┘
```

### Écran Nouvelle Demande de Prêt

```
┌────────────────────────────────────────────────────────────────┐
│ NOUVELLE DEMANDE DE PRÊT                                 [✖]   │
├────────────────────────────────────────────────────────────────┤
│ Étape 2/7: Choix du produit                                    │
│ [●●○○○○○]                                                      │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ CLIENT SÉLECTIONNÉ:                                            │
│ KOUADIO Adjoua Marie (#CL-001247) | Score: 78 | Éligible ✓   │
│                                                                 │
│ PRODUIT DE CRÉDIT:                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│ │ ☑️ AGR      │ │   Groupe    │ │  Équipement │              │
│ │  Commerce   │ │  Solidaire  │ │             │              │
│ │ 6-36 mois   │ │ 6-24 mois   │ │ 12-36 mois  │              │
│ │ Taux: 2%/m  │ │ Taux: 1.8%  │ │ Taux: 2.2%  │              │
│ └─────────────┘ └─────────────┘ └─────────────┘              │
│                                                                 │
│ MONTANT DEMANDÉ:                                               │
│ [_3,000,000_] FCFA                                            │
│ Min: 100,000 | Max: 5,000,000                                 │
│                                                                 │
│ DURÉE:                                                          │
│ [_18_] mois  [▼]                                              │
│                                                                 │
│ FRÉQUENCE REMBOURSEMENT:                                       │
│ ○ Hebdomadaire  ●Mensuel  ○ Trimestriel                       │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐│
│ │ SIMULATION INSTANTANÉE                                      ││
│ │                                                             ││
│ │ Montant: 3,000,000 FCFA                                    ││
│ │ Taux: 2% par mois (24% annuel)                             ││
│ │ Durée: 18 mois                                              ││
│ │ Frais dossier: 30,000 FCFA                                 ││
│ │ Épargne obligatoire (5%): 150,000 FCFA                     ││
│ │                                                             ││
│ │ MENSUALITÉ: 194,500 FCFA                                   ││
│ │ TOTAL À REMBOURSER: 3,501,000 FCFA                         ││
│ │ COÛT DU CRÉDIT: 501,000 FCFA                               ││
│ └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│ OBJET DU PRÊT:                                                 │
│ [Achat marchandises - Réassort stock tissus               ]   │
│                                                                 │
│           [Précédent]              [Continuer Simulation →]    │
└────────────────────────────────────────────────────────────────┘
```

### Écran Collecte Agent Terrain

```
┌────────────────────────────────────────────────────────────────┐
│ COLLECTE DU JOUR - Agent: Jean KOUASSI         📶 Offline ✓   │
├────────────────────────────────────────────────────────────────┤
│ 🗓️ Mercredi 08/01/2026        📍 Zone: Abobo Gare             │
│                                                                 │
│ PRÉVISIONS: 25 clients | 1,250,000 FCFA                       │
│ COLLECTÉ:   18 clients |   980,000 FCFA (78%) ▓▓▓▓▓▓▓▓░░      │
│ EN ATTENTE:  7 clients |   270,000 FCFA                        │
├────────────────────────────────────────────────────────────────┤
│ 🟢 KONAN Yao (#PR-2024-11234)            ✓ Payé 14:15         │
│    Dû: 55,000 | Payé: 55,000 | Prochain: 08/02                │
├────────────────────────────────────────────────────────────────┤
│ 🟡 TRAORE Aminata (#PR-2024-10987)       ⚠️ 2 jours retard    │
│    Dû: 42,000 | Pénalité: 840 | Total: 42,840                 │
│    [📞 Appeler] [📍 Localiser] [💰 Collecter]                  │
├────────────────────────────────────────────────────────────────┤
│ 🔴 DIALLO Mamadou (#PR-2024-09654)       ⚠️ 15 jours retard   │
│    Dû: 75,000 | Pénalités: 22,500 | Total: 97,500             │
│    Dernière visite: 02/01/2026                                 │
│    [📞 Appeler] [📍 Localiser] [✍️ Rapport visite]             │
├────────────────────────────────────────────────────────────────┤
│ [🔄 Sync (3 ops en attente)] [➕ Nouvelle collecte] [📊 Stats] │
└────────────────────────────────────────────────────────────────┘
```

### Écran Enregistrement Remboursement

```
┌────────────────────────────────────────────────────────────────┐
│ ENREGISTRER REMBOURSEMENT                              [✖]     │
├────────────────────────────────────────────────────────────────┤
│ CLIENT: KOUADIO Adjoua Marie (#CL-001247)                     │
│ PRÊT: #PR-2024-08945 | AGR Commerce                           │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐│
│ │ ÉCHÉANCE DU 08/01/2026                                      ││
│ │                                                             ││
│ │ Capital:        45,000 FCFA                                ││
│ │ Intérêts:       10,000 FCFA                                ││
│ │ Pénalités:           0 FCFA                                ││
│ │ ─────────────────────────────                              ││
│ │ TOTAL DÛ:       55,000 FCFA                                ││
│ └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│ MONTANT PAYÉ:                                                   │
│ [_55,000_] FCFA                                               │
│                                                                 │
│ MODE DE PAIEMENT:                                              │
│ ● Espèces                                                      │
│ ○ Mobile Money (Orange/MTN/Moov)                               │
│ ○ Chèque                                                        │
│ ○ Virement                                                      │
│                                                                 │
│ RÉPARTITION AUTOMATIQUE:                                       │
│ ✓ Pénalités:        0 FCFA                                    │
│ ✓ Intérêts:    10,000 FCFA                                    │
│ ✓ Capital:     45,000 FCFA                                    │
│                                                                 │
│ SOLDE APRÈS PAIEMENT: 1,205,000 FCFA                          │
│ PROCHAINE ÉCHÉANCE: 08/02/2026 (55,000 FCFA)                  │
│                                                                 │
│ 📍 Géolocalisation: 5.3599° N, -4.0083° W                     │
│                                                                 │
│ SIGNATURE CLIENT:                                              │
│ [  Zone de signature tactile  ]                                │
│                                                                 │
│     [Annuler]   [✓ Valider et Imprimer Reçu]                  │
└────────────────────────────────────────────────────────────────┘
```

### Écran Caisse - Clôture Journalière

```
┌────────────────────────────────────────────────────────────────┐
│ CLÔTURE DE CAISSE - 08/01/2026                                 │
│ Agence: Centrale | Caissier: Marie DIALLO                     │
├────────────────────────────────────────────────────────────────┤
│ SOLDE INITIAL:           2,500,000 FCFA                        │
│                                                                 │
│ ENCAISSEMENTS:                                                  │
│ • Remboursements prêts:  2,890,000 FCFA                       │
│ • Dépôts épargne:          450,000 FCFA                        │
│ • Frais divers:            110,000 FCFA                        │
│ TOTAL ENCAISSEMENTS:  +3,450,000 FCFA                         │
│                                                                 │
│ DÉCAISSEMENTS:                                                  │
│ • Déblocages prêts:    2,500,000 FCFA                         │
│ • Retraits épargne:      280,000 FCFA                          │
│ • Frais fonctionnement:   20,000 FCFA                          │
│ TOTAL DÉCAISSEMENTS:  -2,800,000 FCFA                         │
│                                                                 │
│ SOLDE THÉORIQUE:         3,150,000 FCFA                        │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐│
│ │ DÉCOMPTE PHYSIQUE PAR COUPURES                              ││
│ │                                                             ││
│ │ Billets 10,000 x [_150_] = 1,500,000 FCFA                  ││
│ │ Billets  5,000 x [_200_] = 1,000,000 FCFA                  ││
│ │ Billets  2,000 x [_80_]  =   160,000 FCFA                  ││
│ │ Billets  1,000 x [_300_] =   300,000 FCFA                  ││
│ │ Pièces     500 x [_380_] =   190,000 FCFA                  ││
│ │ ───────────────────────────────────────                    ││
│ │ TOTAL PHYSIQUE:             3,150,000 FCFA                 ││
│ └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│ ÉCART:                           0 FCFA ✓                      │
│                                                                 │
│ OBSERVATIONS:                                                   │
│ [Aucune anomalie. Caisse conforme.                        ]   │
│                                                                 │
│ SIGNATURE CAISSIER:          SIGNATURE CHEF AGENCE:            │
│ [____________________]       [____________________]            │
│                                                                 │
│         [Annuler]    [✓ Valider et Clôturer]                   │
└────────────────────────────────────────────────────────────────┘
```

### Écran Tableau de Bord PAR

```
┌────────────────────────────────────────────────────────────────┐
│ PORTFOLIO AT RISK (PAR) - Qualité du Portefeuille             │
├────────────────────────────────────────────────────────────────┤
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐           │
│ │ PAR 1-30j    │ │ PAR 31-90j   │ │ PAR >90j     │           │
│ │   1.71%      │ │   2.30% ⚠️   │ │   1.00%      │           │
│ │ 2,145,000    │ │ 2,890,000    │ │ 1,256,000    │           │
│ └──────────────┘ └──────────────┘ └──────────────┘           │
│                                                                 │
│ ENCOURS TOTAL: 125,450,000 FCFA | CRÉANCES À RISQUE: 6,291,000│
│ TAUX REMBOURSEMENT: 97.8% | PROVISIONS: 1,890,000 (150%)      │
├────────────────────────────────────────────────────────────────┤
│ ÉVOLUTION PAR 30 (6 derniers mois)                             │
│                                                                 │
│ 4.0% │                                                          │
│ 3.5% │    ●                                                     │
│ 3.0% │   ╱ ╲                                                    │
│ 2.5% │  ●   ●                                                   │
│ 2.0% │       ╲   ●                                              │
│ 1.5% │         ╲╱ ╲●                                            │
│ 1.0% │             ●                                            │
│      └────────────────────────────                             │
│       Août Sept Oct Nov Déc Jan                                │
├────────────────────────────────────────────────────────────────┤
│ PAR PAR AGENCE:                                                │
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ Agence Sud      │ ▓▓░░░░░░░░  1.5%  ✓                      │ │
│ │ Agence Centrale │ ▓▓░░░░░░░░  1.8%  ✓                      │ │
│ │ Agence Est      │ ▓▓░░░░░░░░  2.1%  ⚠️                     │ │
│ │ Agence Ouest    │ ▓▓▓░░░░░░░  2.8%  ⚠️                     │ │
│ │ Agence Nord     │ ▓▓▓░░░░░░░  3.2%  ⚠️ ACTION REQUISE     │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ CRÉANCES EN SOUFFRANCE PAR AGENT:                              │
│ 1. KONE Seydou (Nord)     - 12 prêts - 890,000 FCFA - 3.8%   │
│ 2. OUATTARA Awa (Ouest)   -  8 prêts - 560,000 FCFA - 3.1%   │
│ 3. BAMBA Issouf (Est)     -  6 prêts - 420,000 FCFA - 2.5%   │
│                                                                 │
│ [📄 Rapport Détaillé] [📊 Export Excel] [🔄 Actualiser]       │
└────────────────────────────────────────────────────────────────┘
```

---

## TECHNOLOGIES RECOMMANDÉES

### Stack Technique

```
├── Frontend Desktop/Mobile
│   ├── Framework: Flutter (Dart)
│   ├── State Management: Riverpod / Bloc
│   ├── UI Components: Material Design 3
│   ├── Charts: fl_chart, syncfusion_flutter_charts
│   └── PDF: pdf, printing packages
│
├── Backend API (Optionnel pour mode Online)
│   ├── Node.js + Express.js ou
│   ├── Python + FastAPI ou
│   ├── PHP + Laravel ou
│   ├── .NET Core
│   └── Architecture: REST API / GraphQL
│
├── Base de données
│   ├── Local: SQLite (Mode Offline)
│   ├── Online: PostgreSQL / MySQL
│   ├── ORM: sqflite (Flutter), Drift
│   └── Migrations: Automatiques avec versioning
│
├── Synchronisation
│   ├── Hive (cache local)
│   ├── Sync bidirectionnelle
│   ├── Conflict resolution
│   └── Queue gestion offline
│
├── Authentification & Sécurité
│   ├── JWT (JSON Web Tokens)
│   ├── Bcrypt (hash mots de passe)
│   ├── Biométrie: local_auth package
│   ├── Chiffrement: encrypt package
│   └── 2FA: OTP, SMS
│
├── Notifications & Communications
│   ├── SMS: Twilio, Africa's Talking
│   ├── Email: SendGrid, AWS SES
│   ├── Push: Firebase Cloud Messaging
│   └── WhatsApp Business API
│
├── Mobile Money
│   ├── Orange Money API
│   ├── MTN Mobile Money API
│   ├── Moov Money API
│   └── Webhooks intégration
│
├── Reporting & Analytics
│   ├── Charts: Recharts, Chart.js
│   ├── Export: PDF (pdf package)
│   ├── Excel: excel, syncfusion_flutter_xlsio
│   └── BI: Metabase (optionnel)
│
└── DevOps & Déploiement
    ├── Version Control: Git (GitHub/GitLab)
    ├── CI/CD: GitHub Actions, GitLab CI
    ├── Container: Docker (pour backend)
    ├── Hosting: AWS, DigitalOcean, Heroku
    ├── Backup: Automatisé quotidien
    └── Monitoring: Sentry, Firebase Crashlytics
```

---

## ARCHITECTURE APPLICATIVE

### Architecture en couches

```
┌──────────────────────────────────────────────────────────┐
│                  PRÉSENTATION (UI)                       │
│  - Écrans Flutter (Material Design)                      │
│  - Widgets réutilisables                                 │
│  - Navigation & Routing                                  │
└──────────────────────────────────────────────────────────┘
                          ↕
┌──────────────────────────────────────────────────────────┐
│            LOGIQUE MÉTIER (Business Logic)               │
│  - Services métier (ClientService, PretService...)       │
│  - Calculs (intérêts, pénalités, échéanciers)           │
│  - Règles de gestion                                     │
│  - Validation données                                    │
└──────────────────────────────────────────────────────────┘
                          ↕
┌──────────────────────────────────────────────────────────┐
│              ACCÈS AUX DONNÉES (Data Layer)              │
│  - Repositories (abstraction DB)                         │
│  - Models (entités métier)                               │
│  - DAO (Data Access Objects)                             │
└──────────────────────────────────────────────────────────┘
                          ↕
┌──────────────────────────────────────────────────────────┐
│            PERSISTANCE (Database & Storage)              │
│  - SQLite local                                          │
│  - Hive (cache)                                          │
│  - Shared Preferences (config)                           │
│  - File Storage (documents)                              │
└──────────────────────────────────────────────────────────┘
```

### Schéma Base de Données Simplifié

```sql
-- CLIENTS
CREATE TABLE clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_client TEXT UNIQUE NOT NULL,
    nom TEXT NOT NULL,
    prenoms TEXT NOT NULL,
    date_naissance DATE,
    sexe TEXT CHECK(sexe IN ('M','F')),
    telephone TEXT,
    adresse TEXT,
    activite_principale TEXT,
    revenus_mensuels REAL,
    score_credit INTEGER DEFAULT 50,
    niveau_risque TEXT CHECK(niveau_risque IN ('Faible','Moyen','Élevé')),
    statut TEXT CHECK(statut IN ('Actif','Inactif','Blacklisté')),
    date_creation DATETIME DEFAULT CURRENT_TIMESTAMP,
    photo_path TEXT,
    latitude REAL,
    longitude REAL
);

-- PRÊTS
CREATE TABLE prets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_pret TEXT UNIQUE NOT NULL,
    client_id INTEGER NOT NULL,
    produit_id INTEGER NOT NULL,
    montant_principal REAL NOT NULL,
    taux_interet REAL NOT NULL,
    duree_mois INTEGER NOT NULL,
    frequence_remboursement TEXT,
    date_deblocage DATE NOT NULL,
    date_echeance_finale DATE NOT NULL,
    montant_mensualite REAL NOT NULL,
    solde_restant REAL NOT NULL,
    jours_retard INTEGER DEFAULT 0,
    statut TEXT CHECK(statut IN ('En cours','Soldé','Retard','Contentieux')),
    FOREIGN KEY (client_id) REFERENCES clients(id),
    FOREIGN KEY (produit_id) REFERENCES produits_financiers(id)
);

-- ÉCHEANCIERS
CREATE TABLE echeanciers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pret_id INTEGER NOT NULL,
    numero_echeance INTEGER NOT NULL,
    date_prevu DATE NOT NULL,
    montant_capital REAL NOT NULL,
    montant_interet REAL NOT NULL,
    montant_total REAL NOT NULL,
    capital_restant REAL NOT NULL,
    statut TEXT CHECK(statut IN ('A payer','Payé','En retard','Annulé')),
    date_paiement DATE,
    montant_paye REAL DEFAULT 0,
    FOREIGN KEY (pret_id) REFERENCES prets(id)
);

-- REMBOURSEMENTS
CREATE TABLE remboursements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_recu TEXT UNIQUE NOT NULL,
    pret_id INTEGER NOT NULL,
    echeance_id INTEGER,
    date_paiement DATETIME NOT NULL,
    montant_total REAL NOT NULL,
    montant_capital REAL NOT NULL,
    montant_interet REAL NOT NULL,
    montant_penalite REAL DEFAULT 0,
    mode_paiement TEXT,
    agent_id INTEGER,
    latitude REAL,
    longitude REAL,
    FOREIGN KEY (pret_id) REFERENCES prets(id),
    FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- COMPTES ÉPARGNE
CREATE TABLE comptes_epargne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_compte TEXT UNIQUE NOT NULL,
    client_id INTEGER NOT NULL,
    type_epargne TEXT,
    solde REAL DEFAULT 0,
    taux_interet REAL,
    date_ouverture DATE NOT NULL,
    statut TEXT CHECK(statut IN ('Actif','Bloqué','Fermé')),
    FOREIGN KEY (client_id) REFERENCES clients(id)
);

-- OPÉRATIONS CAISSE
CREATE TABLE operations_caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agence_id INTEGER NOT NULL,
    caissier_id INTEGER NOT NULL,
    type_operation TEXT CHECK(type_operation IN ('Encaissement','Décaissement')),
    categorie TEXT,
    montant REAL NOT NULL,
    reference TEXT,
    client_id INTEGER,
    date_operation DATETIME DEFAULT CURRENT_TIMESTAMP,
    observations TEXT,
    FOREIGN KEY (agence_id) REFERENCES agences(id),
    FOREIGN KEY (caissier_id) REFERENCES agents(id)
);
```

---

## PLAN DE MISE EN ŒUVRE

### Phase 1 : Fondations (4-6 semaines)
- Configuration projet Flutter
- Architecture et structure
- Base de données SQLite + modèles
- Authentification de base
- Dashboard principal
- Module Clients (CRUD complet)

### Phase 2 : Cœur Métier (6-8 semaines)
- Module Produits Financiers
- Module Demandes de Prêt
- Workflow d'approbation
- Calcul échéanciers
- Module Remboursements
- Module Épargne

### Phase 3 : Opérations (4-6 semaines)
- Module Caisse & Trésorerie
- Clôture journalière
- Module Comptabilité de base
- Écritures automatiques
- Rapports financiers

### Phase 4 : Gestion Risque (3-4 semaines)
- Scoring crédit
- Suivi PAR
- Alertes et notifications
- Module Recouvrement
- Garanties

### Phase 5 : Mobilité (4-5 semaines)
- Application mobile agent
- Mode offline
- Synchronisation
- Géolocalisation
- Collecte terrain

### Phase 6 : Intégrations (3-4 semaines)
- SMS Gateway
- Mobile Money
- Exports avancés
- API REST

### Phase 7 : Reporting & Analytics (2-3 semaines)
- Tableaux de bord avancés
- Rapports personnalisables
- Exports multiformats
- Statistiques

### Phase 8 : Tests & Déploiement (3-4 semaines)
- Tests unitaires
- Tests d'intégration
- Tests utilisateurs
- Formation utilisateurs
- Déploiement pilote
- Go-live production

**DURÉE TOTALE ESTIMÉE : 6-8 mois**

---

## BONNES PRATIQUES

### Développement
- ✅ Architecture Clean (SOLID principles)
- ✅ Repository Pattern
- ✅ Dependency Injection
- ✅ Tests automatisés (unit + widget tests)
- ✅ Code review systématique
- ✅ Documentation code et API
- ✅ Versionning sémantique

### Sécurité
- ✅ Chiffrement données sensibles
- ✅ HTTPS obligatoire
- ✅ Authentification forte (2FA)
- ✅ Gestion fine des permissions
- ✅ Logs d'audit complets
- ✅ Backup automatique quotidien
- ✅ Disaster recovery plan

### UX/UI
- ✅ Interface intuitive et claire
- ✅ Feedback utilisateur constant
- ✅ Messages d'erreur explicites
- ✅ Indicateurs de chargement
- ✅ Mode offline transparent
- ✅ Responsive design
- ✅ Accessibilité

### Performance
- ✅ Pagination des listes
- ✅ Lazy loading
- ✅ Cache intelligent
- ✅ Optimisation requêtes DB
- ✅ Compression images
- ✅ Indexation tables

---

## ANNEXES

### Glossaire Micro-Finance

- **AGR**: Activité Génératrice de Revenus
- **DAT**: Dépôt À Terme
- **IMF**: Institution de Micro-Finance
- **KYC**: Know Your Customer (Connaissance Client)
- **PAR**: Portfolio At Risk (Portefeuille à Risque)
- **TEG**: Taux Effectif Global
- **Write-off**: Passage en perte d'une créance

### Indicateurs Clés de Performance

```
PERFORMANCE PORTEFEUILLE:
- PAR 30 < 3% (Excellent)
- Taux remboursement > 95%
- Taux de croissance encours: 15-25% annuel
- Ratio épargne/crédit: > 20%

PERFORMANCE FINANCIÈRE:
- ROA (Return on Assets) > 3%
- ROE (Return on Equity) > 15%
- Ratio charges/produits < 70%
- Autosuffisance opérationnelle > 100%

PERFORMANCE SOCIALE:
- Taux de pénétration zone: 30-50%
- % femmes clientes: > 60%
- Montant moyen prêt: adapté au marché
- Création/maintien emplois: mesurable
```

---

**DOCUMENT CRÉÉ LE**: 08/01/2026  
**VERSION**: 1.0  
**STATUT**: Spécifications complètes