# Document des Exigences — Phase 4 : Fonctionnalités Métier Avancées

## Introduction

La Phase 4 couvre les fonctionnalités métier avancées de SIGMA Micro-Finance, regroupées en 4 axes :

1. **Produits & Prêts** — Champ assurance, calcul du TEG, gestion du différé de capital dans l'amortissement
2. **Comité de crédit** — Validation PIN/signature pour montants dépassant un seuil, conditionner le déblocage à un contrat signé
3. **Épargne DAT** — Blocage des retraits sur comptes à terme, pénalités de rupture anticipée
4. **Clients** — Upload KYC, création automatique du compte épargne obligatoire, liaison groupe solidaire dynamique

### État de l'existant

Le modèle `ProduitFinancier` a déjà le champ `differePossible` (bool) et `assurancesObligatoires` (String texte libre) mais sans taux numérique d'assurance ni calcul TEG. Le modèle `SavingsAccount` n'a pas de champ `dateEcheanceTerme` ni de flag DAT bloqué. Le formulaire client (`ClientFormDialog`) n'implémente pas encore l'upload KYC ni la création automatique du compte épargne.

## Glossaire

- **TEG** : Taux Effectif Global — taux incluant le taux nominal, les frais de dossier et les primes d'assurance, exprimant le coût réel du crédit pour l'emprunteur.
- **Différé de capital** : Période en début de prêt pendant laquelle l'emprunteur ne rembourse que les intérêts sans amortir le capital (courant pour le crédit agricole saisonnier).
- **DAT** : Dépôt À Terme — compte d'épargne bloqué jusqu'à une date d'échéance définie.
- **Pénalité de rupture** : Frais prélevés sur les intérêts acquis quand un DAT est retiré avant son terme.
- **KYC** : Know Your Customer — documents d'identité (CNI, passeport, justificatif domicile) obligatoires réglementairement.
- **Épargne obligatoire** : Compte épargne lié à un prêt, dont le solde minimum est exigé comme garantie partielle.
- **PIN de validation** : Code à 4-6 chiffres saisi par un superviseur autorisé pour valider un déblocage de prêt au-delà d'un seuil.
- **ProductFormDialog** : Formulaire Flutter de création/modification d'un produit financier (`lib/widgets/dialogs/product_form_dialog.dart`).
- **ClientFormDialog** : Formulaire Flutter multi-étapes de création d'un client (`lib/widgets/dialogs/client_form_dialog.dart`).
- **LoanRequestFormDialog** : Formulaire Flutter de demande de prêt (`lib/screens/prets/loan_request_form_dialog.dart`).
- **SavingsAccount** : Modèle Dart d'un compte épargne (`lib/models/savings_account_model.dart`).
- **ProduitFinancier** : Modèle Dart d'un produit financier (`lib/models/produit_financier_model.dart`).

---

## Exigences

### Exigence 1 : Champ taux d'assurance dans le produit de crédit

**User Story :** En tant que directeur financier, je veux configurer un taux d'assurance décès/invalidité sur chaque produit de crédit, afin que ce coût soit inclus dans le calcul du TEG et reflété dans l'échéancier.

#### Critères d'acceptation

1. THE `ProduitFinancier` model SHALL exposer un champ `tauxAssurance` de type `double?` représentant le pourcentage annuel de la prime d'assurance décès/invalidité.
2. WHEN `ProductFormDialog` est affiché pour un produit de type `crédit`, THE form SHALL afficher un champ `TextFormField` pour `tauxAssurance` avec un suffixe `%/an`.
3. IF `tauxAssurance` est null ou 0, THE product SHALL être enregistré sans prime d'assurance et le TEG sera égal au taux nominal.
4. THE `tauxAssurance` SHALL être persisté dans la table `produits_financiers` via la colonne `taux_assurance`.
5. WHEN un produit est chargé depuis SQLite, THE `ProduitFinancier.fromMap()` SHALL mapper correctement `taux_assurance` vers `tauxAssurance`.

---

### Exigence 2 : Calcul du TEG (Taux Effectif Global)

**User Story :** En tant qu'agent de crédit, je veux que le TEG soit automatiquement calculé et affiché dans le formulaire de demande de prêt, afin de respecter l'obligation légale de transparence du coût du crédit.

