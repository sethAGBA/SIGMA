# Implémentation : Documents KYC, Caution & Épargne

Ce plan détaille la correction et la finalisation de trois fonctionnalités critiques manquantes dans le formulaire de gestion des clients (`ClientFormDialog`).

## User Review Required

> [!WARNING]
> L'ajout de l'upload de fichiers nécessite l'installation du package officiel `file_picker`. Veuillez confirmer que nous pouvons exécuter cette installation et modifier le code en conséquence.

## Proposed Changes

### 1. Configuration du projet
- Exécuter la commande `flutter pub add file_picker` pour activer la sélection de fichiers depuis le système d'exploitation.

### 2. Formulaire Client (`lib/widgets/dialogs/client_form_dialog.dart`)

**A. Upload de Documents KYC :**
- Importer `package:file_picker/file_picker.dart`.
- Mettre à jour la méthode `_buildDocumentItem` pour ouvrir l'explorateur de fichiers au clic.
- Enregistrer le chemin local du fichier sélectionné dans les variables d'état (ex: `_documentCNIPath`).
- Afficher le nom du fichier et une icône de validation verte lorsqu'un document est chargé, remplaçant l'icône de téléchargement.

**B. Gestion du Groupe Solidaire :**
- Charger la liste des groupes solidaires actifs au démarrage du dialogue.
- Afficher dynamiquement un champ de recherche (Dropdown) pour sélectionner le groupe lorsque le switch "Caution solidaire active" est coché.
- Rattacher l'identifiant du groupe (`_groupeSolidaireId`) au profil du `Client` avant la sauvegarde.

**C. Création Automatique du Compte d'Épargne :**
- Modifier la méthode `_submit()`.
- Après l'insertion réussie du client (`insertClient`), si la variable `_epargneObligatoireOuverte` est `true`, créer instantanément un objet `SavingsAccount`.
- Le lier à l'ID du nouveau client, définir son type sur "Épargne Obligatoire" avec un solde de 0, et l'insérer en base via `DatabaseService().insertSavingsAccount()`.

## Verification Plan

### Manual Verification
1. **Documents :** Sélectionner une fausse CNI lors de la création d'un client et vérifier l'apparition du chemin de fichier.
2. **Groupe Solidaire :** Cocher "Caution solidaire", sélectionner un groupe dans le nouveau champ, enregistrer le client et vérifier la liaison en base.
3. **Épargne :** Cocher "Ouvrir un compte épargne obligatoire", valider la création du client, puis naviguer dans le module "Épargne" pour vérifier que le compte a bien été généré automatiquement avec le solde initial de 0 FCFA.
