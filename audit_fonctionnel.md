# Audit Fonctionnel & Technique Détaillé - SIGMA Micro-Finance

## Introduction & État de l'Architecture
Ce document fournit un audit exhaustif de l'application SIGMA Micro-Finance. Il confronte le code actuel aux spécifications initiales orientées "Système d'Information Complet". 

**Bilan Architectural Actuel :**
- **Interface & Expérience Utilisateur (UI/UX) :** Excellente. Le projet dispose d'une structure Flutter robuste avec un layout réactif, des dialogues riches, des alertes de sécurité et une typographie claire. L'ensemble des 15 modules spécifiés possède ses écrans.
- **Base de données Locale :** Implémentation locale via `sqflite` (et `sqflite_common_ffi` pour Desktop) très poussée. Les relations complexes (Prêts -> Échéanciers -> Remboursements) sont fonctionnelles.
- **Dette Technique & Cloud (Offline/Online) :** ⏳ **Majeure**. L'application fonctionne actuellement à 100% en local (mode "Offline" permanent). L'architecture de synchronisation avec un backend Cloud (API REST/GraphQL, SyncManager local-first) reste entièrement à concevoir pour permettre le mode "Online" décrit dans le cahier des charges.

---

## 1. Tableau de Bord Général
**Ce qui est fait :**
- ✅ UI complète et widgets modulaires (`DashboardPage`, `PortfolioChart`, `BottomStatsBar`).
- ✅ Remontée des indicateurs clés via des requêtes SQLite (Portefeuille, Qualité, Clients actifs).