#### Critères d'acceptation

1. THE system SHALL implémenter la fonction `calculerTEG({montant, dureesMois, tauxNominal, tauxAssurance, fraisDossier})` dans `lib/core/utils/loan_calculator.dart` (ou créer ce fichier s'il n'existe pas).
2. THE TEG SHALL être calculé selon la formule : `TEG = tauxNominal + tauxAssurance + (fraisDossier / montant / (dureesMois / 12)) * 100`.
3. WHEN `LoanRequestFormDialog` affiche le simulateur de prêt, THE dialog SHALL afficher le TEG calculé à côté du taux nominal.
4. THE TEG SHALL être mis à jour en temps réel quand le montant, la durée, le taux ou les frais changent.
5. IF le TEG dépasse le taux d'usure légal défini dans les paramètres de l'institution, THE system SHALL afficher un avertissement visuel (badge rouge) sans bloquer la soumission.

---

### Exigence 3 : Gestion du différé de capital dans l'amortissement

**User Story :** En tant qu'agent de crédit agricole, je veux pouvoir configurer une période de différé en début de prêt, afin que l'amortissement du capital ne commence qu'après la récolte.

#### Critères d'acceptation

1. THE `ProduitFinancier` model SHALL exposer un champ `dureeMaxDiffereCapitalMois` de type `int?` indiquant la durée maximale du différé de capital autorisée pour ce produit.
2. WHEN `ProductFormDialog` est affiché et que `differePossible == true`, THE form SHALL afficher un champ numérique pour `dureeMaxDiffereCapitalMois`.
3. WHEN `LoanRequestFormDialog` affiche les paramètres du prêt et que le produit a `differePossible == true`, THE form SHALL afficher un champ `moisDiffereCapital` permettant à l'agent de saisir entre 0 et `dureeMaxDiffereCapitalMois` mois.
4. WHEN l'échéancier est calculé avec un différé, THE `echeanciers` pendant la période de différé SHALL avoir `capital_du = 0` et `interets_dus = montant × tauxMensuel`, et l'amortissement normal commence à l'échéance suivant la fin du différé.
5. THE champ `moisDiffereCapital` SHALL être persisté dans la table `prets`.

---

### Exigence 4 : Validation PIN pour déblocage de prêts au-delà d'un seuil

**User Story :** En tant que directeur d'agence, je veux qu'un code PIN superviseur soit exigé pour valider tout déblocage de prêt dont le montant dépasse un seuil configuré, afin de contrôler les engagements importants.

#### Critères d'acceptation

1. THE `InstitutionConfiguration` SHALL exposer un champ `seuilValidationPinFCFA` de type `double` (valeur par défaut : 500 000 FCFA).
2. WHEN un agent tente de valider un déblocage de prêt dont le montant dépasse `seuilValidationPinFCFA`, THE system SHALL afficher un dialog `PinValidationDialog` demandant un code PIN à 4 chiffres.
3. THE `PinValidationDialog` SHALL valider le PIN saisi en appelant `AuthService().validateSupervisorPin(pin)`.
4. IF le PIN est correct, THE déblocage SHALL procéder normalement.
5. IF le PIN est incorrect, THE system SHALL afficher un message d'erreur et incrémenter un compteur de tentatives.
6. IF 3 tentatives échouent consécutivement, THE system SHALL bloquer le déblocage et logger l'événement dans `audit_logs`.
7. WHEN le montant du prêt est inférieur ou égal au seuil, THE déblocage SHALL procéder sans demande de PIN.

---

### Exigence 5 : Blocage des retraits sur comptes DAT en cours de terme

**User Story :** En tant que caissier, je veux que le système bloque automatiquement les retraits sur les comptes DAT dont la date d'échéance n'est pas atteinte, afin de respecter l'engagement contractuel.

#### Critères d'acceptation

