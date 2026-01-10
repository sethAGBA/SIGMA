import 'dart:convert';
import 'package:sqflite/sqflite.dart';

// This file contains the default canvas templates for the application.

Future<void> insertDefaultCanvasTemplates(Database database) async {
  await _createDefaultCanvasTemplate(database);
  await _createCanvasInvoiceTemplate(database);
  await _createCanvasReceiptTemplate(database);
  await _createCanvasCertificateTemplate(database);
  await _createCanvasEnrollmentTemplate(database);
  await _createNewProfessionalInvoiceTemplate(database);
  await _createCompetenceCertificateTemplate(database);
  await _createParticipationCertificateTemplate(database);
  await _createRegistrationFormTemplate(database);
  await _createProformaInvoiceTemplate(database);
  await _createInterventionCertificateTemplate(database);
  await _createKEmpireBulletinInscriptionTemplate(database);
}

// Helper: default canvas template (simple layout with logo, header and table area)
Future<void> _createDefaultCanvasTemplate(Database database) async {
  final canvas = {
    'canvas': [
      {
        'id': 'el_logo',
        'type': 'placeholder',
        'left': 20.0,
        'top': 20.0,
        'text': '{{company_logo}}',
        'imagePath': null,
      },
      {
        'id': 'el_header',
        'type': 'text',
        'left': 220.0,
        'top': 40.0,
        'text': 'TITRE DU DOCUMENT\n{{document_title}}\n{{academic_year}}',
        'imagePath': null,
      },
      {
        'id': 'el_table',
        'type': 'text',
        'left': 20.0,
        'top': 140.0,
        'text': 'LIGNE 1\nLIGNE 2\nLIGNE 3\n',
        'imagePath': null,
      }
    ]
  };

  await database.insert('document_templates', {
    'id': 'default_canvas',
    'name': 'Modèle Canvas',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

// Canvas: Invoice layout (logo left, header center, table area)
Future<void> _createCanvasInvoiceTemplate(Database database) async {
  final canvas = {
    'canvas': [
      {'id': 'logo', 'type': 'placeholder', 'left': 20.0, 'top': 20.0, 'text': '{{company_logo}}', 'imagePath': null, 'style': {'padding': 4}},
      {'id': 'company', 'type': 'text', 'left': 160.0, 'top': 20.0, 'text': '{{company_name}}\n{{company_address}}\nTél: {{company_phone}}', 'imagePath': null, 'style': {'fontSize': 12, 'color': '#111827'}},
      {'id': 'title', 'type': 'text', 'left': 20.0, 'top': 140.0, 'text': 'FACTURE', 'imagePath': null, 'style': {'fontSize': 28, 'fontWeight': 'bold', 'color': '#0B5394'}},
      {'id': 'meta', 'type': 'text', 'left': 420.0, 'top': 140.0, 'text': 'N°: {{invoice_number}}\nDate: {{invoice_date}}\nÉchéance: {{due_date}}\nMatricule: {{student_id}}', 'imagePath': null, 'style': {'fontSize': 11, 'color': '#374151', 'background': '#F3F4F6', 'padding': 6, 'borderColor': '#E5E7EB', 'borderWidth': 1, 'borderRadius': 6}},
      {'id': 'table_header', 'type': 'text', 'left': 20.0, 'top': 200.0, 'text': 'DESIGNATION\tQTÉ\tPU\tTOTAL', 'imagePath': null, 'style': {'fontWeight': 'bold', 'background': '#EEF2FF', 'padding': 8, 'borderRadius': 4}},
      {'id': 'table_body', 'type': 'text', 'left': 20.0, 'top': 230.0, 'text': 'Formation {{formation_name}}\t1\t{{unit_price}}\t{{line_total}}\n', 'imagePath': null, 'style': {'fontSize': 12}},
      {'id': 'totals', 'type': 'text', 'left': 360.0, 'top': 520.0, 'text': 'Sous-total: {{subtotal}}\nTVA: {{tax}}\nTOTAL: {{total}}', 'imagePath': null, 'style': {'fontSize': 12, 'fontWeight': 'bold'}},
      {'id': 'footer', 'type': 'text', 'left': 20.0, 'top': 740.0, 'text': 'Modalités de paiement: {{payment_terms}}', 'imagePath': null, 'style': {'fontSize': 11, 'color': '#6B7280'}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_invoice',
    'name': 'Facture (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

// Canvas: Receipt layout
Future<void> _createCanvasReceiptTemplate(Database database) async {
  final canvas = {
    'canvas': [
      {'id': 'logo', 'type': 'placeholder', 'left': 220.0, 'top': 20.0, 'text': '{{company_logo}}', 'imagePath': null, 'style': {'padding': 6}},
      {'id': 'title', 'type': 'text', 'left': 20.0, 'top': 120.0, 'text': 'REÇU DE PAIEMENT', 'imagePath': null, 'style': {'fontSize': 22, 'fontWeight': 'bold', 'color': '#059669'}},
      {'id': 'meta', 'type': 'text', 'left': 20.0, 'top': 160.0, 'text': 'N°: {{receipt_number}}\nDate: {{receipt_date}}\nMatricule: {{student_id}}', 'imagePath': null, 'style': {'fontSize': 11, 'color': '#374151'}},
      {'id': 'body', 'type': 'text', 'left': 20.0, 'top': 220.0, 'text': 'Reçu de : {{payer_name}}\nMatricule : {{student_id}}\nFormation : {{formation_name}}\nMontant: {{amount}} FCFA', 'imagePath': null, 'style': {'fontSize': 13}},
      {'id': 'signature', 'type': 'text', 'left': 20.0, 'top': 620.0, 'text': 'Signature:\n______________________________', 'imagePath': null, 'style': {'fontSize': 12}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_receipt',
    'name': 'Reçu (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

// Canvas: Certificate layout
Future<void> _createCanvasCertificateTemplate(Database database) async {
  final canvas = {
    'canvas': [
      {'id': 'border', 'type': 'text', 'left': 20.0, 'top': 20.0, 'text': '========================================', 'imagePath': null, 'style': {'color': '#9CA3AF'}},
      {'id': 'logo', 'type': 'placeholder', 'left': 260.0, 'top': 60.0, 'text': '{{company_logo}}', 'imagePath': null, 'style': {'padding': 6}},
      {'id': 'title', 'type': 'text', 'left': 120.0, 'top': 160.0, 'text': 'ATTESTATION DE FORMATION', 'imagePath': null, 'style': {'fontSize': 20, 'fontWeight': 'bold', 'color': '#7C3AED'}},
      {'id': 'body', 'type': 'text', 'left': 60.0, 'top': 240.0, 'text': 'Nous attestons que {{student_name}} né(e) le {{birth_date_place}} a suivi la formation {{formation_name}}.\nDurée: {{duration}}\nDate de début: {{start_date}}', 'imagePath': null, 'style': {'fontSize': 13}},
      {'id': 'icon', 'type': 'icon', 'left': 80.0, 'top': 140.0, 'text': '', 'imagePath': null, 'style': {'icon': 'verified', 'color': '#10B981', 'background': '#ECFDF5', 'borderRadius': 8, 'padding': 8}},
      {'id': 'footer', 'type': 'text', 'left': 60.0, 'top': 520.0, 'text': 'Fait le: {{issue_date}}\nSignature:\n______________________________', 'imagePath': null, 'style': {'fontSize': 12}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_certificate',
    'name': 'Attestation (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

// Canvas: Enrollment confirmation layout
Future<void> _createCanvasEnrollmentTemplate(Database database) async {
  final canvas = {
    'canvas': [
      {'id': 'logo', 'type': 'placeholder', 'left': 20.0, 'top': 20.0, 'text': '{{company_logo}}', 'imagePath': null, 'style': {'padding': 6}},
      {'id': 'title', 'type': 'text', 'left': 20.0, 'top': 140.0, 'text': 'CONFIRMATION D\'INSCRIPTION', 'imagePath': null, 'style': {'fontSize': 20, 'fontWeight': 'bold', 'color': '#111827'}},
      {'id': 'body', 'type': 'text', 'left': 20.0, 'top': 200.0, 'text': 'Félicitations {{student_name}}!\nMatricule: {{student_id}}\nVotre inscription à {{formation_name}} est confirmée.\nDémarrage: {{start_date}}\nDurée: {{duration}}', 'imagePath': null, 'style': {'fontSize': 13}},
      {'id': 'footer', 'type': 'text', 'left': 20.0, 'top': 620.0, 'text': 'Merci et à bientôt.', 'imagePath': null, 'style': {'fontSize': 12, 'color': '#6B7280'}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_enrollment',
    'name': 'Inscription (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

// Canvas: Professional Invoice Layout
Future<void> _createNewProfessionalInvoiceTemplate(Database database) async {
  final canvas = {
    'canvas': [
      // Header
      {'id': 'header_background', 'type': 'shape', 'left': 0, 'top': 0, 'width': 595, 'height': 120, 'shape': 'rectangle', 'style': {'color': '#F3F4F6'}},
      {'id': 'logo', 'type': 'placeholder', 'left': 40, 'top': 30, 'text': '{{company_logo}}', 'width': 80, 'height': 80},
      {'id': 'company_details', 'type': 'text', 'left': 150, 'top': 40, 'text': '{{company_name}}\n{{company_address}}\n{{company_phone}}', 'style': {'fontSize': 10, 'color': '#374151'}},
      {'id': 'invoice_title', 'type': 'text', 'left': 380, 'top': 45, 'text': 'FACTURE', 'style': {'fontSize': 32, 'fontWeight': 'bold', 'color': '#111827'}},

      // Bill To Section
      {'id': 'bill_to_title', 'type': 'text', 'left': 40, 'top': 150, 'text': 'FACTURÉ À :', 'style': {'fontSize': 10, 'fontWeight': 'bold', 'color': '#6B7280'}},
      {'id': 'client_details', 'type': 'text', 'left': 40, 'top': 170, 'text': '{{client_name}}\n{{client_address}}\n{{client_phone}} | {{client_email}}', 'style': {'fontSize': 11}},

      // Invoice Meta
      {'id': 'invoice_meta', 'type': 'text', 'left': 380, 'top': 170, 'text': 'Numéro : {{invoice_number}}\nDate : {{invoice_date}}\nÉchéance : {{due_date}}', 'style': {'fontSize': 11, 'align': 'right'}},

      // Table Header
      {'id': 'table_header_bg', 'type': 'shape', 'left': 40, 'top': 240, 'width': 515, 'height': 30, 'shape': 'rectangle', 'style': {'color': '#E5E7EB'}},
      {'id': 'table_header', 'type': 'text', 'left': 50, 'top': 248, 'text': 'Désignation\tQté\tP.U.\tTotal', 'style': {'fontSize': 10, 'fontWeight': 'bold', 'color': '#1F2937'}},

      // Table Body
      {'id': 'table_body', 'type': 'text', 'left': 50, 'top': 280, 'text': '{{#each items}}{{this.designation}}\t{{this.quantity}}\t{{this.unit_price}}\t{{this.total}}\n{{/each}}', 'style': {'fontSize': 11}},

      // Totals Section
      {'id': 'totals_line', 'type': 'shape', 'left': 350, 'top': 500, 'width': 205, 'height': 1, 'shape': 'line', 'style': {'color': '#D1D5DB'}},
      {'id': 'totals', 'type': 'text', 'left': 380, 'top': 520, 'text': 'Sous-total : {{subtotal}}\nRemise : -{{discount}}\nTVA (18%) : {{tax}}\n\nTOTAL : {{total}}', 'style': {'fontSize': 12, 'align': 'right', 'lineHeight': 1.5}},
      {'id': 'total_box', 'type': 'shape', 'left': 350, 'top': 580, 'width': 205, 'height': 40, 'shape': 'rectangle', 'style': {'color': '#E5E7EB'}},
      {'id': 'total_label', 'type': 'text', 'left': 360, 'top': 590, 'text': 'TOTAL', 'style': {'fontSize': 14, 'fontWeight': 'bold'}},
      {'id': 'total_value', 'type': 'text', 'left': 450, 'top': 590, 'text': '{{total}}', 'style': {'fontSize': 14, 'fontWeight': 'bold', 'align': 'right'}},

      // Footer
      {'id': 'footer', 'type': 'text', 'left': 40, 'top': 750, 'text': 'Merci pour votre confiance.\nModalités de paiement : {{payment_terms}}', 'style': {'fontSize': 10, 'color': '#6B7280'}},
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_invoice_pro',
    'name': 'Facture Pro (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}
Future<void> _createCompetenceCertificateTemplate(Database database) async {
  final canvas = {
    'canvas': [
      // En-tête avec logo et informations de contact
      {'id': 'contact_info', 'type': 'text', 'left': 400, 'top': 20, 'text': '{{company_website}}\n{{company_email}}\n{{company_phone}}', 'style': {'fontSize': 10, 'color': '#374151', 'align': 'right'}},
      
      // Logo et nom du cabinet
      {'id': 'logo', 'type': 'placeholder', 'left': 20, 'top': 20, 'text': '{{company_logo}}', 'width': 60, 'height': 60},
      {'id': 'company_name', 'type': 'text', 'left': 90, 'top': 40, 'text': '{{company_name}}', 'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': '#111827'}},
      
      // Titre du directeur
      {'id': 'director_title', 'type': 'text', 'left': 20, 'top': 100, 'text': 'Le Directeur\n{{director_name}}', 'style': {'fontSize': 12, 'fontWeight': 'bold'}},
      
      // Corps principal
      {'id': 'main_text', 'type': 'text', 'left': 20, 'top': 150, 'text': 'Je, soussigné, {{director_title}} {{director_name}}, Directeur du {{company_name}}, certifie que {{participant_title}} {{participant_name}}, détentrice de la {{id_document_type}} n° {{id_number}}, a pris une part active au séminaire de formation sur « {{formation_title}} », qui s\'est tenu du {{start_date}} au {{end_date}}.', 'style': {'fontSize': 12, 'lineHeight': 1.6}},
      
      // Numéro de certificat
      {'id': 'certificate_number', 'type': 'text', 'left': 450, 'top': 240, 'text': 'N° {{certificate_number}}', 'style': {'fontSize': 10, 'fontWeight': 'bold', 'align': 'right'}},
      
      // Nature de l'action
      {'id': 'action_nature_label', 'type': 'text', 'left': 20, 'top': 260, 'text': 'Nature de l\'action concourant au développement des compétences :', 'style': {'fontSize': 11, 'fontWeight': 'bold'}},
      
      // Titre du certificat en gros
      {'id': 'certificate_title', 'type': 'text', 'left': 120, 'top': 290, 'text': 'CERTIFICAT DE COMPETENCE', 'style': {'fontSize': 20, 'fontWeight': 'bold', 'color': '#0B5394', 'align': 'center'}},
      
      // Objectifs de la formation
      {'id': 'objectives_title', 'type': 'text', 'left': 20, 'top': 340, 'text': 'OBJECTIFS DE LA FORMATION', 'style': {'fontSize': 14, 'fontWeight': 'bold', 'color': '#111827'}},
      {'id': 'objectives_intro', 'type': 'text', 'left': 20, 'top': 365, 'text': 'La présente formation vise à doter le bénéficiaire des compétences suivantes :', 'style': {'fontSize': 11}},
      {'id': 'objectives_list', 'type': 'text', 'left': 20, 'top': 385, 'text': '{{#each objectives}}• {{this}}\n{{/each}}', 'style': {'fontSize': 11, 'lineHeight': 1.4}},
      
      // Nature de la formation (tableau)
      {'id': 'nature_title', 'type': 'text', 'left': 20, 'top': 520, 'text': 'NATURE DE LA FORMATION', 'style': {'fontSize': 14, 'fontWeight': 'bold', 'color': '#111827'}},
      {'id': 'nature_table_header', 'type': 'text', 'left': 20, 'top': 545, 'text': 'Action de formation\nAction de bilan de compétences\nAction de formation par apprentissage', 'style': {'fontSize': 11, 'lineHeight': 1.8}},
      {'id': 'nature_checkbox', 'type': 'text', 'left': 200, 'top': 545, 'text': '☑\n☐\n☐', 'style': {'fontSize': 14, 'lineHeight': 1.6}},
      
      // Résultat de la formation
      {'id': 'result_title', 'type': 'text', 'left': 320, 'top': 520, 'text': 'RESULTAT DE LA FORMATION', 'style': {'fontSize': 14, 'fontWeight': 'bold', 'color': '#111827'}},
      {'id': 'result_table_header', 'type': 'text', 'left': 320, 'top': 545, 'text': 'Acquis\t\tPartiellement\t\tNon-acquis', 'style': {'fontSize': 10, 'fontWeight': 'bold'}},
      {'id': 'result_checkbox', 'type': 'text', 'left': 320, 'top': 565, 'text': '☑\t\t\t☐\t\t\t\t☐', 'style': {'fontSize': 14}},
      
      // Lieu et date
      {'id': 'location_date', 'type': 'text', 'left': 20, 'top': 640, 'text': 'Fait à {{location}}, le {{issue_date}}', 'style': {'fontSize': 12, 'fontWeight': 'bold'}},
      
      // Signature
      {'id': 'signature_space', 'type': 'text', 'left': 400, 'top': 680, 'text': 'Signature\n\n\n_______________________', 'style': {'fontSize': 11, 'align': 'center'}}
      ,
      // QR Code for certificate validation / quick reference
      {
        'id': 'qrcode_competence',
        'type': 'qrcode',
        'left': 480,
        'top': 660,
        'width': 80,
        'height': 80,
        'text': 'ID du Certificat : {{certificate_number}}\nApprenant : {{participant_name}}\nFormation : {{formation_title}}\nDate d\'émission : {{issue_date}}\nÉmis par : {{company_name}}\n\nPour vérifier l\'authenticité, visitez :\nhttps://afroforma.com/validation?id={{certificate_number}}'
      }
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_competence_certificate_detailed',
    'name': 'Certificat de Compétence Détaillé (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}
Future<void> _createParticipationCertificateTemplate(Database database) async {
  final canvas = {
    'canvas': [
      // Logo du cabinet
      {'id': 'logo', 'type': 'placeholder', 'left': 20, 'top': 20, 'text': '{{company_logo}}', 'width': 80, 'height': 80},
      
      // Titre principal
      {'id': 'main_title', 'type': 'text', 'left': 180, 'top': 30, 'text': 'ATTESTATION\nDE PARTICIPATION', 'style': {'fontSize': 28, 'fontWeight': 'bold', 'color': '#0B5394', 'align': 'center', 'lineHeight': 1.2}},
      
      // Titre du directeur
      {'id': 'director_section', 'type': 'text', 'left': 20, 'top': 120, 'text': 'Le Directeur\n{{director_name}}', 'style': {'fontSize': 14, 'fontWeight': 'bold', 'color': '#111827'}},
      
      // Corps principal - première partie
      {'id': 'main_text_intro', 'type': 'text', 'left': 20, 'top': 170, 'text': 'Nous, soussignés, {{company_name}} attestons que :', 'style': {'fontSize': 13, 'lineHeight': 1.6}},
      
      // Nom du participant (espace à remplir)
      {'id': 'participant_name_field', 'type': 'text', 'left': 20, 'top': 210, 'text': '{{participant_name}}', 'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': '#111827', 'align': 'center', 'background': '#F9FAFB', 'padding': 10, 'borderRadius': 4}},
      
      // Corps principal - deuxième partie
      {'id': 'main_text_content', 'type': 'text', 'left': 20, 'top': 260, 'text': 'a participé effectivement à la formation de catégorie {{event_type}}, sur le thème :\n\n« {{event_theme}} »,\n\ndu {{start_date}} au {{end_date}}.', 'style': {'fontSize': 13, 'lineHeight': 1.8, 'align': 'justify'}},
      
      // Lieu et date
      {'id': 'location_date', 'type': 'text', 'left': 20, 'top': 420, 'text': 'Fait à {{room}}, le {{issue_date}}', 'style': {'fontSize': 13, 'fontWeight': 'bold'}},
      
      // Formule de clôture
      {'id': 'closing_formula', 'type': 'text', 'left': 20, 'top': 460, 'text': 'En foi de quoi, la présente attestation lui est délivrée pour servir et valoir ce que de droit.', 'style': {'fontSize': 12, 'fontStyle': 'italic', 'color': '#374151'}},
      
      // Zone signature
      {'id': 'signature_label', 'type': 'text', 'left': 400, 'top': 520, 'text': 'Signature', 'style': {'fontSize': 12, 'align': 'center'}},
      {'id': 'signature_line', 'type': 'text', 'left': 350, 'top': 580, 'text': '_________________________', 'style': {'fontSize': 12, 'align': 'center'}},
      
      // Label pour prénoms et nom (en bas)
      {'id': 'name_label', 'type': 'text', 'left': 20, 'top': 650, 'text': 'Prénoms et Nom', 'style': {'fontSize': 11, 'color': '#6B7280'}},
      
      // Bordure décorative (optionnelle)
      {'id': 'decorative_border', 'type': 'shape', 'left': 15, 'top': 15, 'width': 565, 'height': 680, 'shape': 'rectangle', 'style': {'borderColor': '#E5E7EB', 'borderWidth': 2, 'borderRadius': 8, 'fill': 'none'}},
      // QR Code for certificate number
      {
        'id': 'qrcode_attestation',
        'type': 'qrcode',
        'left': 450, // Adjust position as needed
        'top': 600,  // Adjust position as needed
        'width': 80,
        'height': 80,
        'text': 'ID du Certificat : {{certificate_number}}\nApprenant : {{participant_name}}\nFormation : {{event_theme}}\nDate d\'émission : {{issue_date}}\nÉmis par : {{company_name}}\n\nPour vérifier l\'authenticité, visitez :\nhttps://afroforma.com/validation?id={{certificate_number}}' // Data for QR code
      }
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_participation_certificate_detailed',
    'name': 'Attestation de Participation Détaillée (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}
Future<void> _createRegistrationFormTemplate(Database database) async {
  final canvas = {
    'canvas': [
      {'id': 'title', 'type': 'text', 'left': 150, 'top': 50, 'text': 'BULLETIN D\'INSCRIPTION', 'style': {'fontSize': 24, 'fontWeight': 'bold'}},
      {'id': 'body', 'type': 'text', 'left': 50, 'top': 150, 'text': 'Nom: {{student_name}}\nFormation: {{formation_name}}\nDate: {{inscription_date}}', 'style': {'fontSize': 16}},
    ]
  };
  await database.insert('document_templates', {
    'id': 'canvas_registration_form',
    'name': 'Bulletin d\'Inscription (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

Future<void> _createProformaInvoiceTemplate(Database database) async {
  final canvas = {
    'canvas': [
      // En-tête avec informations de contact
      {'id': 'contact_info', 'type': 'text', 'left': 300, 'top': 15, 'text': '{{company_website}}\n{{company_email}}\n{{company_phone}} | {{company_phone_2}}', 'style': {'fontSize': 9, 'color': '#374151', 'align': 'right', 'lineHeight': 1.3}},
      
      // Informations légales
      {'id': 'legal_info', 'type': 'text', 'left': 300, 'top': 55, 'text': 'RCCM : {{rccm_number}}\nNIF : {{nif_number}} CNSS : {{cnss_number}}\nRÉGIME : {{tax_regime}}', 'style': {'fontSize': 8, 'color': '#6B7280', 'align': 'right', 'lineHeight': 1.4}},
      
      // Logo et nom de l'entreprise
      {'id': 'logo', 'type': 'placeholder', 'left': 20, 'top': 20, 'text': '{{company_logo}}', 'width': 80, 'height': 60},
      {'id': 'company_name', 'type': 'text', 'left': 110, 'top': 30, 'text': '{{company_name}}\n{{company_legal_form}}', 'style': {'fontSize': 18, 'fontWeight': 'bold', 'color': '#111827'}},
      
      // Slogan services
      {'id': 'services_slogan', 'type': 'text', 'left': 20, 'top': 90, 'text': '{{services_description}}', 'style': {'fontSize': 10, 'color': '#059669', 'fontWeight': 'bold'}},
      
      // Adresse
      {'id': 'address', 'type': 'text', 'left': 20, 'top': 110, 'text': 'Adresse : {{company_address}}', 'style': {'fontSize': 9, 'color': '#374151'}},
      
      // Titre PROFORMA et métadonnées
      {'id': 'proforma_title', 'type': 'text', 'left': 20, 'top': 150, 'text': 'PROFORMA N° {{proforma_number}}', 'style': {'fontSize': 20, 'fontWeight': 'bold', 'color': '#DC2626'}},
      {'id': 'proforma_meta', 'type': 'text', 'left': 20, 'top': 180, 'text': 'Date d\'émission : {{emission_date}}\nÉchéance : {{due_date}}', 'style': {'fontSize': 11, 'color': '#374151'}},
      
      // Informations client
      {'id': 'client_info', 'type': 'text', 'left': 350, 'top': 150, 'text': 'Client : {{client_name}}\n{{client_title}}\n{{client_email}}\n{{client_phone}}', 'style': {'fontSize': 11, 'color': '#374151', 'lineHeight': 1.4}},
      
      // Objet
      {'id': 'object', 'type': 'text', 'left': 20, 'top': 240, 'text': 'Objet : {{object_description}}', 'style': {'fontSize': 12, 'fontWeight': 'bold', 'color': '#111827'}},
      
      // En-tête du tableau
      {'id': 'table_header', 'type': 'text', 'left': 20, 'top': 280, 'text': 'DÉSIGNATION\t\t\tPrix Unitaire\tQté\tMONTANT\n\t\t\t\t\t\t\ten FCFA', 'style': {'fontSize': 11, 'fontWeight': 'bold', 'background': '#F3F4F6', 'padding': 8}},
      
      // Ligne inscription
      {'id': 'inscription_line', 'type': 'text', 'left': 20, 'top': 320, 'text': 'A- INSCRIPTION', 'style': {'fontSize': 11, 'fontWeight': 'bold'}},
      {'id': 'inscription_details', 'type': 'text', 'left': 20, 'top': 340, 'text': '{{inscription_description}}\t\t{{inscription_price}}\t{{inscription_qty}}\t{{inscription_amount}}', 'style': {'fontSize': 10}},
      {'id': 'subtotal_a', 'type': 'text', 'left': 20, 'top': 360, 'text': 'SOUS TOTAL A (HT)\t\t\t\t\t{{subtotal_a}}', 'style': {'fontSize': 10, 'fontWeight': 'bold'}},
      
      // Ligne participation
      {'id': 'participation_line', 'type': 'text', 'left': 20, 'top': 390, 'text': 'B- PARTICIPATION', 'style': {'fontSize': 11, 'fontWeight': 'bold'}},
      {'id': 'participation_details', 'type': 'text', 'left': 20, 'top': 410, 'text': 'FRAIS DE PARTICIPATION\t\t{{participation_price}}\t{{participation_qty}}\t{{participation_amount}}', 'style': {'fontSize': 10}},
      {'id': 'subtotal_b', 'type': 'text', 'left': 20, 'top': 430, 'text': 'SOUS TOTAL B (HT)\t\t\t\t\t{{subtotal_b}}', 'style': {'fontSize': 10, 'fontWeight': 'bold'}},
      
      // Calculs finaux
      {'id': 'discount_line', 'type': 'text', 'left': 20, 'top': 460, 'text': 'Remise {{discount_percentage}}%', 'style': {'fontSize': 11, 'color': '#059669'}},
      {'id': 'total_line', 'type': 'text', 'left': 20, 'top': 480, 'text': 'TOTAL (A+B)\t\t\t\t\t{{total_before_tax}}', 'style': {'fontSize': 11, 'fontWeight': 'bold'}},
      {'id': 'tax_line', 'type': 'text', 'left': 20, 'top': 500, 'text': 'TVA\t\t\t\t\t\t{{tax_status}}', 'style': {'fontSize': 11}},
      {'id': 'final_amount', 'type': 'text', 'left': 20, 'top': 520, 'text': 'MONTANT À PAYER HT\t\t\t\t{{final_amount}}', 'style': {'fontSize': 12, 'fontWeight': 'bold', 'background': '#FEF3C7', 'padding': 6}},
      
      // Montant en lettres
      {'id': 'amount_in_words', 'type': 'text', 'left': 20, 'top': 560, 'text': 'Arrête la présente à : {{amount_in_words}}', 'style': {'fontSize': 11, 'fontStyle': 'italic'}},
      
      // Moyens de paiement
      {'id': 'payment_method_title', 'type': 'text', 'left': 20, 'top': 600, 'text': 'Moyen de paiement :', 'style': {'fontSize': 11, 'fontWeight': 'bold'}},
      {'id': 'payment_details', 'type': 'text', 'left': 20, 'top': 620, 'text': '{{payment_method}}\n{{payment_number}}', 'style': {'fontSize': 11, 'color': '#059669', 'fontWeight': 'bold'}},
      
      // Bordure du tableau
      {'id': 'table_border', 'type': 'shape', 'left': 15, 'top': 275, 'width': 565, 'height': 280, 'shape': 'rectangle', 'style': {'borderColor': '#E5E7EB', 'borderWidth': 1, 'fill': 'none'}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_proforma_invoice_detailed',
    'name': 'Facture Proforma Détaillée (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}
Future<void> _createInterventionCertificateTemplate(Database database) async {
  final canvas = {
    'canvas': [
      // Logo du cabinet
      {'id': 'logo', 'type': 'placeholder', 'left': 20, 'top': 20, 'text': '{{company_logo}}', 'width': 80, 'height': 80},
      
      // Titre principal
      {'id': 'main_title', 'type': 'text', 'left': 180, 'top': 30, 'text': 'CERTIFICAT\nD\'INTERVENTION', 'style': {'fontSize': 28, 'fontWeight': 'bold', 'color': '#0B5394', 'align': 'center', 'lineHeight': 1.2}},
      
      // Titre du directeur
      {'id': 'director_section', 'type': 'text', 'left': 20, 'top': 120, 'text': 'Le Directeur\n{{director_name}}', 'style': {'fontSize': 14, 'fontWeight': 'bold', 'color': '#111827'}},
      
      // Corps principal - première partie
      {'id': 'main_text_intro', 'type': 'text', 'left': 20, 'top': 170, 'text': 'Nous, soussignés, {{company_name}} attestons que :', 'style': {'fontSize': 13, 'lineHeight': 1.6}},
      
      // Nom de l'intervenant (espace à remplir)
      {'id': 'intervenant_name_field', 'type': 'text', 'left': 20, 'top': 210, 'text': '{{intervenant_name}}', 'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': '#111827', 'align': 'center', 'background': '#F9FAFB', 'padding': 10, 'borderRadius': 4}},
      
      // Corps principal - détails de l'intervention
      {'id': 'intervention_details', 'type': 'text', 'left': 20, 'top': 260, 'text': 'a effectué une séance de formation sur la thématique suivante : « {{intervention_theme}} » par {{intervention_mode}} le {{intervention_date}}, dans le cadre de notre formation sur le thème général "{{general_theme}}" du {{training_start_date}} au {{training_end_date}}.', 'style': {'fontSize': 13, 'lineHeight': 1.8, 'align': 'justify'}},
      
      // Lieu et date
      {'id': 'location_date', 'type': 'text', 'left': 20, 'top': 420, 'text': 'Fait à {{location}}, le {{issue_date}}', 'style': {'fontSize': 13, 'fontWeight': 'bold'}},
      
      // Formule de clôture
      {'id': 'closing_formula', 'type': 'text', 'left': 20, 'top': 460, 'text': 'En foi de quoi, le présent certificat lui est délivré pour servir et valoir ce que de droit.', 'style': {'fontSize': 12, 'fontStyle': 'italic', 'color': '#374151'}},
      
      // Nom de l'intervenant en bas (signature)
      {'id': 'intervenant_signature_name', 'type': 'text', 'left': 20, 'top': 520, 'text': '{{intervenant_full_name}}', 'style': {'fontSize': 13, 'fontWeight': 'bold'}},
      
      // Zone signature du directeur
      {'id': 'director_signature_label', 'type': 'text', 'left': 400, 'top': 520, 'text': 'Signature du Directeur', 'style': {'fontSize': 12, 'align': 'center'}},
      {'id': 'director_signature_line', 'type': 'text', 'left': 350, 'top': 580, 'text': '_________________________', 'style': {'fontSize': 12, 'align': 'center'}},
      
      // Bordure décorative
      {'id': 'decorative_border', 'type': 'shape', 'left': 15, 'top': 15, 'width': 565, 'height': 680, 'shape': 'rectangle', 'style': {'borderColor': '#E5E7EB', 'borderWidth': 2, 'borderRadius': 8, 'fill': 'none'}},
      
      // Ligne décorative sous le titre
      {'id': 'title_underline', 'type': 'shape', 'left': 150, 'top': 100, 'width': 300, 'height': 2, 'shape': 'line', 'style': {'color': '#0B5394'}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_intervention_certificate_detailed',
    'name': 'Certificat d\'Intervention Détaillé (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}

Future<void> _createKEmpireBulletinInscriptionTemplate(Database database) async {
  final canvas = {
    'canvas': [
      // En-tête entreprise
      {'id': 'company_header', 'type': 'text', 'left': 40, 'top': 20, 'text': 'K-EMPIRE CORPORATION Sarl U au capital de 1 000 000 FCFA\nRCCM : TG-LRL-01-2024-B13-00035\nRÉGIME : Réel avec TVA\nSiège social : DONGOYO, KARA\nTéléphone : +228 92 66 45 50 / +221 78 149 29 98\nE-mail : contact@k-empirecorporation.com\nSite web : www.k-empirecorporation.com', 'style': {'fontSize': 9, 'color': '#374151', 'lineHeight': 1.3}},

      // Titre principal
      {'id': 'main_title', 'type': 'text', 'left': 200, 'top': 120, 'text': 'BULLETIN D\'INSCRIPTION', 'style': {'fontSize': 18, 'fontWeight': 'bold', 'color': '#111827'}},
      {'id': 'subtitle', 'type': 'text', 'left': 170, 'top': 145, 'text': 'CE BULLETIN D\'INSCRIPTION VAUT BON DE COMMANDE', 'style': {'fontSize': 10, 'color': '#6B7280'}},

      // Section IDENTIFICATION DU SÉMINAIRE
      {'id': 'seminar_section_bg', 'type': 'shape', 'left': 40, 'top': 170, 'width': 515, 'height': 25, 'shape': 'rectangle', 'style': {'color': '#E5E7EB'}},
      {'id': 'seminar_section_title', 'type': 'text', 'left': 50, 'top': 178, 'text': 'IDENTIFICATION DU SÉMINAIRE', 'style': {'fontSize': 12, 'fontWeight': 'bold', 'color': '#111827'}},
      
      {'id': 'seminar_details', 'type': 'text', 'left': 50, 'top': 205, 'text': 'Code (Réf) : {{formation_code}}\nLieu choisi : {{formation_location}}\nThème de la formation : {{formation_theme}}\nDate de la formation Du {{start_date}} au {{end_date}} / 2025\nCoût de la formation (HT) : {{formation_cost_ht}} FCFA', 'style': {'fontSize': 11, 'lineHeight': 1.5}},

      // Section IDENTIFICATION DU CLIENT
      {'id': 'client_section_bg', 'type': 'shape', 'left': 40, 'top': 310, 'width': 515, 'height': 25, 'shape': 'rectangle', 'style': {'color': '#E5E7EB'}},
      {'id': 'client_section_title', 'type': 'text', 'left': 50, 'top': 318, 'text': 'IDENTIFICATION DU CLIENT', 'style': {'fontSize': 12, 'fontWeight': 'bold', 'color': '#111827'}},
      
      {'id': 'client_details', 'type': 'text', 'left': 50, 'top': 345, 'text': 'Raison sociale : {{company_name}}\nSecteur d\'activité : {{activity_sector}}\nAdresse de facturation : {{billing_address}}\nE-mail : {{client_email}}\nTéléphone : {{client_phone}}\nIdentité du signataire : {{signatory_name}}\nCode postale : {{postal_code}}', 'style': {'fontSize': 11, 'lineHeight': 1.5}},

      // Section IDENTIFICATION DES PARTICIPANTS
      {'id': 'participants_section_bg', 'type': 'shape', 'left': 40, 'top': 480, 'width': 515, 'height': 25, 'shape': 'rectangle', 'style': {'color': '#E5E7EB'}},
      {'id': 'participants_section_title', 'type': 'text', 'left': 50, 'top': 488, 'text': 'IDENTIFICATION DES PARTICIPANTS', 'style': {'fontSize': 12, 'fontWeight': 'bold', 'color': '#111827'}},
      
      {'id': 'participants_table_header', 'type': 'text', 'left': 50, 'top': 515, 'text': 'Nom et Prénom(s)\tFonction\tContact\tMontant HT', 'style': {'fontSize': 10, 'fontWeight': 'bold'}},
      {'id': 'participants_table', 'type': 'text', 'left': 50, 'top': 535, 'text': '{{#each participants}}{{this.name}}\t{{this.function}}\t{{this.contact}}\t{{this.amount_ht}}\n{{/each}}', 'style': {'fontSize': 10, 'lineHeight': 1.8}},

      // Totaux
      {'id': 'totals_section', 'type': 'text', 'left': 350, 'top': 580, 'text': 'Coût de la formation Total HT : {{total_ht}} FCFA\nRemise : {{discount}} FCFA\nTVA (18%) : {{tax_amount}} FCFA\nTotal TTC : {{total_ttc}} FCFA', 'style': {'fontSize': 11, 'fontWeight': 'bold', 'align': 'right', 'lineHeight': 1.5}},

      // Section RÈGLEMENT
      {'id': 'payment_section_bg', 'type': 'shape', 'left': 40, 'top': 650, 'width': 515, 'height': 25, 'shape': 'rectangle', 'style': {'color': '#E5E7EB'}},
      {'id': 'payment_section_title', 'type': 'text', 'left': 50, 'top': 658, 'text': 'RÈGLEMENT - CONDITIONS DE RÈGLEMENT 100% AVANT LA FORMATION', 'style': {'fontSize': 12, 'fontWeight': 'bold', 'color': '#111827'}},
      
      {'id': 'payment_details', 'type': 'text', 'left': 50, 'top': 685, 'text': 'K-EMPIRE CORPORATION TOGO\nDomiciliation : BIA TOGO - ATTIJARI WAFA 01 BP 346 Lomé\nChèque ou virement à l\'ordre de K-EMPIRE CORPORATION', 'style': {'fontSize': 10, 'lineHeight': 1.4}},
      
      {'id': 'bank_details_header', 'type': 'text', 'left': 50, 'top': 730, 'text': 'VIREMENT BANCAIRE :', 'style': {'fontSize': 10, 'fontWeight': 'bold'}},
      {'id': 'bank_details', 'type': 'text', 'left': 50, 'top': 745, 'text': 'Code banque: TG005 | Code Guichet: 02255 | N° Compte: 000536804146 | Clé RIB: 38 | Swift: BILTTGTG\nCompte tenu des délais des virements internationaux, nous vous prions de bien vouloir ordonner\nvos virements au plus tard 15 jours avant le début de la formation.', 'style': {'fontSize': 9, 'lineHeight': 1.3}},
      
      {'id': 'transfer_info', 'type': 'text', 'left': 50, 'top': 785, 'text': 'TRANSFERT MONÉTAIRE :\nVous pouvez utiliser les services Western Union ou Money gram ou transfert mobile pour le\npaiement de vos frais de participation, les frais à votre charge.', 'style': {'fontSize': 9, 'lineHeight': 1.3}},

      // Section signature
      {'id': 'signature_section', 'type': 'text', 'left': 50, 'top': 820, 'text': 'Fait à : {{location}}, le {{signature_date}}\n\nSignature et cachet du 1er responsable de l\'entité\n\n\n______________________________', 'style': {'fontSize': 10, 'lineHeight': 1.5}},
      
      {'id': 'declaration', 'type': 'text', 'left': 50, 'top': 880, 'text': 'Je déclare avoir pris connaissance et accepté les conditions générales de vente figurant au verso et faisant partie intégrante de ce bulletin', 'style': {'fontSize': 8, 'color': '#6B7280'}},

      // Instructions retour
      {'id': 'return_instructions', 'type': 'text', 'left': 350, 'top': 820, 'text': 'Nous retourner ce bulletin d\'inscription,\ndûment rempli, signé et cacheté,\naccompagné du règlement.', 'style': {'fontSize': 10, 'color': '#059669', 'fontWeight': 'bold', 'align': 'center', 'background': '#ECFDF5', 'padding': 8, 'borderRadius': 6}}
    ]
  };

  await database.insert('document_templates', {
    'id': 'canvas_bulletin_inscription_kempire',
    'name': 'Bulletin d\'Inscription K-Empire (Canvas)',
    'type': 'canvas',
    'content': jsonEncode(canvas),
    'lastModified': DateTime.now().millisecondsSinceEpoch,
  });
}