**Ce qu'il reste à faire (Détails) :**
- ⏳ **En-tête et Pied de page de l'UI (App Bar & Bottom Stats Bar)** : L'en-tête principal (Profil utilisateur, nom de l'agence) et la barre de statistiques en bas de l'écran (`BottomStatsBar` avec Encours 15.45 M, Collecte 2.34 M) affichent actuellement des valeurs codées en dur (Mocks). Il faut les lier dynamiquement au `DatabaseService` (agrégation SQL globale) et au profil de l'utilisateur connecté.
- ⏳ **Performance / Cache** : Mettre en place un State Management (Provider/Riverpod/Bloc) pour mettre le dashboard en cache et éviter de recalculer les requêtes lourdes (agrégations SQLite) à chaque changement d'onglet.
- ⏳ **Alertes Poussées (Push)** : Brancher les alertes du système de notifications (échéances du jour, alertes PAR) sur des WebSockets ou des notifications locales planifiées (Local Notifications).

---

## 2. Gestion des Clients (KYC)
**Ce qui est fait :**
- ✅ Registre avec filtres croisés, dossier en onglets exhaustifs (Infos, Socio-éco, Scoring, Garanties).
- ✅ Validation formelle des données textuelles lors de l'inscription en mode Wizard.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Intégration Matérielle (Caméra & GPS)** : Activer les plugins `image_picker` et `geolocator` pour la prise de photo du client en direct, le scan de la CNI (OCR optionnel), et l'enregistrement strict des coordonnées GPS du domicile/commerce.
- ⏳ **Upload de fichiers (Storage)** : Gestion du stockage des pièces d'identité (enregistrement des fichiers binaires ou chemins locaux robustes, puis synchronisation Cloud).
- ⏳ **Score de Crédit Dynamique** : Le score actuel est un entier saisi ou statique. Il doit devenir une fonction mathématique recalculée la nuit selon l'historique des retards.

---

## 3. Gestion des Groupes Solidaires
**Ce qui est fait :**
- ✅ Vue liste et détails des performances du groupe (Nom, responsable, membres).

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Réunions & Collecte Groupée** : Interface pour tracer la présence aux réunions régulières documentées obligatoires.
- ⏳ **Mécanisme de Caution Solidaire** : Lorsqu'un membre fait défaut, implémenter un "Transfert de dette" ou "Saisie d'épargne" automatique réparti sur l'épargne bloquée des autres membres du groupe.

---

## 4. Produits Financiers
**Ce qui est fait :**
- ✅ Modélisation complète des produits (crédit et épargne) avec taux, durées min/max.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Assurances & Frais de Dossier** : Ajouter le pourcentage d'assurance décès/invalidité au produit, prélevé au déblocage.
- ⏳ **Taux Effectif Global (TEG)** : Implémenter la formule mathématique du calcul du TEG (incluant frais annexes) pour affichage réglementaire aux clients.

---

## 5 & 6. Demandes, Approbations et Suivi des Prêts
**Ce qui est fait :**
- ✅ Suivi des états du workflow (Brouillon -> Approuvée -> Débloquée).
- ✅ Construction de l'échéancier prévisionnel (Amortissement).

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Comité de Crédit** : Implémenter des signatures électroniques/validation par PIN pour que le Chef d'Agence et le Comité valident les montants supérieurs à certains seuils.
- ⏳ **Règles de Calcul d'Amortissement** : Ajouter la prise en charge du différé de paiement (capital différé de X mois) très utilisé en crédit agricole.
- ⏳ **Déblocage Sécurisé** : Lier l'action "Débloquer les fonds" à la vérification préalable de la signature des contrats PDF et du paiement des frais de dossier initiaux.

---

## 7. Remboursements & Collecte sur le Terrain
**Ce qui est fait :**
- ✅ Répartition manuelle des paiements (Pénalités -> Intérêts -> Capital).

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Mode Déconnecté "Agent de Terrain"** : La collecte mobile nécessite de verrouiller certaines données le matin, de permettre la saisie sans internet toute la journée, puis d'effectuer un rapprochement réseau (Sync) le soir sans créer de conflits.
- ⏳ **Paiements Digitaux** : Implémenter les Webhooks pour valider automatiquement un remboursement initié via un opérateur Mobile Money.
- ⏳ **Génération de Pénalités** : Créer un "Job/Tâche de fond" (ex: à 00h00) qui scanne tous les `echeanciers` non soldés et calcule les pénalités de retard par jour (`jours_retard * taux`).

---

## 8. Gestion de l'Épargne
**Ce qui est fait :**
- ✅ Dépôts et retraits, journalisation des transactions.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Épargne DAT (Dépôt à Terme)** : Empêcher purement et simplement le retrait si le compte est bloqué, ou appliquer des pénalités strictes de rupture anticipée.
- ⏳ **Intérêts Composés** : Implémenter le script de capitalisation mensuelle (calcul du solde moyen mensuel * taux / 12) et génération des écritures d'intérêts versés.

---

## 9. Comptabilité (Le Cœur Réglementaire)
**Ce qui est fait :**
- ✅ Plan comptable hiérarchique, Grand livre, Balance de vérification.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Mapping Automatique (Pont Comptable)** : C'est le développement le plus critique. Créer un Service (`AutomaticAccountingService`) qui intercepte un *Remboursement* et génère instantanément les écritures associées.
- ⏳ **Intégration du Référentiel RCSSFD** : Le plan comptable actuel devra être entièrement mappé et remplacé/fusionné avec le vrai "Plan des Comptes RCSSFD" (présent dans `lib/assets/docs/Plan des Comptes RCSSFD.txt`). Cela garantira que les comptes (ex: 1011 pour les billets de la BCEAO) correspondent aux normes UEMOA/OHADA.
- ⏳ **Normes SYSCOHADA / RCSSFD** : Vérifier que l'export Excel de la balance correspond au format réglementaire local exigé par les auditeurs externes.

---

## 10. Gestion de Caisse
**Ce qui est fait :**
- ✅ Traces des entrées/sorties et transferts inter-agences.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Billetage Physique** : L'écran de "Clôture de Caisse" doit inclure la saisie manuelle des coupures physiques (ex: 10 billets de 10k, 5 pièces de 500) pour forcer le caissier à justifier le solde physique, avec calcul automatique de l'écart.
- ⏳ **Validation à double clé** : Un transfert coffre vers caisse doit être validé par l'agent ET le superviseur via mot de passe.

---

## 11. Reporting & Réglementaire
**Ce qui est fait :**
- ✅ Tableaux PAR (Portfolio At Risk 30/90), exports PDF magnifiques.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **En-têtes et Pieds de page PDF dynamiques** : Actuellement, les entêtes (ex: "SIGMA MICRO-FINANCE") et les pieds de page des exports PDF (`PdfExportService`) sont codés en dur. Il faut les remplacer par les données réelles issues des paramètres de l'institution (`InstitutionConfiguration`).
- ⏳ **Constructeur de requêtes dynamiques** : Dans `CustomReportPage`, parser les filtres de l'utilisateur pour construire de vraies requêtes SQL dynamiques au lieu de simples simulations de chargement.
- ⏳ **Export des rapports réglementaires (BCEAO/Coban)** : Génération de fichiers plats (CSV structurés avec séparateurs spécifiques) pour l'intégration aux systèmes centraux des banques de tutelle.

---

## 12. Ressources Humaines & Agences
**Ce qui est fait :**
- ✅ Informations des agents et portefeuilles d'affectation.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Calcul des Commissions** : Logique calculant les primes d'un agent de collecte selon le volume de retards recouvrés ou le volume de nouvelle épargne captée.

---

## 13. Communication & CRM
**Ce qui est fait :**
- ✅ Interface de rédaction de SMS et d'historique.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Intégration API SMS** : Paramétrer les clés API (Infobip, Twilio, ou agrégateur local Africain) pour envoyer de vraies requêtes HTTP POST lors de l'approbation d'un prêt ou pour rappeler une échéance la veille.
- ⏳ **WhatsApp Business API** : Basculer sur les modèles de messages (Templates WhatsApp) moins chers pour les rappels de paiement.

---

## 14. Gestion Documentaire Légale
**Ce qui est fait :**
- ✅ Inventaire des contrats nécessaires.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Génération PDF Dynamique** : Utiliser la librairie `pdf` pour mapper les variables SQL sur un layout de contrat officiel.
- ⏳ **Archivage Légal** : Attacher la version scannée du contrat signé par le client à l'enregistrement du prêt dans la BD (Stockage Blob / Base64 temporaire avant cloud).

---

## 15. Sécurité, Audit & Base de données
**Ce qui est fait :**
- ✅ Journalisation complète des actions dans SQLite (`audit_logs`). Export Backup fonctionnel.

**Ce qu'il reste à faire (Détails) :**
- ⏳ **Système d'Authentification (Login)** : L'application démarre actuellement directement sur le tableau de bord. Il n'y a **aucun écran de connexion**. Il faut créer une page de `Login` et un gestionnaire d'état de session (`AuthService`) pour authentifier le `UserAccount` avant de donner accès à l'application.
- ⏳ **Chiffrement SQLite (SQLCipher)** : Extrêmement important pour la sécurité. En environnement de bureau Windows, le fichier `sigma.db` est actuellement lisible en clair. Il faut implémenter `sqflite_sqlcipher` pour crypter le fichier avec une clé générée.
- ⏳ **Contrôle d'Accès par Rôle (RBAC)** : Une fois le système de Login en place, brancher le rôle de l'utilisateur connecté sur le menu `Sidebar` pour masquer dynamiquement les sections (ex: Cacher la *Comptabilité* aux *Agents Terrain*).
- ⏳ **Exécution Automatique (Timeout)** : Brancher un `Timer` global sur les événements tactiles Flutter (GestureDetector à la racine) pour déconnecter la session après X minutes d'inactivité comme défini dans les règles de l'Audit de Sécurité.
