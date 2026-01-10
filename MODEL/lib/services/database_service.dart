import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:afroforma/models/document.dart';
import 'package:afroforma/models/formateur.dart';
import 'package:afroforma/models/formation.dart';
import 'package:afroforma/models/inscription.dart';
import 'package:afroforma/models/session.dart';
import 'package:afroforma/models/student.dart';
import 'package:afroforma/models/user.dart';
import 'package:afroforma/screen/parametres/models.dart';
import 'package:afroforma/services/plan_parser.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:afroforma/services/logger.dart';
import 'package:afroforma/services/chart_of_accounts.dart';
import 'package:afroforma/services/default_canvas_templates.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Single, cleaned DatabaseService implementation.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;


  Future<void> _insertDefaultTemplatesIfMissing(Database database) async {
    final existing = await database.query('document_templates');
    if (existing.isNotEmpty) return; // templates already present

    // Insert a set of modern, styled templates. Keep inserts simple (id,name,type,content,lastModified)
    await _createModernInvoiceTemplate(database);
    await _createModernReceiptTemplate(database);
    await _createPremiumCertificateTemplate(database);
    await _createEnrollmentTemplate(database);
    await _createPaymentReminderTemplate(database);
    await _createSessionConfirmationTemplate(database);
    await insertDefaultCanvasTemplates(database);
  }

  // Helper: modern invoice
  Future<void> _createModernInvoiceTemplate(Database database) async {
    final content = jsonEncode([
      {'insert': '{{company_logo}}\n\n'},
      {'insert': 'FACTURE', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': '\n'},
      {'insert': '{{company_name}}\n{{company_address}}\nTél: {{company_phone}}\n\n', 'attributes': {'italic': true}},
  {'insert': 'INFORMATIONS CLIENT\n', 'attributes': {'bold': true}},
  {'insert': 'Nom: {{client_name}}\nMatricule: {{student_id}}\nAdresse: {{client_address}}\nContact: {{client_phone}} | {{client_email}}\n\n'},
      {'insert': 'DÉTAILS FACTURE\n', 'attributes': {'bold': true}},
      {'insert': 'N° Facture: {{invoice_number}}\nDate: {{invoice_date}}\nÉchéance: {{due_date}}\n\n'},
      {'insert': 'DESIGNATION\tQTÉ\tPRIX UNIT.\tTOTAL\n', 'attributes': {'bold': true}},
      {'insert': '-----------------------------------------------'},
      {'insert': '\n'},
      {'insert': 'Formation {{formation_name}}\t1\t{{unit_price}}\t{{line_total}}\n'},
      {'insert': '\n'},
      {'insert': 'Sous-total HT:\t{{subtotal}}\n'},
      {'insert': 'Remise:\t-{{discount}}\n'},
      {'insert': 'TVA (18%):\t{{tax}}\n'},
      {'insert': 'TOTAL TTC:\t{{total}}\n\n', 'attributes': {'bold': true}},
      {'insert': 'Modalités de paiement:\n{{payment_terms}}\n\n'},
      {'insert': 'Signature:\n\n______________________________\n'}
    ]);

    await database.insert('document_templates', {
      'id': 'modern_invoice',
      'name': 'Facture Moderne',
      'type': 'facture',
      'content': content,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Helper: modern receipt
  Future<void> _createModernReceiptTemplate(Database database) async {
    final content = jsonEncode([
      {'insert': '{{company_logo}}\n\n'},
      {'insert': 'REÇU DE PAIEMENT', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': '\n'},
  {'insert': 'N° {{receipt_number}}\nDate: {{receipt_date}}\n\n', 'attributes': {'align': 'right'}},
  {'insert': 'REÇU DE : {{payer_name}}\nMatricule : {{student_id}}\nFormation : {{formation_name}}\nMontant: {{amount}} FCFA\n\n'},
      {'insert': 'Signature:\n\n______________________________\n'},
      {'insert': '\nMerci pour votre paiement.\n'}
    ]);

    await database.insert('document_templates', {
      'id': 'modern_receipt',
      'name': 'Reçu Moderne',
      'type': 'recu',
      'content': content,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Helper: premium certificate
  Future<void> _createPremiumCertificateTemplate(Database database) async {
    final content = jsonEncode([
  {'insert': '========================================\n', 'attributes': {'align': 'center'}},
      {'insert': '{{company_logo}}\n\n'},
      {'insert': 'ATTESTATION DE FORMATION', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': '\n'},
  {'insert': 'Nous attestons que {{student_name}} (Matricule: {{student_id}}) a suivi la formation {{formation_name}}.\n\n'},
      {'insert': 'Durée : {{duration}} heures\nPériode : {{start_date}} - {{end_date}}\n\n'},
      {'insert': 'Fait le: {{issue_date}}\nNuméro de certificat: {{certificate_number}}\n\n'},
      {'insert': 'Signature:\n\n______________________________\n'},
      // QR Code for certificate number
      {'insert': '\n'},
      {'insert': '{{qrcode:certificate_number}}', 'attributes': {'type': 'qrcode', 'width': 80, 'height': 80, 'align': 'center', 'text': '{{certificate_number}}'}},
      {'insert': '\n'}
    ]);

    await database.insert('document_templates', {
      'id': 'premium_certificate',
      'name': 'Attestation Premium',
      'type': 'attestation',
      'content': content,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Helper: enrollment confirmation
  Future<void> _createEnrollmentTemplate(Database database) async {
    final content = jsonEncode([
  {'insert': '{{company_logo}}\n\n'},
  {'insert': 'CONFIRMATION D\'INSCRIPTION', 'attributes': {'header': 1, 'align': 'center'}},
  {'insert': '\n'},
  {'insert': 'Félicitations {{student_name}} (Matricule: {{student_id}}) ! Votre inscription à {{formation_name}} est confirmée.\n\n'},
  {'insert': 'Détails :\nDémarrage : {{start_date}}\nDurée : {{duration}}\nLieu : {{location}}\n\n'},
  {'insert': 'Merci et à bientôt.\n'}
    ]);

    await database.insert('document_templates', {
      'id': 'enrollment_confirmation',
      'name': 'Confirmation d\'inscription',
      'type': 'inscription',
      'content': content,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Helper: payment reminder
  Future<void> _createPaymentReminderTemplate(Database database) async {
    final content = jsonEncode([
      {'insert': '{{company_logo}}\n\n'},
      {'insert': 'RAPPEL DE PAIEMENT', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': '\n'},
      {'insert': 'Cher(e) {{student_name}},\n\nNous vous rappelons que le paiement pour {{formation_name}} est en attente.\nMontant dû : {{amount_due}} FCFA\nDate d\'échéance : {{due_date}}\n\n'},
      {'insert': 'Merci de régulariser au plus vite.\nSignature:\n\n______________________________\n'}
    ]);

    await database.insert('document_templates', {
      'id': 'payment_reminder',
      'name': 'Relance de Paiement',
      'type': 'relance',
      'content': content,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Helper: session confirmation (simple)
  Future<void> _createSessionConfirmationTemplate(Database database) async {
    final content = jsonEncode([
      {'insert': '{{company_logo}}\n\n'},
      {'insert': 'CONFIRMATION DE SESSION', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': '\n'},
      {'insert': 'La session {{session_name}} a été programmée pour le {{session_date}} à {{session_location}}.\n\n'},
      {'insert': 'Merci de votre participation.\n'}
    ]);

    await database.insert('document_templates', {
      'id': 'session_confirmation',
      'name': 'Confirmation de Session',
      'type': 'session',
      'content': content,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    });
  }

  

  Future<Database> get db async {
    if (_db != null) return _db!;
    await init();
    return _db!;
  }

  Future<void> init({String? dbPath, bool useInMemory = false}) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
    }

    String pathToOpen;
    if (useInMemory) {
      pathToOpen = ':memory:';
    } else if (dbPath != null) {
      pathToOpen = dbPath;
    } else {
      final documents = await getApplicationDocumentsDirectory();
      pathToOpen = p.join(documents.path, 'afroforma.db');
    }

    final dbFactory = (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
        ? databaseFactoryFfi
        : databaseFactory;

    _db = await dbFactory.openDatabase(
      pathToOpen,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE formations (
              id TEXT PRIMARY KEY,
              title TEXT,
              description TEXT,
              duration TEXT,
              price REAL,
              imageUrl TEXT,
              category TEXT,
              level TEXT,
              isActive INTEGER,
              objectives TEXT,
              prerequisites TEXT,
              pedagogicalDocuments TEXT,
              enrolledStudents INTEGER,
              revenue REAL,
              directCosts REAL,
              indirectCosts REAL,
              isArchived INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE formateurs (
              id TEXT PRIMARY KEY,
              formationId TEXT,
              name TEXT,
              speciality TEXT,
              hourlyRate REAL,
              avatar TEXT,
              photo TEXT,
              email TEXT,
              phone TEXT,
              address TEXT,
              isArchived INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE sessions (
              id TEXT PRIMARY KEY,
              formationId TEXT,
              name TEXT,
              startDate INTEGER,
              endDate INTEGER,
              start INTEGER,
              "end" INTEGER,
              room TEXT,
              formateurId TEXT,
              maxCapacity INTEGER,
              currentEnrollments INTEGER,
              status TEXT,
              isArchived INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              formationId TEXT,
              studentId TEXT,
              title TEXT,
              category TEXT,
              fileName TEXT,
              path TEXT,
              mimeType TEXT,
              size INTEGER,
              uploadedAt INTEGER,
              isArchived INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE etudiants (
              id TEXT PRIMARY KEY,
              name TEXT,
              photo TEXT,
              address TEXT,
              formation TEXT,
              paymentStatus TEXT,
              phone TEXT,
              email TEXT,
              dateNaissance TEXT,
              lieuNaissance TEXT,
              idDocumentType TEXT,
              idNumber TEXT,
              participantTitle TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE session_formateurs (
              sessionId TEXT,
              formateurId TEXT,
              PRIMARY KEY(sessionId, formateurId)
            )
          ''');
          await db.execute('''
            CREATE TABLE inscriptions (
              id TEXT PRIMARY KEY,
              studentId TEXT,
              formationId TEXT,
              sessionId TEXT, -- New field
              inscriptionDate INTEGER,
              status TEXT,
              finalGrade REAL,
              certificatePath TEXT,
              discountPercent REAL,
              FOREIGN KEY (studentId) REFERENCES etudiants(id),
              FOREIGN KEY (formationId) REFERENCES formations(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE student_payments (
              id TEXT PRIMARY KEY,
              studentId TEXT,
              inscriptionId TEXT,
              formationId TEXT,
              amount REAL,
              method TEXT,
              note TEXT,
              isCredit INTEGER DEFAULT 0,
              createdAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE communications (
              id TEXT PRIMARY KEY,
              studentId TEXT,
              type TEXT,
              channel TEXT,
              subject TEXT,
              body TEXT,
              createdAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              name TEXT,
              email TEXT,
              role INTEGER,
              passwordHash TEXT, -- New field for password hash
              permissions TEXT, -- Stored as JSON string
              createdAt INTEGER,
              lastLogin INTEGER,
              isActive INTEGER
            )
          ''');
          await db.execute('''
                        CREATE TABLE company_info (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              address TEXT,
              phone TEXT,
              email TEXT,
              rccm TEXT,
              nif TEXT,
              website TEXT,
              logoPath TEXT,
              autoBackup INTEGER DEFAULT 0,
              backupFrequency TEXT DEFAULT 'Quotidienne',
              retentionDays INTEGER DEFAULT 30,
              exercice TEXT,
              monnaie TEXT,
              planComptable TEXT,
              directorName TEXT,
              location TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE document_templates (
              id TEXT PRIMARY KEY,
              name TEXT,
              type TEXT,
              content TEXT,
              lastModified INTEGER
            )
          ''');

          // Table to hold remote-distributed update info (simple approach)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_update (
              id TEXT PRIMARY KEY,
              version TEXT,
              platform TEXT,
              url TEXT,
              notes TEXT,
              force INTEGER DEFAULT 0,
              publishedAt INTEGER
            )
          ''');

          // After creating tables, apply lightweight migrations (safe best-effort)
          try {
            await _applyMigrations(db);
          } catch (_) {}

          // Diagnostics table to track image insertions and mismatches
          await db.execute('''
            CREATE TABLE IF NOT EXISTS image_diagnostics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              inserted_path TEXT,
              file_exists INTEGER,
              created_at INTEGER
            )
          ''');

          // Insert default template
          final defaultInvoiceContent = jsonEncode([
            {'insert': 'Facture', 'attributes': {'header': 1, 'align': 'center'}},
            {'insert': '\n'},
            {'insert': 'Nom du client', 'attributes': {'bold': true}},
            {'insert': ' : ________________\n'},
            {'insert': 'Date', 'attributes': {'bold': true}},
            {'insert': ' : ________________\n\n'},
            {'insert': 'Description', 'attributes': {'bold': true, 'italic': true}},
            {'insert': '\n'},
            {'insert': 'Montant', 'attributes': {'bold': true, 'italic': true}},
            {'insert': '\n\n\n'},
            {'insert': 'Merci de votre confiance.\n'}
          ]);

          await db.insert('document_templates', {
            'id': 'default_invoice',
            'name': 'Facture Simple',
            'type': 'facture',
            'content': defaultInvoiceContent,
            'lastModified': DateTime.now().millisecondsSinceEpoch
          });

          // Generic invoices table (for services, receipts not tied to inscriptions)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS invoices (
              id TEXT PRIMARY KEY,
              number TEXT,
              clientName TEXT,
              description TEXT,
              amount REAL,
              currency TEXT,
              date INTEGER,
              dueDate INTEGER,
              status TEXT,
              isInscription INTEGER DEFAULT 0,
              relatedInscriptionId TEXT,
              createdAt INTEGER
            )
          ''');

          // Comptabilité: journaux, plan comptable, écritures
          await db.execute('''
            CREATE TABLE IF NOT EXISTS journaux (
              id TEXT PRIMARY KEY,
              code TEXT,
              name TEXT,
              description TEXT,
              type TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS plan_comptable (
              id TEXT PRIMARY KEY,
              code TEXT,
              title TEXT,
              parentId TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS ecritures_comptables (
              id TEXT PRIMARY KEY,
              pieceId TEXT,
              pieceNumber TEXT,
              date INTEGER,
              journalId TEXT,
              reference TEXT,
              accountCode TEXT,
              label TEXT,
              debit REAL,
              credit REAL,
              lettrageId TEXT,
              createdAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS numerotation (
              journalId TEXT PRIMARY KEY,
              lastNumber INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS lettrages (
              id TEXT PRIMARY KEY,
              label TEXT,
              createdAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS entry_templates (
              id TEXT PRIMARY KEY,
              name TEXT,
              content TEXT,
              defaultJournalId TEXT,
              createdAt INTEGER,
              updatedAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS favorite_accounts (
              code TEXT PRIMARY KEY,
              createdAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_prefs (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('DB onUpgrade: from $oldVersion to $newVersion');
          // Apply known schema upgrades
          if (oldVersion < 2) {
            try {
              await db.execute('ALTER TABLE company_info ADD COLUMN academic_year TEXT');
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE company_info ADD COLUMN directorName TEXT');
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE company_info ADD COLUMN location TEXT');
            } catch (_) {}
          }
          if (oldVersion < 3) {
            try {
              await db.execute('ALTER TABLE inscriptions ADD COLUMN sessionId TEXT');
            } catch (_) {}
          }

          // Ensure documents table has our new columns
          await _applyMigrations(db);
        },
      ),
    );

    await _ensureSchema(_db!);
    // Ensure default document templates exist (for fresh and upgraded DBs)
    await _insertDefaultTemplatesIfMissing(_db!);
    // Force reset of default templates for development/testing
    await resetDefaultTemplates();
    // Seed default accounting journals if missing
    await insertDefaultJournauxIfMissing();
    // Insert large chart of accounts in background to avoid blocking UI on first run.
    // Use compute to parse heavy text in an isolate, then insert in batches.
    Future.microtask(() async {
      try {
        await insertDefaultChartOfAccountsIfMissing(_db!);
      } catch (e) {
        AppLogger.error('background chart insertion failed: $e');
      }
    });
    // Defensive: ensure accounting tables exist for older DBs that predate these migrations
    try {
      final comp = await _db!.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='journaux'");
      if (comp.isEmpty) {
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS journaux (
            id TEXT PRIMARY KEY,
            code TEXT,
            name TEXT,
            description TEXT,
            type TEXT
          )
        ''');

        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS plan_comptable (
            id TEXT PRIMARY KEY,
            code TEXT,
            title TEXT,
            parentId TEXT
          )
        ''');

        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS ecritures_comptables (
            id TEXT PRIMARY KEY,
            pieceId TEXT,
            pieceNumber TEXT,
            date INTEGER,
            journalId TEXT,
            reference TEXT,
            accountCode TEXT,
            label TEXT,
            debit REAL,
            credit REAL,
            lettrageId TEXT,
            createdAt INTEGER
          )
        ''');

        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS numerotation (
            journalId TEXT PRIMARY KEY,
            lastNumber INTEGER
          )
        ''');

        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS lettrages (
            id TEXT PRIMARY KEY,
            label TEXT,
            createdAt INTEGER
          )
        ''');
      }
    } catch (_) {
      // best-effort: if anything fails here, we'll let higher-level calls handle errors
    }
  }

  Future<void> _ensureSchema(Database database) async {
    Future<Set<String>> existingColumns(String table) async {
      try {
        final info = await database.rawQuery('PRAGMA table_info($table)');
        return info.map((r) => (r['name'] as String).toLowerCase()).toSet();
      } catch (_) {
        return {}; // table does not exist
      }
    }

    final formCols = await existingColumns('formateurs');
    if (formCols.isNotEmpty) {
      final formNeeded = {
        'speciality': 'TEXT',
        'hourlyRate': 'REAL',
        'avatar': 'TEXT',
        'photo': 'TEXT',
        'email': 'TEXT',
        'phone': 'TEXT',
        'address': 'TEXT',
        'isArchived': 'INTEGER DEFAULT 0',
      };
      for (final e in formNeeded.entries) {
        if (!formCols.contains(e.key.toLowerCase())) {
          await database.execute('ALTER TABLE formateurs ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    // ensure communications table exists for older DBs
    final commCols = await existingColumns('communications');
    if (commCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS communications (
          id TEXT PRIMARY KEY,
          studentId TEXT,
          type TEXT,
          channel TEXT,
          subject TEXT,
          body TEXT,
          createdAt INTEGER
        )
      ''');
    }

    // ensure users table exists for older DBs
    final userCols = await existingColumns('users');
      if (userCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          name TEXT,
          email TEXT,
          role INTEGER,
          passwordHash TEXT,
          permissions TEXT,
          createdAt INTEGER,
          lastLogin INTEGER,
          isActive INTEGER,
          is2faEnabled INTEGER DEFAULT 0,
          twoFaSecret TEXT
        )
      ''');
    } else { // Table exists, check for missing columns
      if (!userCols.contains('passwordhash')) {
        await database.execute('ALTER TABLE users ADD COLUMN passwordHash TEXT');
      }
      if (!userCols.contains('mustchangepassword')) {
        try {
          await database.execute('ALTER TABLE users ADD COLUMN mustChangePassword INTEGER DEFAULT 0');
        } catch (_) {}
      }
      // Also ensure permissions is TEXT, if it was something else before
      // This might be more complex if permissions was stored differently,
      // but for now, assuming it was either missing or already TEXT.
      if (!userCols.contains('permissions')) {
        await database.execute('ALTER TABLE users ADD COLUMN permissions TEXT');
      }
      if (!userCols.contains('is2faenabled')) {
        try {
          await database.execute('ALTER TABLE users ADD COLUMN is2faEnabled INTEGER DEFAULT 0');
        } catch (_) {}
      }
      if (!userCols.contains('twofasecret')) {
        try {
          await database.execute('ALTER TABLE users ADD COLUMN twoFaSecret TEXT');
        } catch (_) {}
      }
    }

    // ensure audit_logs table exists for older DBs
    final auditCols = await existingColumns('audit_logs');
    if (auditCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id TEXT PRIMARY KEY,
          userId TEXT,
          userName TEXT,
          action TEXT,
          module TEXT,
          timestamp INTEGER,
          details TEXT
        )
      ''');
    }

    // ensure company_info table exists for older DBs
    final companyInfoCols = await existingColumns('company_info');
    if (companyInfoCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS company_info (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          address TEXT,
          phone TEXT,
          email TEXT,
          rccm TEXT,
          nif TEXT,
          website TEXT,
          logoPath TEXT,
          autoBackup INTEGER DEFAULT 0,
          backupFrequency TEXT DEFAULT 'Quotidienne',
          retentionDays INTEGER DEFAULT 30,
          exercice TEXT,
          monnaie TEXT,
          planComptable TEXT
        )
      ''');
    } else { // Table exists, check for missing columns
      final companyInfoNeeded = {
        'autoBackup': 'INTEGER DEFAULT 0',
        'backupFrequency': 'TEXT DEFAULT \'Quotidienne\'',
        'retentionDays': 'INTEGER DEFAULT 30',
        'exercice': 'TEXT',
        'monnaie': 'TEXT',
        'planComptable': 'TEXT',
        'academic_year': 'TEXT',
        'targetRevenue': 'REAL DEFAULT 0.0', // New column for target revenue
        'directorName': 'TEXT',
        'location': 'TEXT',
      };
      for (final e in companyInfoNeeded.entries) {
        if (!companyInfoCols.contains(e.key.toLowerCase())) {
          await database.execute('ALTER TABLE company_info ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    // ensure document_templates table exists for older DBs
    final docTemplatesCols = await existingColumns('document_templates');
    if (docTemplatesCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS document_templates (
          id TEXT PRIMARY KEY,
          name TEXT,
          type TEXT,
          content TEXT,
          lastModified INTEGER
        )
      ''');
    }

    // ensure invoices table exists for older DBs
    final invoiceCols = await existingColumns('invoices');
    if (invoiceCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS invoices (
          id TEXT PRIMARY KEY,
          number TEXT,
          clientName TEXT,
          description TEXT,
          amount REAL,
          currency TEXT,
          date INTEGER,
          dueDate INTEGER,
          status TEXT,
          isInscription INTEGER DEFAULT 0,
          relatedInscriptionId TEXT,
          createdAt INTEGER
        )
      ''');
    }

    final formationCols = await existingColumns('formations');
    if (formationCols.isNotEmpty) {
      final formationNeeded = {
        'pedagogicalDocuments': 'TEXT',
        'enrolledStudents': 'INTEGER',
        'revenue': 'REAL',
        'directCosts': 'REAL',
        'indirectCosts': 'REAL',
        'isArchived': 'INTEGER DEFAULT 0',
      };
      for (final e in formationNeeded.entries) {
        if (!formationCols.contains(e.key.toLowerCase())) {
          await database.execute('ALTER TABLE formations ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    final sessionCols = await existingColumns('sessions');
    if (sessionCols.isNotEmpty) {
      final sessionNeeded = {
        'startDate': 'INTEGER',
        'endDate': 'INTEGER',
        'start': 'INTEGER',
        'name': 'TEXT',
        'end': 'INTEGER',
        'formateurId': 'TEXT',
        'maxCapacity': 'INTEGER',
        'currentEnrollments': 'INTEGER',
        'status': 'TEXT',
        'isArchived': 'INTEGER DEFAULT 0',
      };
      for (final e in sessionNeeded.entries) {
        if (!sessionCols.contains(e.key.toLowerCase())) {
          await database.execute('ALTER TABLE sessions ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    final docCols = await existingColumns('documents');
    if (docCols.isEmpty) {
      await database.execute('''
        CREATE TABLE documents (
          id TEXT PRIMARY KEY,
          formationId TEXT,
          studentId TEXT,
          title TEXT,
          category TEXT,
          fileName TEXT,
          path TEXT,
          mimeType TEXT,
          size INTEGER,
          uploadedAt INTEGER,
          isArchived INTEGER DEFAULT 0
        )
      ''');
    } else {
      final docNeeded = {
        'fileName': 'TEXT',
        'path': 'TEXT',
        'mimeType': 'TEXT',
        'size': 'INTEGER',
        'uploadedAt': 'INTEGER',
        'isArchived': 'INTEGER DEFAULT 0',
        'studentId': 'TEXT',
        'title': 'TEXT',
        'category': 'TEXT',
      };
      for (final e in docNeeded.entries) {
        if (!docCols.contains(e.key.toLowerCase())) {
          await database.execute('ALTER TABLE documents ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    final joinInfo = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='session_formateurs'");
    if (joinInfo.isEmpty) {
      await database.execute('''
        CREATE TABLE session_formateurs (
          sessionId TEXT,
          formateurId TEXT,
          PRIMARY KEY(sessionId, formateurId)
        )
      ''');
    }

    final studentsCols = await existingColumns('etudiants');
    if (studentsCols.isEmpty) {
      await database.execute('''
        CREATE TABLE etudiants (
          id TEXT PRIMARY KEY,
          studentNumber TEXT,
          name TEXT,
          address TEXT,
          photo TEXT,
          formation TEXT,
          paymentStatus TEXT,
          phone TEXT,
          email TEXT
        )
      ''');
    } else {
      final studentsNeeded = {
        'name': 'TEXT',
        'studentNumber': 'TEXT',
        'address': 'TEXT',
        'photo': 'TEXT',
        'formation': 'TEXT',
        'paymentStatus': 'TEXT',
        'phone': 'TEXT',
        'email': 'TEXT',
        'dateNaissance': 'TEXT',
        'lieuNaissance': 'TEXT',
        'idDocumentType': 'TEXT',
        'idNumber': 'TEXT',
        'participantTitle': 'TEXT',
      };
      for (final e in studentsNeeded.entries) {
        if (!studentsCols.contains(e.key.toLowerCase())) {
          await database.execute('ALTER TABLE etudiants ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    final paymentsCols = await existingColumns('student_payments');
    if (paymentsCols.isEmpty) {
      await database.execute('''
        CREATE TABLE student_payments (
          id TEXT PRIMARY KEY,
          studentId TEXT,
          inscriptionId TEXT,
          formationId TEXT,
          amount REAL,
          method TEXT,
          note TEXT,
          isCredit INTEGER DEFAULT 0,
          createdAt INTEGER
        )
      ''');
    } else {
      if (!paymentsCols.contains('inscriptionid')) {
        await database.execute('ALTER TABLE student_payments ADD COLUMN inscriptionId TEXT');
      }
      if (!paymentsCols.contains('formationid')) {
        await database.execute('ALTER TABLE student_payments ADD COLUMN formationId TEXT');
      }
      if (!paymentsCols.contains('iscredit')) {
        await database.execute('ALTER TABLE student_payments ADD COLUMN isCredit INTEGER DEFAULT 0');
      }
    }

    final inscriptionsInfo = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='inscriptions'");
    if (inscriptionsInfo.isEmpty) {
      await database.execute('''
        CREATE TABLE inscriptions (
          id TEXT PRIMARY KEY,
          studentId TEXT,
          formationId TEXT,
          inscriptionDate INTEGER,
          status TEXT,
          finalGrade REAL,
          certificatePath TEXT,
          discountPercent REAL,
          appreciation TEXT,
          sessionId TEXT, -- New field
          FOREIGN KEY (studentId) REFERENCES etudiants(id),
          FOREIGN KEY (formationId) REFERENCES formations(id)
        )
      ''');
    }
    // ensure discountPercent column exists on older DBs
    final insCols = await existingColumns('inscriptions');
    if (!insCols.contains('discountpercent')) {
      try {
        await database.execute('ALTER TABLE inscriptions ADD COLUMN discountPercent REAL');
      } catch (_) {}
    }
    if (!insCols.contains('appreciation')) {
      try {
        await database.execute('ALTER TABLE inscriptions ADD COLUMN appreciation TEXT');
      } catch (_) {}
    }
    if (!insCols.contains('sessionid')) {
      try {
        await database.execute('ALTER TABLE inscriptions ADD COLUMN sessionId TEXT');
      } catch (_) {}
    }

    // ensure entry_templates table exists for older DBs
    final entryTplCols = await existingColumns('entry_templates');
    if (entryTplCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS entry_templates (
          id TEXT PRIMARY KEY,
          name TEXT,
          content TEXT,
          defaultJournalId TEXT,
          createdAt INTEGER,
          updatedAt INTEGER
        )
      ''');
    }
    else {
      if (!entryTplCols.contains('defaultjournalid')) {
        try {
          await database.execute('ALTER TABLE entry_templates ADD COLUMN defaultJournalId TEXT');
        } catch (_) {}
      }
    }

    // ensure favorite_accounts table exists
    final favCols = await existingColumns('favorite_accounts');
    if (favCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS favorite_accounts (
          code TEXT PRIMARY KEY,
          createdAt INTEGER
        )
      ''');
    }

    // ensure app_prefs table exists
    final prefsCols = await existingColumns('app_prefs');
    if (prefsCols.isEmpty) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS app_prefs (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
  }

  Future<void> addInscription(Map<String, Object?> inscriptionData) async {
    final database = await db;
    await database.insert('inscriptions', inscriptionData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertInvoice(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('invoices', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getInvoices({bool onlyGeneric = true}) async {
    final database = await db;
    if (onlyGeneric) {
      return await database.query('invoices', where: 'isInscription = ?', whereArgs: [0], orderBy: 'date DESC');
    }
    return await database.query('invoices', orderBy: 'date DESC');
  }

  Future<Map<String, Object?>?> getInvoiceById(String id) async {
    final database = await db;
    final rows = await database.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> updateInvoice(String id, Map<String, Object?> changes) async {
    final database = await db;
    await database.update('invoices', changes, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateInscriptionCertificate(String inscriptionId, String certificatePath) async {
    final database = await db;
    await database.update(
      'inscriptions',
      {'certificatePath': certificatePath},
      where: 'id = ?',
      whereArgs: [inscriptionId],
    );
  }

  Future<void> updateInscriptionStatus(String inscriptionId, String status) async {
    final database = await db;
    await database.update(
      'inscriptions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [inscriptionId],
    );
  }

  Future<void> updateInscriptionEvaluation({
    required String inscriptionId,
    required String status,
    double? finalGrade,
    String? appreciation,
  }) async {
    final database = await db;
    await database.update(
      'inscriptions',
      {
        'status': status,
        'finalGrade': finalGrade,
        'appreciation': appreciation,
      },
      where: 'id = ?',
      whereArgs: [inscriptionId],
    );
  }

  Future<List<Inscription>> getInscriptionsForStudent(String studentId) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT
        i.*,
        f.title as formationTitle,
        s.name as sessionName, -- New field
        s.startDate as sessionStartDate, -- New field
        s.endDate as sessionEndDate, -- New field
        s.room as room -- New field
      FROM inscriptions i
      LEFT JOIN formations f ON i.formationId = f.id
      LEFT JOIN sessions s ON i.sessionId = s.id -- New join
      WHERE i.studentId = ?
      ORDER BY i.inscriptionDate DESC
    ''', [studentId]);
    return rows.map((r) => Inscription.fromMap(r)).toList();
  }

  /// Return raw inscription rows joined with student and formation info
  /// Fields returned: inscriptionId, inscriptionDate, discountPercent, inscriptionStatus,
  /// studentId, studentName, studentNumber,
  /// formationId, formationTitle, formationPrice
  Future<List<Map<String, Object?>>> getInscriptionsForInvoicing() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT
        i.id as inscriptionId,
        i.inscriptionDate as inscriptionDate,
        i.discountPercent as discountPercent,
        i.status as inscriptionStatus,
        e.id as studentId,
        e.name as studentName,
        e.studentNumber as studentNumber,
        f.id as formationId,
        f.title as formationTitle,
        f.price as formationPrice
      FROM inscriptions i
      LEFT JOIN etudiants e ON i.studentId = e.id
      LEFT JOIN formations f ON i.formationId = f.id
      ORDER BY i.inscriptionDate DESC
    ''');

    return rows;
  }

  /// Return raw inscription rows joined with student and formation info within a date range.
  Future<List<Map<String, Object?>>> getInscriptionsByDateRange(int startMs, int endMs) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT
        i.id as inscriptionId,
        i.inscriptionDate as inscriptionDate,
        i.discountPercent as discountPercent,
        i.status as inscriptionStatus,
        e.id as studentId,
        e.name as studentName,
        e.studentNumber as studentNumber,
        f.id as formationId,
        f.title as formationTitle,
        f.price as formationPrice
      FROM inscriptions i
      LEFT JOIN etudiants e ON i.studentId = e.id
      LEFT JOIN formations f ON i.formationId = f.id
      WHERE i.inscriptionDate >= ? AND i.inscriptionDate <= ?
      ORDER BY i.inscriptionDate DESC
    ''', [startMs, endMs]);

    return rows;
  }

  Future<List<Document>> getDocumentsByStudent(String studentId) async {
    final database = await db;
    final rows = await database.query('documents', where: 'studentId = ?', whereArgs: [studentId]);
    return rows.map((r) => Document.fromMap(r)).toList();
  }

  Future<bool> hasConflict({
    required String room,
    required String formateurId,
    required int startMs,
    required int endMs,
    String? excludeSessionId,
  }) async {
    final database = await db;
  // Support both legacy (start/end) and new (startDate/endDate) column names
  final whereClauses = <String>['isArchived = 0', '((room = ? OR formateurId = ?) AND NOT (COALESCE("endDate", "end") <= ? OR COALESCE(startDate, start) >= ?))'];
  final whereArgs = <Object>[room, formateurId, startMs, endMs];
    if (excludeSessionId != null) {
      whereClauses.add('id != ?');
      whereArgs.add(excludeSessionId);
    }
    final whereString = whereClauses.join(' AND ');
    final rows = await database.rawQuery('SELECT COUNT(*) as c FROM sessions WHERE $whereString', whereArgs);
    final count = (rows.first['c'] as int?) ?? 0;
    return count > 0;
  }

  Future<bool> checkSessionConflict({required String formationId, required int startMs, required int endMs, String? excludeSessionId}) async {
    final database = await db;
  // Use COALESCE to query whichever date columns exist
  final whereClauses = <String>['COALESCE(startDate, start) < ? AND COALESCE("endDate", "end") > ?'];
  final whereArgs = <Object>[endMs, startMs];
    if (excludeSessionId != null) {
      whereClauses.add('id != ?');
      whereArgs.add(excludeSessionId);
    }

    final whereString = whereClauses.join(' AND ');
    final rows = await database.rawQuery('SELECT COUNT(*) as c FROM sessions WHERE $whereString AND isArchived = 0', whereArgs);
    final count = (rows.first['c'] as int?) ?? 0;
    return count > 0;
  }

  // CRUD helpers
  Future<List<Formation>> getFormations() async {
    final database = await db;
    final rows = await database.query('formations');

    List<Formation> result = [];
    for (final r in rows) {
      final formateursRows = await database.query('formateurs', where: 'formationId = ?', whereArgs: [r['id']]);
      final sessionsRows = await database.query('sessions', where: 'formationId = ?', whereArgs: [r['id']]);

      final formateurs = formateursRows.map((m) => Formateur.fromMap(m)).toList();
      final sessions = sessionsRows.map((m) => Session.fromMap(m)).toList();

      result.add(Formation.fromMap(r, formateurs: formateurs, sessions: sessions));
    }

    return result;
  }

  Future<void> insertFormation(Formation f) async {
    final database = await db;
    await database.insert('formations', f.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    for (final fm in f.formateurs) {
      await insertFormateur(fm, formationId: f.id);
    }
    for (final s in f.sessions) {
      await insertSession(s, formationId: f.id);
    }
  }

  Future<void> updateFormation(Formation f) async {
    final database = await db;
    await database.update('formations', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
  }

  Future<void> deleteFormation(String id) async {
    final database = await db;
    await database.delete('formations', where: 'id = ?', whereArgs: [id]);
    await database.delete('formateurs', where: 'formationId = ?', whereArgs: [id]);
    await database.delete('sessions', where: 'formationId = ?', whereArgs: [id]);
  }

  Future<void> insertFormateur(Formateur f, {required String formationId}) async {
    final database = await db;
    final m = f.toMap(formationId);
    await database.insert('formateurs', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFormateur(Formateur f, {required String formationId}) async {
    final database = await db;
    await database.update('formateurs', f.toMap(formationId), where: 'id = ?', whereArgs: [f.id]);
  }

  Future<void> deleteFormateur(String id) async {
    final database = await db;
    await database.delete('formateurs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertSession(Session s, {required String formationId}) async {
    final database = await db;
    final m = await _sessionMapForExecutor(database, s, formationId);
    await database.insert('sessions', m, conflictAlgorithm: ConflictAlgorithm.replace);
  // persist many-to-many assignments
  await _writeSessionFormateurs(database, s.id, s.formateurIds);
  }

  Future<void> updateSession(Session s, {required String formationId}) async {
    final database = await db;
    final m = await _sessionMapForExecutor(database, s, formationId);
    await database.update('sessions', m, where: 'id = ?', whereArgs: [s.id]);
  await _writeSessionFormateurs(database, s.id, s.formateurIds);
  }

  Future<void> deleteSession(String id) async {
    final database = await db;
    await database.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await database.delete('session_formateurs', where: 'sessionId = ?', whereArgs: [id]);
  }

  Future<List<Session>> getSessionsForFormation(String formationId) async {
    final database = await db;
    final rows = await database.query('sessions', where: 'formationId = ?', whereArgs: [formationId], orderBy: 'startDate ASC');
    return rows.map((r) => Session.fromMap(r)).toList();
  }

  Future<void> _writeSessionFormateurs(DatabaseExecutor exec, String sessionId, List<String> formateurIds) async {
    // remove existing
    await exec.rawDelete('DELETE FROM session_formateurs WHERE sessionId = ?', [sessionId]);
    for (final fid in formateurIds) {
      if (fid.isEmpty) continue;
      await exec.insert('session_formateurs', {'sessionId': sessionId, 'formateurId': fid}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Lightweight migrations: add new columns to existing tables if they don't exist.
  Future<void> _applyMigrations(Database database) async {
    try {
      final cols = await database.rawQuery("PRAGMA table_info('documents')");
      final existing = cols.map((c) => (c['name'] as String).toLowerCase()).toSet();

      if (!existing.contains('certificatenumber')) {
        await database.execute("ALTER TABLE documents ADD COLUMN certificateNumber TEXT DEFAULT ''");
      }
      if (!existing.contains('validationurl')) {
        await database.execute("ALTER TABLE documents ADD COLUMN validationUrl TEXT DEFAULT ''");
      }
      if (!existing.contains('qrcodedata')) {
        await database.execute("ALTER TABLE documents ADD COLUMN qrcodeData TEXT DEFAULT ''");
      }
    } catch (e) {
      // If migration fails, log and continue — older installations will still function but
      // inserts that include the new keys may fail until DB schema is fixed.
      print('DB migration warning: failed to apply documents table migrations: $e');
    }
  }

  // Documents CRUD
  Future<void> insertDocument(Document doc) async {
    final database = await db;
    await database.insert('documents', doc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Document?> getDocumentByCertificateNumber(String certNumber) async {
    final database = await db;
    final rows = await database.query('documents', where: 'certificateNumber = ?', whereArgs: [certNumber], limit: 1);
    if (rows.isEmpty) return null;
    return Document.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<Document?> getDocumentByValidationUrl(String url) async {
    final database = await db;
    final rows = await database.query('documents', where: 'validationUrl = ?', whereArgs: [url], limit: 1);
    if (rows.isEmpty) return null;
    return Document.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> updateDocument(Map<String, Object?> m) async {
    final database = await db;
    await database.update('documents', m, where: 'id = ?', whereArgs: [m['id']]);
  }

  Future<void> insertPayment(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('student_payments', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertCommunication(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('communications', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getCommunicationsForStudent(String studentId) async {
    final database = await db;
    final rows = await database.query('communications', where: 'studentId = ?', whereArgs: [studentId], orderBy: 'createdAt DESC');
    return rows;
  }

  Future<List<Map<String, Object?>>> getPaymentsByStudent(String? studentId, {String? inscriptionId, bool genericOnly = false}) async {
    final database = await db;
    String whereClause = '';
    List<Object> whereArgs = [];

    if (genericOnly) {
      whereClause = 'inscriptionId IS NULL';
    } else if (studentId != null) {
      whereClause = 'studentId = ?';
      whereArgs.add(studentId);
      if (inscriptionId != null) {
        whereClause += ' AND inscriptionId = ?';
        whereArgs.add(inscriptionId);
      }
    }

    final rows = await database.query('student_payments', where: whereClause.isNotEmpty ? whereClause : null, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: 'createdAt DESC');
    return rows;
  }

  /// Return sums for payments on an inscription: paid (isCredit=0) and credits (isCredit=1)
  Future<Map<String, double>> getPaymentSumsForInscription(String inscriptionId) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT
        SUM(CASE WHEN COALESCE(isCredit,0)=0 THEN COALESCE(amount,0) ELSE 0 END) as paid,
        SUM(CASE WHEN COALESCE(isCredit,0)=1 THEN COALESCE(amount,0) ELSE 0 END) as credits
      FROM student_payments
      WHERE inscriptionId = ?
    ''', [inscriptionId]);

    final paid = (rows.first['paid'] as num?)?.toDouble() ?? 0.0;
    final credits = (rows.first['credits'] as num?)?.toDouble() ?? 0.0;
    return {'paid': paid, 'credits': credits};
  }

  // Dashboard / metrics helpers
  Future<int> countStudents() async {
    final database = await db;
    final rows = await database.rawQuery('SELECT COUNT(*) as c FROM etudiants');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countStudentsInDebt() async {
    final database = await db;
    // consider students not marked 'À jour' as in debt/partial
    final rows = await database.rawQuery("SELECT COUNT(*) as c FROM etudiants WHERE paymentStatus IS NULL OR paymentStatus != ?", ['À jour']);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countSessionsAlmostFull({int thresholdRemaining = 2}) async {
    final database = await db;
    final rows = await database.rawQuery('SELECT COUNT(*) as c FROM sessions WHERE maxCapacity IS NOT NULL AND maxCapacity > 0 AND (maxCapacity - COALESCE(currentEnrollments,0)) <= ? AND isArchived = 0', [thresholdRemaining]);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countPaymentsInMonth(int year, int month) async {
    final database = await db;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await database.rawQuery('SELECT COUNT(*) as c FROM student_payments WHERE createdAt >= ? AND createdAt < ?', [start, end]);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<double> sumPaymentsInMonth(int year, int month) async {
    final database = await db;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await database.rawQuery('SELECT SUM(amount) as s FROM student_payments WHERE createdAt >= ? AND createdAt < ?', [start, end]);
    return (rows.first['s'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getRecoveryRate() async {
    final database = await db;
    final paidRows = await database.rawQuery('SELECT SUM(amount) as s FROM student_payments');
    final totalPaid = (paidRows.first['s'] as num?)?.toDouble() ?? 0.0;

    final dueRows = await database.rawQuery('''
      SELECT SUM(COALESCE(f.price,0.0) * (1 - COALESCE(i.discountPercent,0)/100.0)) as due
      FROM inscriptions i
      LEFT JOIN formations f ON i.formationId = f.id
    ''');
    final totalDue = (dueRows.first['due'] as num?)?.toDouble() ?? 0.0;

    if (totalDue <= 0.0) return 0.0;
    return (totalPaid / totalDue) * 100.0;
  }

  Future<List<Document>> getDocumentsByFormation(String formationId) async {
    final database = await db;
    final rows = await database.query('documents', where: 'formationId = ?', whereArgs: [formationId]);
    return rows.map((r) => Document.fromMap(r)).toList();
  }

  Future<void> deleteDocument(String id) async {
    final database = await db;
    await database.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // Comptabilité helpers

  Future<void> insertJournal(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('journaux', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getPlanComptable() async {
    final database = await db;
    final rows = await database.query('plan_comptable', orderBy: 'code');
    return rows;
  }

  /// Diagnostic: return all plan_comptable codes that are not purely numeric.
  /// Useful to detect entries like 'INST' inserted from the embedded CSV.
  Future<List<String>> findNonNumericPlanCodes() async {
    final database = await db;
    final rows = await database.query('plan_comptable');
    final result = <String>[];
    for (final r in rows) {
      final code = (r['code'] ?? '').toString();
      if (code.isEmpty) continue;
      if (int.tryParse(code) == null) result.add(code);
    }
    return result;
  }

  /// Diagnostic: return codes that appear more than once in the plan_comptable table.
  Future<List<String>> findDuplicatePlanCodes() async {
    final database = await db;
    final rows = await database.query('plan_comptable');
    final counts = <String, int>{};
    for (final r in rows) {
      final code = (r['code'] ?? '').toString();
      if (code.isEmpty) continue;
      counts[code] = (counts[code] ?? 0) + 1;
    }
    return counts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
  }

  /// Migrate a plan_comptable code/id from `oldCode` to `newCode`.
  /// This will:
  ///  - fail if `newCode` already exists (to avoid collisions),
  ///  - update `plan_comptable` rows where code == oldCode (set id and code to newCode),
  ///  - update any `parentId` references pointing to oldCode,
  ///  - update `ecritures_comptables.accountCode` references from oldCode to newCode.
  /// Returns a map with `success: true` or `success: false` and `message` on failure.
  Future<Map<String, Object?>> migratePlanCode(String oldCode, String newCode) async {
    final database = await db;
    // Defensive: require non-empty codes
    if (oldCode.trim().isEmpty || newCode.trim().isEmpty) {
      return {'success': false, 'message': 'empty_code'};
    }

    return await database.transaction<Map<String, Object?>>((txn) async {
      // Check target existence
      final targetRows = await txn.query('plan_comptable', where: 'code = ?', whereArgs: [newCode], limit: 1);
      if (targetRows.isNotEmpty) {
        return {'success': false, 'message': 'target_exists'};
      }

      // Ensure source exists
      final sourceRows = await txn.query('plan_comptable', where: 'code = ?', whereArgs: [oldCode], limit: 1);
      if (sourceRows.isEmpty) {
        return {'success': false, 'message': 'source_not_found'};
      }

      try {
        // Update the account row(s) - id is primary key but SQLite allows updating it.
        await txn.update('plan_comptable', {'id': newCode, 'code': newCode}, where: 'code = ?', whereArgs: [oldCode]);

        // Update any parentId references that pointed to the old code
        await txn.rawUpdate('UPDATE plan_comptable SET parentId = ? WHERE parentId = ?', [newCode, oldCode]);

        // Update accounting entries referencing the account code
        await txn.rawUpdate('UPDATE ecritures_comptables SET accountCode = ? WHERE accountCode = ?', [newCode, oldCode]);

        return {'success': true};
      } catch (err) {
        return {'success': false, 'message': 'exception', 'detail': err.toString()};
      }
    });
  }

  Future<void> insertCompte(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('plan_comptable', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Delete a compte from the plan comptable by id.
  Future<void> deleteCompte(String id) async {
    final database = await db;
    await database.delete('plan_comptable', where: 'id = ?', whereArgs: [id]);
  }

  /// Return true if the given account has direct child accounts.
  Future<bool> hasChildAccounts(String id) async {
    final database = await db;
    final rows = await database.query('plan_comptable', where: 'parentId = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  /// Count ecritures referencing a given account code.
  Future<int> countEcrituresForAccountCode(String accountCode) async {
    final database = await db;
    final rows = await database.rawQuery('SELECT COUNT(*) as c FROM ecritures_comptables WHERE accountCode = ?', [accountCode]);
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Fetch ecritures referencing any of the provided account codes.
  Future<List<Map<String, Object?>>> getEcrituresByAccountCodes(List<String> codes) async {
    final database = await db;
    if (codes.isEmpty) return [];
    final placeholders = List.filled(codes.length, '?').join(',');
    final rows = await database.rawQuery('SELECT * FROM ecritures_comptables WHERE accountCode IN ($placeholders)', codes);
    return rows;
  }

  /// Get sum of debit or credit for accounts starting with a given prefix within a date range.
  Future<double> getAccountSum(String accountCodePrefix, {bool isDebit = true, DateTime? start, DateTime? end}) async {
    final database = await db;
    final where = <String>[];
    final args = <Object>[];

    where.add('accountCode LIKE ?');
    args.add('$accountCodePrefix%');

    if (start != null) {
      where.add('date >= ?');
      args.add(start.millisecondsSinceEpoch);
    }
    if (end != null) {
      where.add('date <= ?');
      args.add(end.millisecondsSinceEpoch);
    }

    final sumColumn = isDebit ? 'debit' : 'credit';
    final whereClause = where.join(' AND ');

    final rows = await database.rawQuery(
      'SELECT SUM($sumColumn) as totalSum FROM ecritures_comptables WHERE $whereClause',
      args,
    );

    return (rows.first['totalSum'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get plan_comptable row by id.
  Future<Map<String, Object?>?> getCompteById(String id) async {
    final database = await db;
    final rows = await database.query('plan_comptable', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Delete an account and all its descendant accounts; set accountCode to NULL on matching ecritures.
  Future<void> deleteCompteCascade(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      // collect ids to delete
      final toDelete = <String>{};
      final codes = <String>{};

      final stack = <String>[id];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (toDelete.contains(cur)) continue;
        toDelete.add(cur);
        final rows = await txn.query('plan_comptable', where: 'parentId = ?', whereArgs: [cur]);
        for (final r in rows) {
          stack.add(r['id'] as String);
        }
      }

      // collect account codes for affected ids
      for (final cid in toDelete) {
        final r = await txn.query('plan_comptable', where: 'id = ?', whereArgs: [cid], limit: 1);
        if (r.isNotEmpty) {
          final code = r.first['code'] as String?;
          if (code != null && code.isNotEmpty) codes.add(code);
        }
      }

      // clear accountCode references in ecritures for affected codes
      if (codes.isNotEmpty) {
        final placeholders = List.filled(codes.length, '?').join(',');
        await txn.rawUpdate('UPDATE ecritures_comptables SET accountCode = NULL WHERE accountCode IN ($placeholders)', codes.toList());
      }

      // delete accounts
      for (final cid in toDelete) {
        await txn.delete('plan_comptable', where: 'id = ?', whereArgs: [cid]);
      }
    });
  }

  Future<void> insertEcriture(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('ecritures_comptables', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getEcritures({DateTime? start, DateTime? end, String? journalId}) async {
    final database = await db;
    final where = <String>[];
    final args = <Object>[];
    if (start != null) {
      where.add('date >= ?');
      args.add(start.millisecondsSinceEpoch);
    }
    if (end != null) {
      where.add('date <= ?');
      args.add(end.millisecondsSinceEpoch);
    }
    if (journalId != null && journalId.isNotEmpty && journalId != 'Tous') {
      where.add('journalId = ?');
      args.add(journalId);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final rows = await database.query('ecritures_comptables', where: whereClause, whereArgs: args, orderBy: 'date DESC');
    return rows;
  }

  Future<String> getNextPieceNumberForJournal(String journalId) async {
    final database = await db;
    final rows = await database.query('numerotation', where: 'journalId = ?', whereArgs: [journalId]);
    int next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['lastNumber'] as int? ?? 0;
      next = last + 1;
      await database.update('numerotation', {'lastNumber': next}, where: 'journalId = ?', whereArgs: [journalId]);
    } else {
      await database.insert('numerotation', {'journalId': journalId, 'lastNumber': next});
    }
    final padded = next.toString().padLeft(5, '0');
    return '${journalId.toUpperCase()}-$padded';
  }

  /// Peek next piece number for a journal without incrementing the counter.
  /// If the journal has no row yet, returns "JOURNAL-00001".
  Future<String> peekNextPieceNumberForJournal(String journalId) async {
    final database = await db;
    final rows = await database.query('numerotation', where: 'journalId = ?', whereArgs: [journalId]);
    int next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['lastNumber'] as int? ?? 0;
      next = last + 1;
    }
    final padded = next.toString().padLeft(5, '0');
    return '${journalId.toUpperCase()}-$padded';
  }

  Future<void> insertLettrage(Map<String, Object?> lettrage) async {
    final database = await db;
    await database.insert('lettrages', lettrage, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Journal entry templates CRUD
  Future<List<Map<String, dynamic>>> getEntryTemplates() async {
    final database = await db;
    final rows = await database.query('entry_templates', orderBy: 'name ASC');
    return rows;
  }

  // Journaux comptables
  Future<List<Map<String, Object?>>> getJournaux() async {
    final database = await db;
    return await database.query('journaux', orderBy: 'code');
  }

  Future<void> upsertJournal(Map<String, Object?> m) async {
    final database = await db;
    await database.insert('journaux', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertDefaultJournauxIfMissing() async {
    final database = await db;
    final rows = await database.query('journaux', limit: 1);
    if (rows.isNotEmpty) return;
    final defaults = [
      {'id': 'VE', 'code': 'VE', 'name': 'Journal des Ventes', 'description': 'Ventes et avoirs clients', 'type': 'Ventes'},
      {'id': 'AC', 'code': 'AC', 'name': 'Journal des Achats', 'description': 'Achats et frais', 'type': 'Achats'},
      {'id': 'BQ', 'code': 'BQ', 'name': 'Journal de Banque', 'description': 'Opérations bancaires', 'type': 'Banque'},
      {'id': 'CA', 'code': 'CA', 'name': 'Journal de Caisse', 'description': 'Opérations de caisse', 'type': 'Caisse'},
      {'id': 'OD', 'code': 'OD', 'name': 'Opérations Diverses', 'description': 'Écritures d\'OD', 'type': 'OD'},
      {'id': 'PA', 'code': 'PA', 'name': 'Journal de Paie', 'description': 'Écritures de paie', 'type': 'Paie'},
      {'id': 'IM', 'code': 'IM', 'name': 'Journal des Immobilisations', 'description': 'Acquisitions/cessions immo', 'type': 'Immobilisations'},
    ];
    final batch = database.batch();
    for (final j in defaults) {
      batch.insert('journaux', j, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.insert('numerotation', {'journalId': j['id'], 'lastNumber': 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertEntryTemplate({required String id, required String name, required String contentJson, String? defaultJournalId}) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.insert(
      'entry_templates',
      {
        'id': id,
        'name': name,
        'content': contentJson,
        'defaultJournalId': defaultJournalId,
        'createdAt': now,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEntryTemplate(String id) async {
    final database = await db;
    await database.delete('entry_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertDefaultEntryTemplatesIfMissing() async {
    final database = await db;
    final rows = await database.query('entry_templates', limit: 1);
    if (rows.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = [
      {
        'id': 'tpl_vente_comptant', 'defaultJournalId': 'VE',
        'name': 'Vente comptant',
        'content': jsonEncode([
          {'account': '701', 'label': 'Vente', 'debit': 0.0, 'credit': 100.0},
          {'account': '512', 'label': 'Encaissement', 'debit': 100.0, 'credit': 0.0},
        ]),
      },
      {
        'id': 'tpl_achat_fournisseur', 'defaultJournalId': 'AC',
        'name': 'Achat fournisseur',
        'content': jsonEncode([
          {'account': '601', 'label': 'Achat', 'debit': 100.0, 'credit': 0.0},
          {'account': '401', 'label': 'Fournisseur', 'debit': 0.0, 'credit': 100.0},
        ]),
      },
      {
        'id': 'tpl_paiement_fournisseur', 'defaultJournalId': 'BQ',
        'name': 'Paiement fournisseur',
        'content': jsonEncode([
          {'account': '401', 'label': 'Dette fournisseur', 'debit': 100.0, 'credit': 0.0},
          {'account': '512', 'label': 'Banque', 'debit': 0.0, 'credit': 100.0},
        ]),
      },
      {
        'id': 'tpl_vente_client_ttc', 'defaultJournalId': 'VE',
        'name': 'Vente client (TTC)',
        'content': jsonEncode([
          {'account': '411', 'label': 'Client', 'debit': 118.0, 'credit': 0.0},
          {'account': '701', 'label': 'Vente', 'debit': 0.0, 'credit': 100.0},
          {'account': '4457', 'label': 'TVA collectée', 'debit': 0.0, 'credit': 18.0},
        ]),
      },
      {
        'id': 'tpl_reglement_client', 'defaultJournalId': 'BQ',
        'name': 'Règlement client',
        'content': jsonEncode([
          {'account': '512', 'label': 'Banque', 'debit': 118.0, 'credit': 0.0},
          {'account': '411', 'label': 'Client', 'debit': 0.0, 'credit': 118.0},
        ]),
      },
      {
        'id': 'tpl_achat_ttc', 'defaultJournalId': 'AC',
        'name': 'Achat (TTC)',
        'content': jsonEncode([
          {'account': '601', 'label': 'Achat', 'debit': 100.0, 'credit': 0.0},
          {'account': '4456', 'label': 'TVA déductible', 'debit': 18.0, 'credit': 0.0},
          {'account': '401', 'label': 'Fournisseur', 'debit': 0.0, 'credit': 118.0},
        ]),
      },
      {
        'id': 'tpl_paie_salariale', 'defaultJournalId': 'PA',
        'name': 'Paie salariale',
        'content': jsonEncode([
          {'account': '641', 'label': 'Salaires', 'debit': 100.0, 'credit': 0.0},
          {'account': '645', 'label': 'Charges sociales', 'debit': 40.0, 'credit': 0.0},
          {'account': '421', 'label': 'Rémunérations dues', 'debit': 0.0, 'credit': 120.0},
        ]),
      },
      {
        'id': 'tpl_paiement_salaires', 'defaultJournalId': 'BQ',
        'name': 'Paiement salaires',
        'content': jsonEncode([
          {'account': '421', 'label': 'Rémunérations dues', 'debit': 120.0, 'credit': 0.0},
          {'account': '512', 'label': 'Banque', 'debit': 0.0, 'credit': 120.0},
        ]),
      },
      {
        'id': 'tpl_acquisition_immobilisation', 'defaultJournalId': 'IM',
        'name': 'Acquisition immobilisation (TTC)',
        'content': jsonEncode([
          {'account': '215', 'label': 'Immobilisation', 'debit': 1000.0, 'credit': 0.0},
          {'account': '44562', 'label': 'TVA déductible Immos', 'debit': 180.0, 'credit': 0.0},
          {'account': '404', 'label': 'Fournisseur d\'immobilisations', 'debit': 0.0, 'credit': 1180.0},
        ]),
      },
      {
        'id': 'tpl_reglement_immobilisation', 'defaultJournalId': 'BQ',
        'name': 'Règlement acquisition immo',
        'content': jsonEncode([
          {'account': '404', 'label': 'Fournisseur immo', 'debit': 1180.0, 'credit': 0.0},
          {'account': '512', 'label': 'Banque', 'debit': 0.0, 'credit': 1180.0},
        ]),
      },
      {
        'id': 'tpl_dotation_amort', 'defaultJournalId': 'OD',
        'name': 'Dotation amortissement',
        'content': jsonEncode([
          {'account': '6811', 'label': 'Dotations aux amortissements', 'debit': 100.0, 'credit': 0.0},
          {'account': '281', 'label': 'Amortissements cumulés', 'debit': 0.0, 'credit': 100.0},
        ]),
      },
      {
        'id': 'tpl_avoir_client', 'defaultJournalId': 'VE',
        'name': 'Avoir client',
        'content': jsonEncode([
          {'account': '709', 'label': 'Rabais/Remises accordés', 'debit': 100.0, 'credit': 0.0},
          {'account': '4457', 'label': 'TVA collectée', 'debit': 18.0, 'credit': 0.0},
          {'account': '411', 'label': 'Client', 'debit': 0.0, 'credit': 118.0},
        ]),
      },
      {
        'id': 'tpl_remise_od', 'defaultJournalId': 'OD',
        'name': 'Remise (OD)',
        'content': jsonEncode([
          {'account': '709', 'label': 'Remise commerciale', 'debit': 100.0, 'credit': 0.0},
          {'account': '701', 'label': 'Vente', 'debit': 0.0, 'credit': 100.0},
        ]),
      },
      {
        'id': 'tpl_frais_bancaires', 'defaultJournalId': 'BQ',
        'name': 'Frais bancaires',
        'content': jsonEncode([
          {'account': '627', 'label': 'Services bancaires', 'debit': 25.0, 'credit': 0.0},
          {'account': '512', 'label': 'Banque', 'debit': 0.0, 'credit': 25.0},
        ]),
      },
      {
        'id': 'tpl_agios_bancaires', 'defaultJournalId': 'BQ',
        'name': 'Agios bancaires',
        'content': jsonEncode([
          {'account': '661', 'label': 'Intérêts bancaires', 'debit': 30.0, 'credit': 0.0},
          {'account': '512', 'label': 'Banque', 'debit': 0.0, 'credit': 30.0},
        ]),
      },
      {
        'id': 'tpl_provision_clients_douteux', 'defaultJournalId': 'OD',
        'name': 'Provision clients douteux',
        'content': jsonEncode([
          {'account': '68174', 'label': 'Dotations prov. clients', 'debit': 100.0, 'credit': 0.0},
          {'account': '491', 'label': 'Dépréciations clients', 'debit': 0.0, 'credit': 100.0},
        ]),
      },
    ];
    for (final t in defaults) {
      await database.insert('entry_templates', {
        'id': t['id'],
        'name': t['name'],
        'content': t['content'],
        'defaultJournalId': t['defaultJournalId'],
        'createdAt': now,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    // Also ensure default journals exist (so models can be applied)
    await insertDefaultJournauxIfMissing();
  }

  Future<void> assignLettrageToEcritures(String lettrageId, List<String> ecritureIds) async {
    final database = await db;
    final batch = database.batch();
    for (final id in ecritureIds) {
      batch.update('ecritures_comptables', {'lettrageId': lettrageId}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> getLettrages() async {
    final database = await db;
    final rows = await database.query('lettrages', orderBy: 'createdAt DESC');
    return rows;
  }

  Future<void> removeLettrageFromEcritures(String lettrageId) async {
    final database = await db;
    await database.update('ecritures_comptables', {'lettrageId': null}, where: 'lettrageId = ?', whereArgs: [lettrageId]);
    await database.delete('lettrages', where: 'id = ?', whereArgs: [lettrageId]);
  }

  /// Return top account codes by usage in entries, fallback to common ones if none.
  Future<List<String>> getTopAccountCodes({int limit = 10}) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT e.accountCode as code, COUNT(e.id) as cnt
      FROM ecritures_comptables e
      WHERE e.accountCode IS NOT NULL AND e.accountCode <> ''
      GROUP BY e.accountCode
      ORDER BY cnt DESC
      LIMIT ?
    ''', [limit]);
    final out = rows.map((r) => (r['code'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    // Merge pinned accounts at the front
    final pinned = await getPinnedAccountCodes();
    final merged = <String>{...pinned, ...out}.toList();
    if (merged.isNotEmpty) return merged;
    // Fallback to common accounts
    return ['512', '401', '411', '701', '601', '4457', '627', '661', '215', '281'];
  }

  Future<List<String>> getPinnedAccountCodes() async {
    final database = await db;
    final rows = await database.query('favorite_accounts', orderBy: 'createdAt DESC');
    return rows.map((r) => (r['code'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> setPinnedAccount(String code, bool pinned) async {
    final database = await db;
    if (code.isEmpty) return;
    if (pinned) {
      await database.insert('favorite_accounts', {'code': code, 'createdAt': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await database.delete('favorite_accounts', where: 'code = ?', whereArgs: [code]);
    }
  }

  // App preferences (key-value)
  Future<String?> getPref(String key) async {
    final database = await db;
    final rows = await database.query('app_prefs', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setPref(String key, String value) async {
    final database = await db;
    await database.insert('app_prefs', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateEcriture(String id, Map<String, Object?> data) async {
    final database = await db;
    await database.update('ecritures_comptables', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archiveDocument(String id) async {
    final database = await db;
    await database.update('documents', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, Object?>> _sessionMapForExecutor(DatabaseExecutor exec, Session s, String formationId) async {
    final colsInfo = await exec.rawQuery('PRAGMA table_info(sessions)');
    final cols = colsInfo.map((c) => (c['name'] as String).toLowerCase()).toSet();

    final m = <String, Object?>{
      'id': s.id,
      'formationId': formationId,
      'room': s.room,
      'maxCapacity': s.maxCapacity,
      'currentEnrollments': s.currentEnrollments,
      'status': s.status,
    };

    if (cols.contains('start')) {
      m['start'] = s.startDate.millisecondsSinceEpoch;
    } else if (cols.contains('startdate')) {
      m['startDate'] = s.startDate.millisecondsSinceEpoch;
    } else {
      m['start'] = s.startDate.millisecondsSinceEpoch;
    }

    // include name if supported
    if (cols.contains('name')) {
      m['name'] = s.name;
    }

    if (cols.contains('end')) {
      m['end'] = s.endDate.millisecondsSinceEpoch;
    } else if (cols.contains('enddate')) {
      m['endDate'] = s.endDate.millisecondsSinceEpoch;
    } else {
      m['end'] = s.endDate.millisecondsSinceEpoch;
    }

    return m;
  }

  // Students CRUD
  Future<List<Student>> getStudents() async {
    final database = await db;
    final rows = await database.query('etudiants');
    return rows.map((r) => Student.fromMap(r)).toList();
  }

  // Helper: get existing columns for a table (lowercased)
  Future<Set<String>> _getTableColumns(String table) async {
    final database = await db;
    try {
      final info = await database.rawQuery('PRAGMA table_info($table)');
      return info.map((r) => (r['name'] as String).toLowerCase()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> insertStudent(Map<String, Object?> m) async {
    final database = await db;
    final cols = await _getTableColumns('etudiants');
    final filtered = <String, Object?>{};
    m.forEach((k, v) {
      if (cols.contains(k.toLowerCase())) filtered[k] = v;
    });
    await database.insert('etudiants', filtered, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStudent(Map<String, Object?> m) async {
    final database = await db;
    final cols = await _getTableColumns('etudiants');
    final filtered = <String, Object?>{};
    m.forEach((k, v) {
      if (cols.contains(k.toLowerCase())) filtered[k] = v;
    });
    if (filtered.isEmpty) return;
    await database.update('etudiants', filtered, where: 'id = ?', whereArgs: [m['id']]);
  }

  Future<void> deleteStudent(String id) async {
    final database = await db;
    await database.delete('etudiants', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveFormationTransaction(Formation f) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.insert('formations', f.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final existingFormateurs = await txn.query('formateurs', where: 'formationId = ?', whereArgs: [f.id]);
      final existingIds = existingFormateurs.map((r) => r['id'] as String).toSet();
      final incomingIds = f.formateurs.map((fm) => fm.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('formateurs', where: 'id = ?', whereArgs: [id]);
      }
      for (final fm in f.formateurs) {
        await txn.insert('formateurs', fm.toMap(f.id), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final existingSessions = await txn.query('sessions', where: 'formationId = ?', whereArgs: [f.id]);
      final existingSessionIds = existingSessions.map((r) => r['id'] as String).toSet();
      final incomingSessionIds = f.sessions.map((s) => s.id).toSet();

      for (final id in existingSessionIds.difference(incomingSessionIds)) {
        await txn.delete('sessions', where: 'id = ?', whereArgs: [id]);
      }
      for (final s in f.sessions) {
        final m = await _sessionMapForExecutor(txn, s, f.id);
        await txn.insert('sessions', m, conflictAlgorithm: ConflictAlgorithm.replace);
  // persist many-to-many assignments
  await _writeSessionFormateurs(txn, s.id, s.formateurIds);
      }
    });
  }

  // Archive helpers
  Future<void> archiveFormation(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.update('formations', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
      await txn.update('formateurs', {'isArchived': 1}, where: 'formationId = ?', whereArgs: [id]);
      await txn.update('sessions', {'isArchived': 1}, where: 'formationId = ?', whereArgs: [id]);
  // also mark relationships by deleting or leaving them; we'll keep join rows but it's fine to leave them
  // mark documents archived
      await txn.update('documents', {'isArchived': 1}, where: 'formationId = ?', whereArgs: [id]);
    });
  }

  Future<void> unarchiveFormation(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.update('formations', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);
      await txn.update('formateurs', {'isArchived': 0}, where: 'formationId = ?', whereArgs: [id]);
      await txn.update('sessions', {'isArchived': 0}, where: 'formationId = ?', whereArgs: [id]);
      await txn.update('documents', {'isArchived': 0}, where: 'formationId = ?', whereArgs: [id]);
    });
  }

  Future<void> archiveFormateur(String id) async {
    final database = await db;
    await database.update('formateurs', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> unarchiveFormateur(String id) async {
    final database = await db;
    await database.update('formateurs', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archiveSession(String id) async {
    final database = await db;
    await database.update('sessions', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> unarchiveSession(String id) async {
    final database = await db;
    await database.update('sessions', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Backup/export
  Future<String> backupDB({String? targetPath}) async {
    String dbPath;
    if (_db != null) {
      dbPath = _db!.path;
    } else {
      final documents = await getApplicationDocumentsDirectory();
      dbPath = p.join(documents.path, 'afroforma.db');
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupPath = targetPath ?? p.join(documentsDir.path, 'afroforma_backup_${DateTime.now().millisecondsSinceEpoch}.db');
    final dbFile = File(dbPath);
    await dbFile.copy(backupPath);
    return backupPath;
  }

  Future<String> exportCSV({String? targetPath}) async {
    final database = await db;
    final documentsDir = await getApplicationDocumentsDirectory();
    final exportPath = targetPath ?? p.join(documentsDir.path, 'afroforma_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    final sink = File(exportPath).openWrite();

    final formations = await database.query('formations');
    sink.writeln('formations');
    if (formations.isNotEmpty) {
      sink.writeln(formations.first.keys.join(','));
      for (final row in formations) {
        sink.writeln(row.values.map((v) => '"${v ?? ''}"').join(','));
      }
    }

    final formateurs = await database.query('formateurs');
    sink.writeln('\nformateurs');
    if (formateurs.isNotEmpty) {
      sink.writeln(formateurs.first.keys.join(','));
      for (final row in formateurs) {
        sink.writeln(row.values.map((v) => '"${v ?? ''}"').join(','));
      }
    }

    final sessions = await database.query('sessions');
    sink.writeln('\nsessions');
    if (sessions.isNotEmpty) {
      sink.writeln(sessions.first.keys.join(','));
      for (final row in sessions) {
        sink.writeln(row.values.map((v) => '"${v ?? ''}"').join(','));
      }
    }

    await sink.flush();
    await sink.close();
    return exportPath;
  }

  /// Close the database connection and clear internal reference.
  // User CRUD
  Future<void> insertUser(User user) async {
    final database = await db;
    await database.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getUsers() async {
    final database = await db;
    final rows = await database.query('users');
    return rows.map((r) => User.fromMap(r)).toList();
  }

  Future<void> updateUser(User user) async {
    final database = await db;
    await database.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deleteUser(String id) async {
    final database = await db;
    await database.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// Reset users table and recreate a single admin user.
  /// Returns the plaintext generated password so the caller can display it to the operator.
  Future<Map<String, String>> resetAdmin() async {
    final database = await db;
    // Preserve existing admin's 2FA if present
    String? preservedSecret;
    bool preserve2fa = false;
    try {
      final existing = await database.query('users', where: 'role = ? AND isActive = 1', whereArgs: [UserRole.admin.index]);
      if (existing.isNotEmpty) {
        final first = existing.first;
        final enabled = (first['is2faEnabled'] as int?) == 1;
        final secret = first['twoFaSecret'] as String?;
        if (enabled && (secret != null && secret.isNotEmpty)) {
          preserve2fa = true;
          preservedSecret = secret;
        }
      }
    } catch (_) {}
    // Generate a secure random password
    final rng = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%&*()-_=+';
    final pwLength = 12;
    final password = List.generate(pwLength, (_) => chars[rng.nextInt(chars.length)]).join();

    final hashedPassword = sha256.convert(utf8.encode(password)).toString();

    String createdId = '';
    await database.transaction((txn) async {
      // 1. Delete all existing users
      await txn.delete('users');

      // 2. Create a default admin user with generated password
      final adminUser = User(
        id: 'admin_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Admin',
        email: 'admin@afroforma.com',
        role: UserRole.admin,
        passwordHash: hashedPassword,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isActive: true,
        permissions: [],
        mustChangePassword: true,
        is2faEnabled: preserve2fa,
        twoFaSecret: preserve2fa ? preservedSecret : null,
      );

      await txn.insert('users', adminUser.toMap());
      createdId = adminUser.id;
    });

    return {'id': createdId, 'password': password};
  }

  Future<void> setMustChangePassword(String userId, bool mustChange) async {
    final database = await db;
    await database.update('users', {'mustChangePassword': mustChange ? 1 : 0}, where: 'id = ?', whereArgs: [userId]);
  }

  Future<int> countActiveAdmins() async {
    final database = await db;
    final rows = await database.rawQuery(
      'SELECT COUNT(*) as c FROM users WHERE role = ? AND isActive = 1',
      [UserRole.admin.index], // Assuming UserRole.admin is stored as its index
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // Audit Log CRUD
  Future<void> insertAuditLog(AuditLog log) async {
    final database = await db;
    await database.insert(
      'audit_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AuditLog>> getAuditLogs() async {
    final database = await db;
    final rows = await database.query('audit_logs', orderBy: 'timestamp DESC');
    return rows.map((r) => AuditLog.fromMap(r)).toList();
  }

  // CompanyInfo CRUD
  Future<void> saveCompanyInfo(CompanyInfo info) async {
    final database = await db;
    await database.transaction((txn) async {
      // Always ensure there's only one row. Delete existing and insert new.
      await txn.delete('company_info');
      await txn.insert(
        'company_info',
        info.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<CompanyInfo?> getCompanyInfo() async {
    final database = await db;
    final rows = await database.query('company_info', limit: 1);
    if (rows.isNotEmpty) {
      return CompanyInfo.fromMap(rows.first);
    }
    // If no info found, return a default empty CompanyInfo object
    return CompanyInfo(
      name: '',
      address: '',
      phone: '',
      email: '',
      rccm: '',
      nif: '',
      website: '',
      logoPath: '',
      autoBackup: false,
      backupFrequency: 'Quotidienne',
      retentionDays: 30,
      exercice: '',
      monnaie: 'FCFA',
      planComptable: 'SYSCOHADA',
      academic_year: '',
      directorName: '',
      location: '',
    );
  }

  /// Log an image insert attempt (path and whether file existed at the time).
  Future<void> logImageDiagnostic(String path, bool exists) async {
    final database = await db;
    await database.insert('image_diagnostics', {
      'inserted_path': path,
      'file_exists': exists ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // DocumentTemplate CRUD
  Future<void> saveDocumentTemplate(DocumentTemplate template) async {
    final database = await db;
  Future<List<Map<String, Object?>>> getRecentPayments() async {
    final database = await db;
    final rows = await database.query('student_payments', orderBy: 'createdAt DESC', limit: 5);
    return rows;
  }
    await database.insert(
      'document_templates',
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DocumentTemplate>> getDocumentTemplates() async {
    final database = await db;
    final rows = await database.query('document_templates', orderBy: 'name ASC');
    return rows.map((r) => DocumentTemplate.fromMap(r)).toList();
  }

  Future<void> deleteDocumentTemplate(String id) async {
    final database = await db;
    await database.delete('document_templates', where: 'id = ?', whereArgs: [id]);
  }

  /// Remove all custom templates and re-insert the three default templates.
  Future<void> resetDefaultTemplates() async {
    final database = await db;
    await database.delete('document_templates');
    await _insertDefaultTemplatesIfMissing(database);
  }

  Future<List<Map<String, Object?>>> getRecentPayments() async {
    final database = await db;
    final rows = await database.query('student_payments', orderBy: 'createdAt DESC', limit: 5);
    return rows;
  }

  
  Future<void> close() async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
  }
}
