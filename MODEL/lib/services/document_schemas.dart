// Schema definitions for school document types and simple validators.
// Use these schemas to build forms, validate input, and persist documents.

import 'dart:core';

enum FieldType { text, number, date, amount, choice, phone, email, file, signature, boolean }

class FieldSpec {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? hint;
  final List<String>? choices;

  const FieldSpec({required this.key, required this.label, required this.type, this.required = false, this.hint, this.choices});
}

class DocumentSchema {
  final String id;
  final String name;
  final List<FieldSpec> fields;

  const DocumentSchema({required this.id, required this.name, required this.fields});
}

/// Schemas for common school documents (French labels)
final Map<String, DocumentSchema> documentSchemas = {
  'diplome': DocumentSchema(
    id: 'diplome',
    name: 'Diplôme',
    fields: [
      FieldSpec(key: 'student_name', label: 'Nom & prénoms', type: FieldType.text, required: true),
      FieldSpec(key: 'birth_date_place', label: 'Date et lieu de naissance', type: FieldType.text, required: true, hint: 'JJ/MM/AAAA, Ville'),
      FieldSpec(key: 'student_id', label: 'Numéro matricule / ID étudiant', type: FieldType.text, required: true),
      FieldSpec(key: 'programme', label: 'Intitulé de la formation / filière', type: FieldType.text, required: true),
      FieldSpec(key: 'level', label: 'Niveau', type: FieldType.choice, required: true, choices: ['Licence', 'Master', 'BTS', 'Doctorat', 'Autre']),
      FieldSpec(key: 'mention', label: 'Mention / Grade obtenu', type: FieldType.text, required: true),
      FieldSpec(key: 'academic_year', label: 'Année académique', type: FieldType.text, required: true, hint: 'ex. 2024-2025'),
      FieldSpec(key: 'institution_name', label: 'Nom de l’établissement', type: FieldType.text, required: true),
      FieldSpec(key: 'diploma_number', label: 'Numéro du diplôme', type: FieldType.text, required: true, hint: 'Référence unique'),
      FieldSpec(key: 'signatures', label: 'Signatures officielles', type: FieldType.signature, required: true, hint: 'Directeur, Responsable pédagogique'),
      FieldSpec(key: 'seal', label: 'Cachet de l’école', type: FieldType.file, required: true),
    ],
  ),

  'recu_paiement': DocumentSchema(
    id: 'recu_paiement',
    name: 'Reçu de paiement',
    fields: [
      FieldSpec(key: 'receipt_number', label: 'Numéro du reçu', type: FieldType.text, required: true),
      FieldSpec(key: 'issue_date', label: 'Date d’émission', type: FieldType.date, required: true),
      FieldSpec(key: 'student_name', label: 'Nom de l’étudiant', type: FieldType.text, required: true),
      FieldSpec(key: 'student_id', label: 'Matricule étudiant', type: FieldType.text, required: true),
      FieldSpec(key: 'amount_paid', label: 'Montant payé', type: FieldType.amount, required: true),
      FieldSpec(key: 'payment_method', label: 'Mode de paiement', type: FieldType.choice, required: true, choices: ['Cash', 'Mobile Money', 'Virement', 'Chèque']),
      FieldSpec(key: 'payment_purpose', label: 'Objet du paiement', type: FieldType.text, required: true),
      FieldSpec(key: 'remaining_balance', label: 'Solde restant', type: FieldType.amount, required: false),
      FieldSpec(key: 'accountant_signature', label: 'Signature/Cachet de l’agent comptable', type: FieldType.signature, required: true),
      FieldSpec(key: 'school_contact', label: 'Coordonnées de l’école', type: FieldType.text, required: false, hint: 'Logo, adresse, téléphone'),
    ],
  ),

  'facture': DocumentSchema(
    id: 'facture',
    name: 'Facture',
    fields: [
      FieldSpec(key: 'invoice_number', label: 'Numéro de la facture', type: FieldType.text, required: true),
      FieldSpec(key: 'issue_date', label: 'Date d’émission', type: FieldType.date, required: true),
      FieldSpec(key: 'recipient_name', label: 'Nom et coordonnées (étudiant / parent)', type: FieldType.text, required: true),
      FieldSpec(key: 'student_id', label: 'Matricule étudiant', type: FieldType.text, required: false),
      FieldSpec(key: 'items', label: 'Désignation (ligne de facture)', type: FieldType.text, required: true, hint: 'Structure attendue: [{designation, quantity, unit_price}]'),
      FieldSpec(key: 'quantity', label: 'Quantité', type: FieldType.number, required: false),
      FieldSpec(key: 'unit_price', label: 'Montant unitaire', type: FieldType.amount, required: true),
      FieldSpec(key: 'subtotal_ht', label: 'Montant total HT', type: FieldType.amount, required: true),
      FieldSpec(key: 'taxes', label: 'Taxes (TVA)', type: FieldType.amount, required: false),
      FieldSpec(key: 'discounts', label: 'Remises / bourses', type: FieldType.amount, required: false),
      FieldSpec(key: 'total_ttc', label: 'Montant TTC à payer', type: FieldType.amount, required: true),
      FieldSpec(key: 'payment_terms', label: 'Conditions de paiement', type: FieldType.text, required: false),
      FieldSpec(key: 'finance_signature', label: 'Signature & cachet du service financier', type: FieldType.signature, required: true),
    ],
  ),

  'inscription': DocumentSchema(
    id: 'inscription',
    name: 'Inscription',
    fields: [
      FieldSpec(key: 'registration_number', label: 'Numéro d’inscription / Matricule', type: FieldType.text, required: true),
      FieldSpec(key: 'student_name', label: 'Nom & prénoms', type: FieldType.text, required: true),
      FieldSpec(key: 'gender', label: 'Sexe', type: FieldType.choice, required: true, choices: ['Masculin', 'Féminin', 'Autre']),
      FieldSpec(key: 'birth_date_place', label: 'Date et lieu de naissance', type: FieldType.text, required: true),
      FieldSpec(key: 'nationality', label: 'Nationalité', type: FieldType.text, required: false),
      FieldSpec(key: 'address', label: 'Adresse complète', type: FieldType.text, required: true),
      FieldSpec(key: 'phone_email', label: 'Téléphone & Email', type: FieldType.text, required: true),
      FieldSpec(key: 'chosen_program', label: 'Formation choisie', type: FieldType.text, required: true),
      FieldSpec(key: 'academic_year', label: 'Année académique', type: FieldType.text, required: true),
      FieldSpec(key: 'admission_mode', label: 'Mode d’admission', type: FieldType.choice, required: true, choices: ['Concours', 'Dossier', 'Orientation']),
      FieldSpec(key: 'documents', label: 'Pièces justificatives', type: FieldType.file, required: true, hint: 'CNI, acte de naissance, relevés, photo'),
      FieldSpec(key: 'registration_date', label: 'Date d’inscription', type: FieldType.date, required: true),
      FieldSpec(key: 'student_signature', label: 'Signature étudiant / parent / tuteur', type: FieldType.signature, required: true),
      FieldSpec(key: 'admin_signature', label: 'Signature de l’administration', type: FieldType.signature, required: true),
    ],
  ),

  'attestation': DocumentSchema(
    id: 'attestation',
    name: 'Attestation',
    fields: [
      FieldSpec(key: 'attestation_number', label: 'Numéro de l’attestation', type: FieldType.text, required: true),
      FieldSpec(key: 'student_name', label: 'Nom & prénoms', type: FieldType.text, required: true),
      FieldSpec(key: 'birth_date_place', label: 'Date et lieu de naissance', type: FieldType.text, required: true),
      FieldSpec(key: 'student_id', label: 'Matricule étudiant', type: FieldType.text, required: true),
      FieldSpec(key: 'purpose', label: "Objet de l’attestation", type: FieldType.text, required: true),
      FieldSpec(key: 'programme', label: 'Formation suivie', type: FieldType.text, required: true),
      FieldSpec(key: 'period', label: 'Période concernée', type: FieldType.text, required: true),
      FieldSpec(key: 'declaration', label: 'Déclaration', type: FieldType.text, required: true),
      FieldSpec(key: 'issue_date', label: 'Date de délivrance', type: FieldType.date, required: true),
      FieldSpec(key: 'signature', label: 'Signature du Directeur / Responsable', type: FieldType.signature, required: true),
      FieldSpec(key: 'seal', label: 'Cachet de l’école', type: FieldType.file, required: true),
    ],
  ),
};

/// Validate a document's data against schema. Returns list of missing/invalid messages.
List<String> validateDocument(String schemaId, Map<String, dynamic> data) {
  final schema = documentSchemas[schemaId];
  if (schema == null) return ['Schema not found: $schemaId'];
  final List<String> errors = [];
  for (final f in schema.fields) {
    final v = data[f.key];
    if (f.required) {
      if (v == null) {
        errors.add('Champ requis manquant: ${f.label} (${f.key})');
        continue;
      }
      if (v is String && v.trim().isEmpty) {
        errors.add('Champ requis vide: ${f.label} (${f.key})');
        continue;
      }
    }
    if (v != null) {
      switch (f.type) {
        case FieldType.amount:
        case FieldType.number:
          final num? parsed = v is num ? v : num.tryParse(v.toString());
          if (parsed == null) errors.add('Valeur numérique attendue pour ${f.label} (${f.key})');
          break;
        case FieldType.email:
          final s = v.toString();
          final emailRe = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+");
          if (!emailRe.hasMatch(s)) errors.add('Email invalide pour ${f.label} (${f.key})');
          break;
        default:
          break;
      }
    }
  }
  return errors;
}