1. THE `SavingsAccount` model SHALL exposer un champ `dateEcheanceTerme` de type `DateTime?`.
2. THE `SavingsAccount` model SHALL exposer un champ `tauxPenaliteRuptureAnt` de type `double?` représentant le pourcentage des intérêts acquis prélevé en cas de retrait anticipé.
3. WHEN `SavingsOperationDialog` tente un retrait sur un compte dont `savingsCategory == SavingsCategory.bloquee`, THE system SHALL vérifier si `DateTime.now() < dateEcheanceTerme`.
4. IF la date d'échéance n'est pas atteinte et qu'il n'y a pas de validation superviseur, THE system SHALL afficher un dialog d'avertissement `BreakDATDialog` indiquant la date d'échéance et la pénalité applicable.
5. THE `BreakDATDialog` SHALL calculer la pénalité : `pénalité = interetsAcquis × tauxPenaliteRuptureAnt / 100`.
6. WHEN le superviseur valide la rupture anticipée via le PIN, THE system SHALL appliquer la pénalité en soustrayant du solde avant d'effectuer le retrait.
7. IF `dateEcheanceTerme` est atteinte ou dépassée, THE retrait SHALL s'effectuer normalement sans pénalité.

---

### Exigence 6 : Création automatique du compte épargne obligatoire à la création du client

**User Story :** En tant qu'agent de crédit, je veux que la création d'un client déclenche automatiquement l'ouverture d'un compte épargne obligatoire, afin de respecter la politique institutionnelle sans étape supplémentaire.

#### Critères d'acceptation

1. WHEN `ClientFormDialog` crée un nouveau client avec succès, THE system SHALL vérifier s'il existe un produit épargne avec `savingsCategory == SavingsCategory.obligatoire` actif dans le catalogue.
2. IF un tel produit existe, THE system SHALL créer automatiquement un `SavingsAccount` lié au nouveau client avec `statut = actif`, `solde = 0.0`, et `produitId` du produit obligatoire trouvé.
3. THE numéro de compte SHALL être généré selon le format `CEP-{clientId}-{YYYYMM}`.
4. IF plusieurs produits obligatoires existent, THE system SHALL utiliser le premier produit obligatoire actif trouvé.
5. IF aucun produit obligatoire n'existe, THE system SHALL créer le client sans compte épargne et logger un message informatif.
6. WHEN le compte épargne est créé automatiquement, THE system SHALL afficher une notification `SnackBar` informant l'agent que le compte a été ouvert.

---

### Exigence 7 : Upload de documents KYC dans le formulaire client

**User Story :** En tant qu'agent de crédit, je veux pouvoir joindre les documents KYC (CNI, passeport, justificatif domicile) depuis le formulaire client, afin de numériser le dossier directement à la saisie.

#### Critères d'acceptation

1. THE `ClientFormDialog` SHALL inclure une section « Documents KYC » permettant de joindre jusqu'à 5 fichiers (PDF, JPG, PNG).
2. WHEN l'agent appuie sur « Ajouter un document », THE system SHALL ouvrir `FilePicker.platform.pickFiles()` avec les extensions autorisées `['pdf', 'jpg', 'jpeg', 'png']`.
3. THE fichiers sélectionnés SHALL être affichés dans une liste avec leur nom, taille et un bouton de suppression.
4. WHEN le formulaire est soumis, THE fichiers SHALL être copiés dans le dossier de l'application (`getApplicationDocumentsDirectory()/kyc/{clientId}/`) et leurs chemins persistés dans la table `documents_clients`.
5. IF `file_picker` n'est pas disponible dans `pubspec.yaml`, THE task SHALL l'ajouter en dépendance (`file_picker: ^8.1.6`).
6. IF un fichier dépasse 10 Mo, THE system SHALL refuser le fichier et afficher un message d'erreur.

---

### Exigence 8 : Liaison groupe solidaire dans le formulaire client

**User Story :** En tant qu'agent de crédit, je veux pouvoir associer un client à un groupe solidaire dès sa création, afin de ne pas avoir à revenir modifier le dossier après.

#### Critères d'acceptation

1. WHEN `ClientFormDialog` est affiché, THE form SHALL inclure un champ optionnel « Groupe solidaire » avec un `DropdownButtonFormField` listant les groupes actifs depuis `DatabaseService().getGroupesSolidaires()`.
2. IF aucun groupe n'existe, THE dropdown SHALL afficher le message `'Aucun groupe disponible'` et être désactivé.
3. WHEN un groupe est sélectionné et que le client est créé, THE system SHALL insérer une entrée dans `membres_groupe` avec `client_id` et `groupe_id`.
4. THE champ groupe SHALL être optionnel — le client peut être créé sans groupe.

---

### Exigence 9 : Conditionner le déblocage à la signature du contrat PDF

**User Story :** En tant que chef d'agence, je veux qu'aucun prêt ne puisse être débloqué sans que le contrat signé soit confirmé dans le système, afin de garantir la traçabilité juridique de chaque engagement.

#### Critères d'acceptation

1. WHEN le formulaire de déblocage est affiché, THE system SHALL présenter une case à cocher « Contrat signé par le client » non cochée par défaut.
2. WHEN l'agent tente de valider le déblocage sans cocher la case, THE system SHALL refuser la soumission et afficher le message « Veuillez confirmer la signature du contrat avant le déblocage. ».
3. WHEN l'agent appuie sur « Générer contrat PDF », THE system SHALL appeler `PdfExportService` pour produire un contrat de prêt pré-rempli avec les données du dossier.
4. WHEN le déblocage est confirmé avec la case cochée, THE système SHALL persister le flag `contrat_signe = true` dans la table `prets`.

---

### Exigence 10 : Écran de décompte par coupures physiques

**User Story :** En tant que caissier, je veux saisir le décompte physique de la caisse par coupures de billets et pièces, afin d'obtenir automatiquement le solde physique sans addition manuelle.

#### Critères d'acceptation

1. THE `CashDenominationDialog` SHALL afficher une ligne par coupure : 10 000, 5 000, 2 000, 1 000, 500, 200, 100 FCFA.
2. WHEN l'agent saisit une quantité pour chaque coupure, THE dialog SHALL calculer en temps réel `total = sum(quantite × valeur_coupure)`.
3. THE dialog SHALL afficher l'écart entre le total physique calculé et le solde théorique de la caisse.
4. WHEN l'agent valide le décompte, THE `CashClosingDialog` SHALL pré-remplir le champ « Solde Physique » avec le total calculé.
5. THE `CashClosingDialog` SHALL proposer un bouton « Décompte par coupures » à côté du champ « Solde Physique ».

---

### Exigence 11 : Validation double clé pour transferts coffre

**User Story :** En tant que directeur d'agence, je veux qu'un transfert entre la caisse et le coffre nécessite la validation PIN d'un superviseur en plus de l'agent caissier, afin de sécuriser les mouvements de fonds importants.

#### Critères d'acceptation

1. WHEN un agent valide un transfert coffre dans `CashTransferDialog`, THE system SHALL afficher `PinValidationDialog` pour demander le PIN d'un superviseur.
2. IF le PIN superviseur est incorrect ou annulé, THE system SHALL annuler le transfert et afficher un SnackBar d'erreur.
3. IF le PIN superviseur est valide, THE transfert SHALL être enregistré normalement.
4. THE validation PIN SHALL utiliser le `PinValidationDialog` existant (`lib/widgets/dialogs/pin_validation_dialog.dart`).

---

### Exigence 12 : Intégration caméra pour photo client

**User Story :** En tant qu'agent de crédit, je veux pouvoir prendre une photo du client en direct depuis l'application, afin de compléter son dossier KYC sans quitter l'écran de saisie.

#### Critères d'acceptation

1. THE `ClientFormDialog` SHALL proposer deux boutons dans la section photo : « Prendre une photo » et « Choisir depuis galerie ».
2. WHEN l'agent appuie sur « Prendre une photo », THE system SHALL ouvrir la caméra via `ImagePicker().pickImage(source: ImageSource.camera)`.
3. WHEN l'agent appuie sur « Choisir depuis galerie », THE system SHALL ouvrir le sélecteur de fichiers via `ImagePicker().pickImage(source: ImageSource.gallery)`.
4. WHEN une image est sélectionnée, THE system SHALL la copier dans `{appDocDir}/photos/{clientId}.jpg` et stocker le chemin dans `client.photoPath`.
5. THE `pubspec.yaml` SHALL déclarer la dépendance `image_picker: ^1.1.2`.
6. IF `image_picker` n'est pas disponible sur la plateforme (Windows Desktop sans webcam), THE button SHALL être désactivé avec un tooltip « Caméra non disponible sur ce poste ».
