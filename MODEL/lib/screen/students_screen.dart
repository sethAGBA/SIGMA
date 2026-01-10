import 'dart:io';

import 'dart:typed_data';
import 'package:afroforma/models/inscription.dart';
import 'package:afroforma/models/session.dart';
import 'package:afroforma/utils/receipt_generator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import '../utils/format_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:afroforma/services/notification_service.dart';
import '../utils/template_canvas_pdf.dart';

import '../models/document.dart';
import '../models/formation.dart';
import '../models/student.dart';
import '../services/database_service.dart';
import 'package:afroforma/utils/certificate_generator.dart';

class StudentsScreen extends StatefulWidget {
  @override
  _StudentsScreenState createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  static const Color primaryAccent = Color(0xFF06B6D4);
  static const Color primaryAccentDark = Color(0xFF0891B2);

  final List<Student> _students = [];
  final List<Formation> _formations = [];
  final Map<String, Formation> _formationMap = {};
  final Set<String> _selected = {};

  String _search = '';
  String _filterFormation = 'Toutes';
  String _filterPayment = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadFormations();
  }

  Future<void> _loadStudents() async {
    final rows = await DatabaseService().getStudents();
    setState(() {
      _students
        ..clear()
        ..addAll(rows);
    });
  }

  Future<void> _loadFormations() async {
    try {
      final rows = await DatabaseService().getFormations();
      setState(() {
        _formations
          ..clear()
          ..addAll(rows);
        _formationMap.clear();
        for (final f in _formations) {
          _formationMap[f.id] = f;
        }
      });
    } catch (e) {
      // ignore - keep UI functional even if formations fail to load
    }
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    IconData icon = Icons.people_outline,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryAccent, primaryAccentDark],
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _bulkExportSelected() async {
    final selectedStudents = _students
        .where((s) => _selected.contains(s.id))
        .toList();
    if (selectedStudents.isEmpty) return;

    // Let user choose columns
    final availableColumns = <String, bool>{
      'id': true,
      'studentNumber': true,
      'name': true,
      'email': true,
      'phone': true,
      'address': false,
      'formation': true,
      'paymentStatus': true,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) {
          return AlertDialog(
            title: const Text('Choisir les colonnes à exporter'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: availableColumns.keys.map((k) {
                  return CheckboxListTile(
                    title: Text(k),
                    value: availableColumns[k],
                    onChanged: (v) =>
                        setState2(() => availableColumns[k] = v ?? false),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx2, true),
                child: const Text('Continuer'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final selectedCols = availableColumns.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedCols.isEmpty) return;

    // ask where to save (same options as receipts)
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sauvegarder l\'export'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'app'),
            child: const Text("Sauvegarder dans l'app"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'choose'),
            child: const Text('Choisir un répertoire'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    final csvContent = StringBuffer();
    csvContent.writeln(selectedCols.join(','));
    for (final s in selectedStudents) {
      final values = selectedCols
          .map((col) {
            switch (col) {
              case 'id':
                return '"${s.id}"';
              case 'studentNumber':
                return '"${s.studentNumber}"';
              case 'name':
                return '"${s.name}"';
              case 'email':
                return '"${s.email}"';
              case 'phone':
                return '"${s.phone}"';
              case 'address':
                return '"${s.address}"';
              case 'formation':
                return '"${s.formation}"';
              case 'paymentStatus':
                return '"${s.paymentStatus}"';
              default:
                return '""';
            }
          })
          .join(',');
      csvContent.writeln(values);
    }

    Future<void> _showExportedDialog(String filePath) async {
      final dir = File(filePath).parent.path;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export terminé'),
          content: Text(filePath),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (Platform.isMacOS)
                  await Process.run('open', [dir]);
                else if (Platform.isLinux)
                  await Process.run('xdg-open', [dir]);
                else if (Platform.isWindows)
                  await Process.run('cmd', ['/c', 'start', '', dir]);
              },
              child: const Text('Ouvrir dossier'),
            ),
          ],
        ),
      );
    }

    if (choice == 'app') {
      final documentsDir = await getApplicationDocumentsDirectory();
      final filePath = p.join(
        documentsDir.path,
        'students_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      final file = File(filePath);
      await file.writeAsString(csvContent.toString(), flush: true);
      await _showExportedDialog(filePath);
    } else if (choice == 'choose') {
      try {
        final dirPath = await FilePicker.platform.getDirectoryPath();
        if (dirPath == null) return;
        final filePath =
            '$dirPath${Platform.pathSeparator}students_export_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(filePath);
        await file.writeAsString(csvContent.toString(), flush: true);
        await _showExportedDialog(filePath);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur export: $e')));
      }
    }
  }

  Future<void> _bulkSendReminder() async {
    final selectedStudents = _students
        .where((s) => _selected.contains(s.id) && s.email.isNotEmpty)
        .toList();
    if (selectedStudents.isEmpty) {
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Aucun étudiant sélectionné avec email.',
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final subjectCtrl = TextEditingController(text: "Rappel de paiement");
    final bodyCtrl = TextEditingController(
      text:
          "Bonjour, ceci est un rappel concernant votre situation de paiement.",
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Envoyer un rappel à tous les étudiants sélectionnés ?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nombre d\'étudiants : ${selectedStudents.length}'),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(labelText: 'Objet'),
            ),
            TextField(
              controller: bodyCtrl,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final s in selectedStudents) {
      await DatabaseService().insertCommunication({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'studentId': s.id,
        'type': 'relance',
        'channel': 'email',
        'subject': subjectCtrl.text,
        'body': bodyCtrl.text,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _sendEmail(s.email, subject: subjectCtrl.text, body: bodyCtrl.text);
    }

    NotificationService().showNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: 'Rappel envoyé à ${selectedStudents.length} étudiant(s).',
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _bulkDeleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer $count étudiant(s)?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in _selected.toList()) {
      await DatabaseService().deleteStudent(id);
    }
    _selected.clear();
    await _loadStudents();
    NotificationService().showNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: '$count étudiant(s) supprimé(s).',
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ...existing code...

  Future<void> _openFile(String path) async {
    try {
      final f = File(path);
      if (!f.existsSync()) {
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Fichier introuvable.',
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (Platform.isMacOS)
        await Process.run('open', [path]);
      else if (Platform.isLinux)
        await Process.run('xdg-open', [path]);
      else if (Platform.isWindows)
        await Process.run('cmd', ['/c', 'start', '', path]);
      else
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Ouverture non supportée.',
            backgroundColor: Colors.orange,
          ),
        );
    } catch (e) {
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Erreur lors de l\'ouverture du fichier.',
          details: e.toString(),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }


  // Allow generating a receipt either via the standard generator or via a canvas template.
  Future<String> _generateAndSaveOrTemplateReceipt(
    BuildContext context,
    Student student,
    Formation? formation,
    Map<String, dynamic> newPayment,
    List<Map<String, dynamic>> paymentHistory,
    double balance, {
    bool saveInApp = true,
    String? externalDir,
    String? inscriptionId,
    bool? useCanvasTemplate,
  }) async {
    // fetch canvas-type templates for receipts
    final templates = (await DatabaseService().getDocumentTemplates()).where((t) => t.type == 'canvas' && t.id.contains('receipt')).toList();

    // Determine whether we should use a canvas template.
    // If caller explicitly requested canvas (useCanvasTemplate != null), honor it.
    // Otherwise, ask the user to pick between Standard or one of the canvas templates.
    bool useTemplate = false;
    String? picked;
    if (useCanvasTemplate != null) {
      useTemplate = useCanvasTemplate && templates.isNotEmpty;
    } else {
      // Build choices
      final choices = <String>['Standard'];
      choices.addAll(templates.map((t) => t.name));

      picked = await showDialog<String?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Choisir le modèle pour le reçu'),
          children: [
            ...choices.map((c) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c))),
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
          ],
        ),
      );
      if (picked == null) return '';
      useTemplate = picked != 'Standard';
    }
    Uint8List bytes;
    if (!useTemplate) {
      final companyInfo = await DatabaseService().getCompanyInfo();
      bytes = await generateReceiptPdfBytes(student, formation, newPayment, paymentHistory, balance, companyInfo!, inscriptionId: inscriptionId);
    } else {
      final chosenTemplate = templates.firstWhere((t) => t.name == picked, orElse: () => templates.first);
      // build data map expected by template renderer
      final data = <String, dynamic>{
        'receipt_number': newPayment['id']?.toString() ?? '',
        'receipt_date': DateFormat.yMMMd('fr_FR').format(DateTime.now()),
        'payer_name': student.name,
        'student_id': student.id,
        'formation_name': formation?.title ?? '',
        'amount': newPayment['amount']?.toString() ?? '',
        'academic_year': (await DatabaseService().getCompanyInfo())?.academic_year ?? '',
      };
      bytes = await generatePdfFromCanvasTemplate(chosenTemplate, data);
    }

  // Save bytes
    final documentsDir = await getApplicationDocumentsDirectory();
    final baseDir = externalDir ?? p.join(documentsDir.path, 'receipts', student.id);
    final dir = Directory(baseDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fileName = 'receipt_${inscriptionId ?? 'unknown'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = p.join(dir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // register in DB
    final doc = Document(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      formationId: formation?.id ?? '',
      studentId: student.id,
      title: 'Reçu paiement ${formation?.title ?? ''}',
      category: 'reçu',
      fileName: fileName,
      path: filePath,
      mimeType: 'application/pdf',
      size: bytes.length,
    );
  await DatabaseService().insertDocument(doc);

  NotificationService().showNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: 'Reçu généré et sauvegardé.',
        backgroundColor: Colors.green,
        onAction: () => _openFile(filePath),
        actionLabel: 'Ouvrir',
        duration: const Duration(seconds: 8),
      ),
    );
  return filePath;
  }

  // Similar helper for certificates: allows Standard or Canvas template
  Future<String> _generateAndSaveOrTemplateCertificate(
    BuildContext context,
    Student student,
    Formation formation,
    Map<String, dynamic> certificationData,
  ) async {
    final templates = (await DatabaseService().getDocumentTemplates()).where((t) => t.type == 'canvas' && (t.id.contains('certificate') || t.id.contains('attestation') || t.name.toLowerCase().contains('attestation'))).toList();
    final choices = <String>['Standard'];
    choices.addAll(templates.map((t) => t.name));

    final picked = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir le modèle pour le certificat'),
        children: [
          ...choices.map((c) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c))),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
        ],
      ),
    );
  if (picked == null) return '';

    final useTemplate = picked != 'Standard';
    if (!useTemplate) {
      // existing function already saves and registers
      final path = await generateAndSaveCertificate(student, formation, certificationData);
      return path;
    }

    final chosenTemplate = templates.firstWhere((t) => t.name == picked, orElse: () => templates.first);
    final companyInfo = await DatabaseService().getCompanyInfo();
    // Determine session / room / dates to populate the participation attestation
    String room = certificationData['room'] ?? companyInfo?.location ?? '';
    DateTime? sessionStart;
    DateTime? sessionEnd;
    String? sessionName = certificationData['sessionName'] as String?;
    try {
      final sessions = await DatabaseService().getSessionsForFormation(formation.id);
      if (sessions.isNotEmpty) {
        // Prefer explicit sessionId from the certification data (inscription), else pick the first session
        if (certificationData['sessionId'] != null && (certificationData['sessionId'] as String).isNotEmpty) {
          final sid = certificationData['sessionId'] as String;
          final sel = sessions.firstWhere((ss) => ss.id == sid, orElse: () => sessions.first);
          room = (sel.room.isNotEmpty) ? sel.room : room;
          sessionStart = sel.startDate;
          sessionEnd = sel.endDate;
          sessionName = (sessionName == null || sessionName.isEmpty) ? sel.name : sessionName;
        } else {
          final sel = sessions.first;
          room = (sel.room.isNotEmpty) ? sel.room : room;
          sessionStart = sel.startDate;
          sessionEnd = sel.endDate;
          sessionName = (sessionName == null || sessionName.isEmpty) ? sel.name : sessionName;
        }
      }
    } catch (e) {
      // ignore - fallback values will be used below
      print('ATT: failed to resolve sessions for formation ${formation.id}: $e');
    }
    final data = <String, dynamic>{
      // Student information
      'student_name': student.name,
      'student_id': student.id,
      'id_document_type': student.idDocumentType, // From Student model
      'id_number': student.idNumber,             // From Student model
      'student_email': student.email,
      'student_phone': student.phone,
      'student_address': student.address,
      'student_photo': student.photo,
      'student_birth_date': student.dateNaissance,
      'student_birth_place': student.lieuNaissance,
      'student_number': student.studentNumber,

      // Formation information
      'formation_name': formation.title,
      'formation_id': formation.id,
      'formation_description': formation.description,
      'formation_duration': formation.duration,
      'formation_price': formation.price,
      'formation_title': formation.title, // Added for template compatibility

      // Certification-specific data from the inscription
      'certification_date': DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now()),
      'certification_mention': certificationData['appreciation'] ?? 'Passable',
      'certification_final_grade': certificationData['finalGrade']?.toString() ?? '',
      'certification_level': certificationData['niveau'] ?? 'Certification',
      'certification_speciality': certificationData['specialite'] ?? '',
      'certification_number': 'CERT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      'certificate_number': 'CERT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}', // Added for template compatibility


      // Company information
      'company_name': companyInfo?.name ?? '',
      'company_address': companyInfo?.address ?? '',
      'company_phone': companyInfo?.phone ?? '',
      'company_email': companyInfo?.email ?? '',
      'company_website': companyInfo?.website ?? '',
      'company_logo': companyInfo?.logoPath ?? '',
      'academic_year': certificationData['sessionStartDate'] != null ? DateFormat('yyyy').format(DateTime.fromMillisecondsSinceEpoch(certificationData['sessionStartDate'] as int)) : (companyInfo?.academic_year ?? ''),
      'director_name': companyInfo?.directorName ?? '',
      'director_title': 'Monsieur', // Default title for director
      'location': certificationData['room'] ?? companyInfo?.location ?? '',

      // Specific for Participation Certificate (from Session if available)
    'participant_name': student.name, // Mapping student_name to participant_name
    'participant_title': student.participantTitle, // From Student model
    'event_type': formation.category, // Use formation category
  // event_description: keep session name if present, otherwise formation description
  'event_description': sessionName != null && sessionName.isNotEmpty ? sessionName : (certificationData['sessionName'] ?? formation.description),
  // event_theme: should be the formation description (theme), fallback to formation.title
  'event_theme': formation.description.isNotEmpty ? formation.description : formation.title,
    // Use resolved session dates if we found one, else fall back to certificationData millis or 'N/A'
    'start_date': sessionStart != null
      ? DateFormat('dd MMMM yyyy', 'fr_FR').format(sessionStart)
      : (certificationData['sessionStartDate'] != null
        ? DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.fromMillisecondsSinceEpoch(certificationData['sessionStartDate'] as int))
        : 'N/A'),
    'end_date': sessionEnd != null
      ? DateFormat('dd MMMM yyyy', 'fr_FR').format(sessionEnd)
      : (certificationData['sessionEndDate'] != null
        ? DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.fromMillisecondsSinceEpoch(certificationData['sessionEndDate'] as int))
        : 'N/A'),

      // Legacy keys for backward compatibility
      'birth_date_place': '${student.dateNaissance} à ${student.lieuNaissance}',
      'duration': formation.duration,
  'issue_date': DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now()),
  // Ensure room/location placeholder uses resolved room
  'room': room,
    };
    print('DEBUG: Data for PDF export for student ${student.name}: $data');
    final bytes = await generatePdfFromCanvasTemplate(chosenTemplate, data);

    final documentsDir = await getApplicationDocumentsDirectory();
    final certsDir = Directory(p.join(documentsDir.path, 'certificates', student.id));
    if (!certsDir.existsSync()) certsDir.createSync(recursive: true);
    final fileName = 'certificate_${formation.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = p.join(certsDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    final idStr = DateTime.now().millisecondsSinceEpoch.toString();
    final certNumber = data['certificate_number'] ?? data['certification_number'] ?? 'CERT-${DateTime.now().year}-$idStr';
    final validationUrl = data['validation_url'] ?? data['validationUrl'] ?? '';
    final qrData = validationUrl.isNotEmpty ? validationUrl : certNumber;

    final doc = Document(
      id: idStr,
      formationId: formation.id,
      studentId: student.id,
      title: 'Certificat - ${formation.title}',
      category: 'certificat',
      fileName: fileName,
      path: filePath,
      mimeType: 'application/pdf',
      size: bytes.length,
      certificateNumber: certNumber.toString(),
      validationUrl: validationUrl.toString(),
      qrcodeData: qrData.toString(),
    );
    await DatabaseService().insertDocument(doc);
    NotificationService().showNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: 'Certificat généré et sauvegardé.',
        backgroundColor: Colors.green,
        onAction: () => _openFile(filePath),
        actionLabel: 'Ouvrir',
        duration: const Duration(seconds: 8),
      ),
    );
    return filePath;
  }
  Future<void> _sendEmail(
    String to, {
    String subject = '',
    String body = '',
  }) async {
    if (to.isEmpty) {
      if (to.isEmpty) {
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Aucun email disponible.',
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      return;
    }
    try {
      final mailto =
          'mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      if (Platform.isMacOS)
        await Process.run('open', [mailto]);
      else if (Platform.isLinux)
        await Process.run('xdg-open', [mailto]);
      else if (Platform.isWindows)
        await Process.run('cmd', ['/c', 'start', '', mailto]);
      else
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Envoi d\'email non supporté.',
            backgroundColor: Colors.orange,
          ),
        );
    } catch (e) {
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message:
              'Erreur lors de l\'ouverture de l\'application de messagerie.',
          details: e.toString(),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showEvaluationDialog(
    Inscription inscription,
    VoidCallback onUpdate,
  ) async {
    final statusCtrl = ValueNotifier<String>(inscription.status);
    final gradeCtrl = TextEditingController(
      text: inscription.finalGrade?.toString() ?? '',
    );
    final appreciationCtrl = TextEditingController(
      text: inscription.appreciation ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final statuses = ['En cours', 'Terminé', 'Validé', 'Abandonné'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Évaluer l\'inscription'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: statusCtrl,
                  builder: (context, value, child) {
                    return DropdownButtonFormField<String>(
                      // If the current value isn't one of the allowed statuses, pass null so
                      // the dropdown doesn't assert (and the user can pick a new value).
                      value: statuses.contains(value) ? value : null,
                      items: statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          statusCtrl.value = v;
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Statut'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: gradeCtrl,
                  decoration: const InputDecoration(labelText: 'Note finale'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v) == null) {
                      return 'Veuillez entrer un nombre valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: appreciationCtrl,
                  decoration: const InputDecoration(labelText: 'Appréciation'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().updateInscriptionEvaluation(
        inscriptionId: inscription.id,
        status: statusCtrl.value,
        finalGrade: double.tryParse(gradeCtrl.text),
        appreciation: appreciationCtrl.text,
      );
      onUpdate(); // This will be reloadInscriptions
    }
  }

  List<Student> get _visible => _students.where((s) {
    final matchesSearch =
        _search.isEmpty ||
        s.name.toLowerCase().contains(_search.toLowerCase()) ||
        s.phone.contains(_search) ||
        s.email.toLowerCase().contains(_search.toLowerCase());
    final matchesFormation =
        _filterFormation == 'Toutes' || s.formation == _filterFormation;
    final matchesPayment =
        _filterPayment == 'Tous' || s.paymentStatus == _filterPayment;
    return matchesSearch && matchesFormation && matchesPayment;
  }).toList();

  Future<void> _showStudentDetails(Student s) async {
    final companyInfo = await DatabaseService().getCompanyInfo();
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<List<Document>> docsFuture = DatabaseService()
              .getDocumentsByStudent(s.id);
          Future<List<Inscription>> inscriptionsFuture = DatabaseService()
              .getInscriptionsForStudent(s.id);

          void reloadDocs() {
            setStateDialog(() {
              docsFuture = DatabaseService().getDocumentsByStudent(s.id);
            });
          }

          void reloadInscriptions() {
            setStateDialog(() {
              inscriptionsFuture = DatabaseService().getInscriptionsForStudent(
                s.id,
              );
            });
          }

          return Dialog(
            backgroundColor: const Color(0xFF0B1220),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 1000,
              height: 560,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Fiche Étudiant',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: const TabBar(
                          tabs: [
                            Tab(text: 'Infos'),
                            Tab(text: 'Parcours'),
                            Tab(text: 'Finances'),
                            Tab(text: 'Communication'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Infos
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 48,
                                        backgroundImage: s.photo.isNotEmpty
                                            ? FileImage(File(s.photo))
                                            : null,
                                        child: s.photo.isNotEmpty
                                            ? null
                                            : Text(
                                                s.name.isNotEmpty
                                                    ? s.name[0]
                                                    : '?',
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Formation: ${_formationMap[s.formation]?.title ?? s.formation}',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.85,
                                                ),
                                              ),
                                            ),
                                            if (s.email.isNotEmpty)
                                              Text(
                                                'Email: ${s.email}',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.75),
                                                ),
                                              ),
                                            if (s.phone.isNotEmpty)
                                              Text(
                                                'Téléphone: ${s.phone}',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.75),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Documents joints',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<Document>>(
                                    future: docsFuture,
                                    builder: (ctx, snap) {
                                      if (snap.connectionState !=
                                          ConnectionState.done)
                                        return const SizedBox();
                                      final docs = snap.data ?? [];
                                      if (docs.isEmpty)
                                        return const Text(
                                          'Aucun document',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        );
                                      return Column(
                                        children: docs
                                            .map(
                                              (d) => Card(
                                                color: const Color(0xFF0F1724),
                                                child: ListTile(
                                                  title: Text(
                                                    d.fileName,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Titre: ${d.title}',
                                                        style: const TextStyle(
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Catégorie: ${d.category}',
                                                        style: const TextStyle(
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                        ),
                                                        onPressed: () async {
                                                          final titleCtrl =
                                                              TextEditingController(
                                                                text: d.title,
                                                              );
                                                          final categoryCtrl =
                                                              TextEditingController(
                                                                text:
                                                                    d.category,
                                                              );
                                                          await showDialog(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              title: const Text(
                                                                'Modifier document',
                                                              ),
                                                              content: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  TextField(
                                                                    controller:
                                                                        titleCtrl,
                                                                    decoration: const InputDecoration(
                                                                      labelText:
                                                                          'Titre',
                                                                    ),
                                                                  ),
                                                                  TextField(
                                                                    controller:
                                                                        categoryCtrl,
                                                                    decoration: const InputDecoration(
                                                                      labelText:
                                                                          'Catégorie',
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                        ctx,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Annuler',
                                                                      ),
                                                                ),
                                                                ElevatedButton(
                                                                  onPressed: () async {
                                                                    if (titleCtrl
                                                                        .text
                                                                        .trim()
                                                                        .isEmpty) {
                                                                      NotificationService().showNotification(
                                                                        NotificationItem(
                                                                          id: DateTime.now()
                                                                              .millisecondsSinceEpoch
                                                                              .toString(),
                                                                          message:
                                                                              'Le titre est requis.',
                                                                          backgroundColor:
                                                                              Colors.redAccent,
                                                                        ),
                                                                      );
                                                                      return;
                                                                    }
                                                                    await DatabaseService().updateDocument({
                                                                      'id':
                                                                          d.id,
                                                                      'title':
                                                                          titleCtrl
                                                                              .text,
                                                                      'category':
                                                                          categoryCtrl
                                                                              .text,
                                                                    });
                                                                    reloadDocs();
                                                                    Navigator.pop(
                                                                      ctx,
                                                                    );
                                                                  },
                                                                  child: const Text(
                                                                    'Enregistrer',
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.download,
                                                        ),
                                                        onPressed: () async {
                                                          if (d.path.isNotEmpty)
                                                            await _openFile(
                                                              d.path,
                                                            );
                                                          else
                                                            NotificationService().showNotification(
                                                              NotificationItem(
                                                                id: DateTime.now()
                                                                    .millisecondsSinceEpoch
                                                                    .toString(),
                                                                message:
                                                                    'Aucun fichier.',
                                                                backgroundColor:
                                                                    Colors
                                                                        .orange,
                                                              ),
                                                            );
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete,
                                                        ),
                                                        onPressed: () async {
                                                          final confirmed = await showDialog<bool>(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              title: const Text(
                                                                'Supprimer le document ?',
                                                              ),
                                                              content: Text(
                                                                'Le document "${d.fileName}" sera supprimé. Cette action est irréversible.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                        ctx,
                                                                        false,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Annuler',
                                                                      ),
                                                                ),
                                                                ElevatedButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                        ctx,
                                                                        true,
                                                                      ),
                                                                  child: const Text(
                                                                    'Supprimer',
                                                                  ),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .redAccent,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );

                                                          if (confirmed ==
                                                              true) {
                                                            await DatabaseService()
                                                                .deleteDocument(
                                                                  d.id,
                                                                );
                                                            reloadDocs();
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final res = await FilePicker.platform
                                              .pickFiles();
                                          if (res == null || res.files.isEmpty)
                                            return;
                                          final f = res.files.first;
                                          final tmpPath = f.path!;
                                          final fileName = p.basename(tmpPath);
                                          final titleCtrl =
                                              TextEditingController(
                                                text: fileName,
                                              );
                                          final categoryCtrl =
                                              TextEditingController();
                                          await showDialog(
                                            context: context,
                                            builder: (ctx) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Ajouter document',
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller: titleCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Titre',
                                                          ),
                                                    ),
                                                    TextField(
                                                      controller: categoryCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Catégorie',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text(
                                                      'Annuler',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      if (titleCtrl.text
                                                          .trim()
                                                          .isEmpty) {
                                                        NotificationService()
                                                            .showNotification(
                                                              NotificationItem(
                                                                id: DateTime.now()
                                                                    .millisecondsSinceEpoch
                                                                    .toString(),
                                                                message:
                                                                    'Le titre est requis.',
                                                                backgroundColor:
                                                                    Colors
                                                                        .redAccent,
                                                              ),
                                                            );
                                                        return;
                                                      }
                                                      final documentsDir =
                                                          await getApplicationDocumentsDirectory();
                                                      final attachmentsDir =
                                                          Directory(
                                                            p.join(
                                                              documentsDir.path,
                                                              'attachments',
                                                              s.id,
                                                            ),
                                                          );
                                                      if (!attachmentsDir
                                                          .existsSync())
                                                        attachmentsDir
                                                            .createSync(
                                                              recursive: true,
                                                            );
                                                      final destPath = p.join(
                                                        attachmentsDir.path,
                                                        fileName,
                                                      );
                                                      await File(
                                                        tmpPath,
                                                      ).copy(destPath);

                                                      final doc = Document(
                                                        id: DateTime.now()
                                                            .millisecondsSinceEpoch
                                                            .toString(),
                                                        formationId:
                                                            s.formation,
                                                        studentId: s.id,
                                                        title: titleCtrl.text,
                                                        category:
                                                            categoryCtrl.text,
                                                        fileName: fileName,
                                                        path: destPath,
                                                      );
                                                      await DatabaseService()
                                                          .insertDocument(doc);
                                                      reloadDocs();
                                                      Navigator.pop(ctx);
                                                    },
                                                    child: const Text(
                                                      'Ajouter',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Ajouter document'),
                                      ),
                                      const SizedBox(width: 12),
                                      TextButton(
                                        onPressed: () {},
                                        child: const Text('Télécharger tout'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Parcours
                            FutureBuilder<List<Inscription>>(
                              future: inscriptionsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Erreur: ${snapshot.error}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  );
                                }
                                final inscriptions = snapshot.data ?? [];
                                if (inscriptions.isEmpty) {
                                  return const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.school_outlined,
                                          size: 48,
                                          color: Colors.white54,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Aucun parcours académique trouvé',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: inscriptions.length,
                                  itemBuilder: (context, index) {
                                    final inscription = inscriptions[index];
                                    return Card(
                                      color: const Color(0xFF0F1724),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.school,
                                          color: primaryAccent,
                                        ),
                                        title: Text(
                                          inscription.formationTitle ??
                                              'Formation inconnue',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              'Inscrit le: ${DateFormat.yMMMd('fr_FR').format(inscription.inscriptionDate)}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Text(
                                              'Statut: ${inscription.status}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            if (inscription.finalGrade != null)
                                              Text(
                                                'Note finale: ${inscription.finalGrade}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            if (inscription.appreciation !=
                                                    null &&
                                                inscription
                                                    .appreciation!
                                                    .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4.0,
                                                ),
                                                child: Text(
                                                  'Appréciation: ${inscription.appreciation}',
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_note,
                                                color: Colors.cyan,
                                              ),
                                              tooltip: 'Évaluer',
                                              onPressed: () =>
                                                  _showEvaluationDialog(
                                                    inscription,
                                                    reloadInscriptions,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons
                                                    .workspace_premium_outlined,
                                                color: Colors.green,
                                              ),
                                              tooltip: 'Générer le certificat',
                                              onPressed: () async {
                                                if (inscription.status !=
                                                        'Terminé' &&
                                                    inscription.status !=
                                                        'Validé') {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text(
                                                        'Confirmation requise',
                                                      ),
                                                      content: const Text(
                                                        'Le statut de cette inscription n\'est pas "Terminé" ou "Validé". Voulez-vous quand même générer le certificat ?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Annuler',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Continuer',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm != true) return;
                                                }

                                                try {
                                                  final formation =
                                                      _formationMap[inscription
                                                          .formationId];
                                                  if (formation == null) {
                                                    NotificationService()
                                                        .showNotification(
                                                          NotificationItem(
                                                            id: DateTime.now()
                                                                .millisecondsSinceEpoch
                                                                .toString(),
                                                            message:
                                                                'Erreur : Formation non trouvée.',
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent,
                                                          ),
                                                        );
                                                    return;
                                                  }

                                                  NotificationService()
                                                      .showNotification(
                                                        NotificationItem(
                                                          id: DateTime.now()
                                                              .millisecondsSinceEpoch
                                                              .toString(),
                                                          message:
                                                              'Génération du certificat en cours...',
                                                          backgroundColor:
                                                              Colors.blue,
                                                        ),
                                                      );

                                                  final path = await _generateAndSaveOrTemplateCertificate(
                                                    context,
                                                    s,
                                                    formation,
                                                    inscription.toMap(),
                                                  );

                                                  NotificationService().showNotification(
                                                    NotificationItem(
                                                      id: DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString(),
                                                      message:
                                                          'Certificat pour ${s.name} généré.',
                                                      details:
                                                          'Formation: ${formation.title}',
                                                      backgroundColor:
                                                          Colors.green,
                                                      onAction: () =>
                                                          _openFile(path),
                                                      actionLabel: 'Ouvrir',
                                                      duration: const Duration(
                                                        seconds: 10,
                                                      ),
                                                    ),
                                                  );

                                                  reloadInscriptions();
                                                } catch (e) {
                                                  NotificationService()
                                                      .showNotification(
                                                        NotificationItem(
                                                          id: DateTime.now()
                                                              .millisecondsSinceEpoch
                                                              .toString(),
                                                          message:
                                                              'Erreur de génération.',
                                                          details: e.toString(),
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                        ),
                                                      );
                                                }
                                              },
                                            ),
                                            // Nouveau bouton: générer attestation de participation (A4)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.article,
                                                color: Colors.orange,
                                              ),
                                              tooltip: 'Générer attestation de participation',
                                              onPressed: () async {
                                                try {
                                                  // Debug print to capture invocation
                                                  print('ATT: Generating participation attestation for student=${s.id} name=${s.name} inscription=${inscription.id} formationId=${inscription.formationId}');

                                                  NotificationService()
                                                      .showNotification(
                                                        NotificationItem(
                                                          id: DateTime.now()
                                                              .millisecondsSinceEpoch
                                                              .toString(),
                                                          message:
                                                              'Génération de l\'attestation en cours...',
                                                          backgroundColor:
                                                              Colors.blue,
                                                        ),
                                                      );

                                                  // Récupère la formation liée et vérifie
                                                  final formation = _formationMap[inscription.formationId];
                                                  if (formation == null) {
                                                    print('ATT: formation not found for id=${inscription.formationId}');
                                                    NotificationService().showNotification(
                                                      NotificationItem(
                                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                        message: 'Erreur : Formation non trouvée.',
                                                        backgroundColor: Colors.redAccent,
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  print('ATT: calling generateAndSaveInterventionCertificate for formationId=${formation.id}');

                                                  // Utilise la fonction standardisée pour sauvegarder et lier au student
                                                  final path = await generateAndSaveInterventionCertificate(
                                                    participantFullName: s.name,
                                                    studentId: s.id,
                                                    formationId: formation.id,
                                                    eventStart: DateTime(2024, 10, 30),
                                                    eventEnd: DateTime(2024, 10, 31),
                                                    issueDate: DateTime(2024, 11, 7),
                                                  );

                                                  print('ATT: generation succeeded, path=$path');

                                                  NotificationService().showNotification(
                                                    NotificationItem(
                                                      id: DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString(),
                                                      message:
                                                          'Attestation pour ${s.name} générée.',
                                                      details: 'Fichier: ${p.basename(path)}',
                                                      backgroundColor: Colors.green,
                                                      onAction: () => _openFile(path),
                                                      actionLabel: 'Ouvrir',
                                                      duration: const Duration(seconds: 10),
                                                    ),
                                                  );

                                                  reloadInscriptions();
                                                } catch (e, st) {
                                                  // Print error & stacktrace for debugging
                                                  print('ATT: error generating attestation for student=${s.id} error=$e');
                                                  print(st.toString());

                                                  NotificationService()
                                                      .showNotification(
                                                        NotificationItem(
                                                          id: DateTime.now()
                                                              .millisecondsSinceEpoch
                                                              .toString(),
                                                          message:
                                                              'Erreur lors de la génération de l\'attestation.',
                                                          details: e.toString(),
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                        ),
                                                      );
                                                }
                                              },
                                            ),
                                            if (inscription.certificatePath !=
                                                    null &&
                                                inscription
                                                    .certificatePath!
                                                    .isNotEmpty)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.card_membership,
                                                  color: Colors.amber,
                                                ),
                                                tooltip: 'Voir le certificat',
                                                onPressed: () => _openFile(
                                                  inscription.certificatePath!,
                                                ),
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.upload_file,
                                                color: Colors.white70,
                                              ),
                                              tooltip: 'Joindre un certificat',
                                              onPressed: () async {
                                                final res = await FilePicker
                                                    .platform
                                                    .pickFiles(
                                                      type: FileType.custom,
                                                      allowedExtensions: [
                                                        'pdf',
                                                        'png',
                                                        'jpg',
                                                      ],
                                                    );
                                                if (res == null ||
                                                    res.files.isEmpty)
                                                  return;

                                                final f = res.files.first;
                                                final tmpPath = f.path!;
                                                final fileName = p.basename(
                                                  tmpPath,
                                                );

                                                final documentsDir =
                                                    await getApplicationDocumentsDirectory();
                                                final certsDir = Directory(
                                                  p.join(
                                                    documentsDir.path,
                                                    'certificates',
                                                    s.id,
                                                  ),
                                                );
                                                if (!certsDir.existsSync())
                                                  certsDir.createSync(
                                                    recursive: true,
                                                  );

                                                final destPath = p.join(
                                                  certsDir.path,
                                                  fileName,
                                                );
                                                await File(
                                                  tmpPath,
                                                ).copy(destPath);

                                                await DatabaseService()
                                                    .updateInscriptionCertificate(
                                                      inscription.id,
                                                      destPath,
                                                    );
                                                reloadInscriptions();

                                                NotificationService().showNotification(
                                                  NotificationItem(
                                                    id: DateTime.now()
                                                        .millisecondsSinceEpoch
                                                        .toString(),
                                                    message:
                                                        'Certificat ajouté avec succès.',
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                            // Finances
                            // Finances
                            FutureBuilder<List<Inscription>>(
                              future: inscriptionsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text('Erreur: ${snapshot.error}'),
                                  );
                                }
                                final inscriptions = snapshot.data ?? [];
                                if (inscriptions.isEmpty) {
                                  return const Center(
                                    child: Text('Aucune inscription trouvée.'),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: inscriptions.length,
                                  itemBuilder: (context, index) {
                                    final inscription = inscriptions[index];
                                    final formation =
                                        _formationMap[inscription.formationId];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                      color: const Color(0xFF0F1724),
                                      child: FutureBuilder<List<Map<String, Object?>>>(
                                        future: DatabaseService()
                                            .getPaymentsByStudent(
                                              s.id,
                                              inscriptionId: inscription.id,
                                            ),
                                        builder: (context, paymentSnapshot) {
                                          final payments =
                                              paymentSnapshot.data ?? [];
                                          final totalPaid = payments
                                              .fold<double>(
                                                0,
                                                (prev, p) =>
                                                    prev +
                                                    ((p['amount'] as num?)
                                                            ?.toDouble() ??
                                                        0.0),
                                              );
                                          final basePrice =
                                              formation?.price ?? 0.0;
                                          final discount =
                                              inscription.discountPercent ??
                                              0.0;
                                          final formationPrice =
                                              basePrice *
                                              (1 - (discount / 100.0));
                                          final balance =
                                              formationPrice - totalPaid;

                                          Widget balanceWidget;
                                          if (balance > 0.01) {
                                            // Use a small epsilon for float comparison
                                            balanceWidget = Text(
                                              'Solde restant: ${balance.toStringAsFixed(2)} XOF',
                                              style: const TextStyle(
                                                color: Colors.orange,
                                              ),
                                            );
                                          } else if (balance < -0.01) {
                                            balanceWidget = Text(
                                              'Avance: ${(-balance).toStringAsFixed(2)} XOF',
                                              style: const TextStyle(
                                                color: Colors.blueAccent,
                                              ),
                                            );
                                          } else {
                                            balanceWidget = const Text(
                                              'Soldé',
                                              style: TextStyle(
                                                color: Colors.green,
                                              ),
                                            );
                                          }

                                          return ExpansionTile(
                                            title: Text(
                                              inscription.formationTitle ??
                                                  'Formation inconnue',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: balanceWidget,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  16.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (discount > 0)
                                                      Text(
                                                        'Prix initial: ${basePrice.toStringAsFixed(2)} XOF — Remise: ${discount.toStringAsFixed(2)}%',
                                                      ),
                                                    Text(
                                                      'Prix net: ${formationPrice.toStringAsFixed(2)} XOF',
                                                    ),
                                                    Text(
                                                      'Total payé: ${totalPaid.toStringAsFixed(2)} XOF',
                                                    ),
                                                    const SizedBox(height: 16),
                                                    const Text(
                                                      'Historique des paiements:',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (payments.isEmpty)
                                                      const Text(
                                                        'Aucun paiement pour cette formation.',
                                                      )
                                                    else
                                                      ...payments.map(
                                                        (
                                                          paymentData,
                                                        ) => ListTile(
                                                          title: Text(
                                                            '${paymentData['amount']} XOF - ${paymentData['method']}',
                                                          ),
                                                          subtitle: Text(
                                                            DateFormat.yMMMd(
                                                              'fr_FR',
                                                            ).format(
                                                              DateTime.fromMillisecondsSinceEpoch(
                                                                paymentData['createdAt']
                                                                    as int,
                                                              ),
                                                            ),
                                                          ),
                                                          trailing: IconButton(
                                                            icon: const Icon(
                                                              Icons.print,
                                                              color: Colors
                                                                  .white54,
                                                            ),
                                                            onPressed: () async {
                                                              // let user choose where to save: app storage or external directory
                                                              final choice = await showDialog<String?>(
                                                                context:
                                                                    context,
                                                                builder: (ctx) => SimpleDialog(
                                                                  title: const Text('Sauvegarder le reçu'),
                                                                  children: [
                                                                    SimpleDialogOption(
                                                                      onPressed: () => Navigator.pop(ctx, 'app_standard'),
                                                                      child: const Text('Sauvegarder dans l\'app (Standard)'),
                                                                    ),
                                                                    SimpleDialogOption(
                                                                      onPressed: () => Navigator.pop(ctx, 'app_canvas'),
                                                                      child: const Text('Sauvegarder dans l\'app (Canvas)'),
                                                                    ),
                                                                    SimpleDialogOption(
                                                                      onPressed: () => Navigator.pop(ctx, 'choose_standard'),
                                                                      child: const Text('Choisir un répertoire (Standard)'),
                                                                    ),
                                                                    SimpleDialogOption(
                                                                      onPressed: () => Navigator.pop(ctx, 'choose_canvas'),
                                                                      child: const Text('Choisir un répertoire (Canvas)'),
                                                                    ),
                                                                    SimpleDialogOption(
                                                                      onPressed: () => Navigator.pop(ctx, null),
                                                                      child: const Text('Annuler'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );

                                                              if (choice == null) return;

                                                              if (choice == 'app_standard' || choice == 'app_canvas') {
                                                                try {
                                                                  final savedPath = await _generateAndSaveOrTemplateReceipt(
                                                                    context,
                                                                    s,
                                                                    formation,
                                                                    paymentData,
                                                                    payments,
                                                                    balance,
                                                                    saveInApp: true,
                                                                    inscriptionId: inscription.id,
                                                                    useCanvasTemplate: choice == 'app_canvas',
                                                                  );
                                                                  NotificationService().showNotification(
                                                                    NotificationItem(
                                                                      id: DateTime.now()
                                                                          .millisecondsSinceEpoch
                                                                          .toString(),
                                                                      message:
                                                                          'Reçu sauvegardé dans l\'application.',
                                                                      backgroundColor:
                                                                          Colors
                                                                              .green,
                                                                      onAction: () =>
                                                                          _openFile(
                                                                            savedPath,
                                                                          ),
                                                                      actionLabel:
                                                                          'Ouvrir',
                                                                      duration: const Duration(
                                                                        seconds:
                                                                            10,
                                                                      ),
                                                                    ),
                                                                  );
                                                                  reloadDocs();
                                                                } catch (e) {
                                                                  NotificationService().showNotification(
                                                                    NotificationItem(
                                                                      id: DateTime.now()
                                                                          .millisecondsSinceEpoch
                                                                          .toString(),
                                                                      message:
                                                                          'Échec de la sauvegarde du reçu.',
                                                                      details: e
                                                                          .toString(),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .redAccent,
                                                                    ),
                                                                  );
                                                                  await generateAndPrintReceipt(
                                                                    s,
                                                                    formation,
                                                                    paymentData,
                                                                    payments,
                                                                    balance,
                                                                  );
                                                                }
                                                              } else if (choice == 'choose_standard' || choice == 'choose_canvas') {
                                                                try {
                                                                  final dirPath =
                                                                      await FilePicker
                                                                          .platform
                                                                          .getDirectoryPath();
                                                                  if (dirPath ==
                                                                      null)
                                                                    return; // user cancelled
                                                                  final bytes = await generateReceiptPdfBytes(
                                                                    s,
                                                                    formation,
                                                                    paymentData,
                                                                    payments,
                                                                    balance,
                                                                    companyInfo!,
                                                                    inscriptionId: inscription.id,
                                                                    useCanvasTemplate: choice == 'choose_canvas',
                                                                  );
                                                                  final fileName =
                                                                      'receipt_${inscription.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                                                  final filePath =
                                                                      '$dirPath${Platform.pathSeparator}$fileName';
                                                                  final file =
                                                                      File(
                                                                        filePath,
                                                                      );
                                                                  await file
                                                                      .writeAsBytes(
                                                                        bytes,
                                                                        flush:
                                                                            true,
                                                                      );

                                                                  // register as document in DB pointing to external path
                                                                  final doc = Document(
                                                                    id: DateTime.now()
                                                                        .millisecondsSinceEpoch
                                                                        .toString(),
                                                                    formationId:
                                                                        formation
                                                                            ?.id ??
                                                                        '',
                                                                    studentId:
                                                                        s.id,
                                                                    title:
                                                                        'Reçu paiement ${formation?.title ?? ''}',
                                                                    category:
                                                                        'reçu',
                                                                    fileName:
                                                                        fileName,
                                                                    path:
                                                                        filePath,
                                                                    mimeType:
                                                                        'application/pdf',
                                                                    size: bytes
                                                                        .length,
                                                                  );
                                                                  await DatabaseService()
                                                                      .insertDocument(
                                                                        doc,
                                                                      );
                                                                  reloadDocs();

                                                                  NotificationService().showNotification(
                                                                    NotificationItem(
                                                                      id: DateTime.now()
                                                                          .millisecondsSinceEpoch
                                                                          .toString(),
                                                                      message:
                                                                          'Reçu sauvegardé.',
                                                                      // details: 'Fichier: ${p.basename(filePath)}',
                                                                      backgroundColor:
                                                                          Colors
                                                                              .green,
                                                                      onAction: () =>
                                                                          _openFile(
                                                                            filePath,
                                                                          ),
                                                                      actionLabel:
                                                                          'Ouvrir',
                                                                      duration: const Duration(
                                                                        seconds:
                                                                            10,
                                                                      ),
                                                                    ),
                                                                  );
                                                                } catch (e) {
                                                                  NotificationService().showNotification(
                                                                    NotificationItem(
                                                                      id: DateTime.now()
                                                                          .millisecondsSinceEpoch
                                                                          .toString(),
                                                                      message:
                                                                          'Échec de la sauvegarde du reçu.',
                                                                      details: e
                                                                          .toString(),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .redAccent,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            },
                                                          ),
                                                          dense: true,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 8),
                                                    ElevatedButton.icon(
                                                      icon: const Icon(
                                                        Icons.payment,
                                                      ),
                                                      label: const Text(
                                                        'Ajouter un paiement',
                                                      ),
                                                      onPressed: () async {
                                                        final amountCtrl =
                                                            TextEditingController();
                                                        final noteCtrl =
                                                            TextEditingController();

                                                        await showDialog(
                                                          context: context,
                                                          builder: (ctx) {
                                                            String
                                                            selectedMethod = '';
                                                            final paymentMethods =
                                                                [
                                                                  'Espèces',
                                                                  'Carte',
                                                                  'Mobile Money',
                                                                  'Virement',
                                                                  'Chèque',
                                                                  'Autre',
                                                                ];
                                                            return StatefulBuilder(
                                                              builder:
                                                                  (
                                                                    ctx2,
                                                                    setStateInner,
                                                                  ) {
                                                                    return AlertDialog(
                                                                      title: const Text(
                                                                        'Ajouter paiement',
                                                                      ),
                                                                      content: Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            'Solde restant: ${balance.toStringAsFixed(2)} XOF',
                                                                            style: const TextStyle(
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            height:
                                                                                16,
                                                                          ),
                                                                          TextFormField(
                                                                            controller:
                                                                                amountCtrl,
                                                                            decoration: const InputDecoration(
                                                                              labelText: 'Montant',
                                                                            ),
                                                                            keyboardType:
                                                                                TextInputType.number,
                                                                          ),
                                                                          const SizedBox(
                                                                            height:
                                                                                8,
                                                                          ),
                                                                          DropdownButtonFormField<
                                                                            String
                                                                          >(
                                                                            value:
                                                                                selectedMethod.isEmpty
                                                                                ? null
                                                                                : selectedMethod,
                                                                            decoration: const InputDecoration(
                                                                              labelText: 'Méthode',
                                                                            ),
                                                                            items: paymentMethods
                                                                                .map(
                                                                                  (
                                                                                    m,
                                                                                  ) => DropdownMenuItem(
                                                                                    value: m,
                                                                                    child: Text(
                                                                                      m,
                                                                                    ),
                                                                                  ),
                                                                                )
                                                                                .toList(),
                                                                            onChanged: (v) => setStateInner(
                                                                              () => selectedMethod =
                                                                                  v ??
                                                                                  '',
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            height:
                                                                                8,
                                                                          ),
                                                                          TextField(
                                                                            controller:
                                                                                noteCtrl,
                                                                            decoration: const InputDecoration(
                                                                              labelText: 'Note (facultatif)',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                            ctx2,
                                                                          ),
                                                                          child: const Text(
                                                                            'Annuler',
                                                                          ),
                                                                        ),
                                                                        ElevatedButton(
                                                                          onPressed: () async {
                                                                            final amount =
                                                                                double.tryParse(
                                                                                  amountCtrl.text,
                                                                                ) ??
                                                                                0.0;
                                                                            if (amount <=
                                                                                0) {
                                                                              NotificationService().showNotification(
                                                                                NotificationItem(
                                                                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                                                  message: 'Le montant doit être positif.',
                                                                                  backgroundColor: Colors.redAccent,
                                                                                ),
                                                                              );
                                                                              return;
                                                                            }

                                                                            if (amount >
                                                                                balance) {
                                                                              final confirm =
                                                                                  await showDialog<
                                                                                    bool
                                                                                  >(
                                                                                    context: context,
                                                                                    builder:
                                                                                        (
                                                                                          alertCtx,
                                                                                        ) => AlertDialog(
                                                                                          title: const Text(
                                                                                            'Confirmation requise',
                                                                                          ),
                                                                                          content: const Text(
                                                                                            'Le montant saisi est supérieur au solde restant. Voulez-vous enregistrer ce paiement comme une avance ?',
                                                                                          ),
                                                                                          actions: [
                                                                                            TextButton(
                                                                                              onPressed: () => Navigator.pop(
                                                                                                alertCtx,
                                                                                                false,
                                                                                              ),
                                                                                              child: const Text(
                                                                                                'Non',
                                                                                              ),
                                                                                            ),
                                                                                            TextButton(
                                                                                              onPressed: () => Navigator.pop(
                                                                                                alertCtx,
                                                                                                true,
                                                                                              ),
                                                                                              child: const Text(
                                                                                                'Oui',
                                                                                              ),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                  );
                                                                              if (confirm !=
                                                                                  true)
                                                                                return;
                                                                            }

                                                                            final newPayment = {
                                                                              'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                                                              'studentId': s.id,
                                                                              'inscriptionId': inscription.id,
                                                                              'amount': amount,
                                                                              'method': selectedMethod,
                                                                              'note': noteCtrl.text,
                                                                              'createdAt': DateTime.now().millisecondsSinceEpoch,
                                                                            };
                                                                            await DatabaseService().insertPayment(
                                                                              newPayment,
                                                                            );
                                                                            Navigator.pop(
                                                                              ctx2,
                                                                            );

                                                                            // recompute statuses for the affected inscription and the student
                                                                            final allPayments = await DatabaseService().getPaymentsByStudent(
                                                                              s.id,
                                                                              inscriptionId: inscription.id,
                                                                            );
                                                                            final newBalance =
                                                                                balance -
                                                                                amount;
                                                                            try {
                                                                              // inscription status
                                                                              final sumPaid =
                                                                                  allPayments.fold<
                                                                                    double
                                                                                  >(
                                                                                    0,
                                                                                    (
                                                                                      prev,
                                                                                      e,
                                                                                    ) =>
                                                                                        prev +
                                                                                        ((e['amount']
                                                                                                    as num?)
                                                                                                ?.toDouble() ??
                                                                                            0.0),
                                                                                  );
                                                                              final formationPrice =
                                                                                  (formation?.price ??
                                                                                      0.0) *
                                                                                  (1 -
                                                                                      ((inscription.discountPercent ??
                                                                                              0.0) /
                                                                                          100.0));
                                                                              String
                                                                              newInsStatus;
                                                                              if (sumPaid <=
                                                                                  0.0) {
                                                                                newInsStatus = 'Impayé';
                                                                              } else if (sumPaid <
                                                                                  formationPrice) {
                                                                                newInsStatus = 'Partiel';
                                                                              } else {
                                                                                newInsStatus = 'Soldé';
                                                                              }
                                                                              await DatabaseService().updateInscriptionStatus(
                                                                                inscription.id,
                                                                                newInsStatus,
                                                                              );

                                                                              // student overall status
                                                                              final studentInscriptions = await DatabaseService().getInscriptionsForStudent(
                                                                                s.id,
                                                                              );
                                                                              double
                                                                              totalPrice = 0.0;
                                                                              for (final ins in studentInscriptions) {
                                                                                final f = _formationMap[ins.formationId];
                                                                                final base =
                                                                                    f?.price ??
                                                                                    0.0;
                                                                                final disc =
                                                                                    ins.discountPercent ??
                                                                                    0.0;
                                                                                totalPrice +=
                                                                                    base *
                                                                                    (1 -
                                                                                        (disc /
                                                                                            100.0));
                                                                              }
                                                                              final paymentsAll = await DatabaseService().getPaymentsByStudent(
                                                                                s.id,
                                                                              );
                                                                              final totalPaid =
                                                                                  paymentsAll.fold<
                                                                                    double
                                                                                  >(
                                                                                    0,
                                                                                    (
                                                                                      prev,
                                                                                      e,
                                                                                    ) =>
                                                                                        prev +
                                                                                        ((e['amount']
                                                                                                    as num?)
                                                                                                ?.toDouble() ??
                                                                                            0.0),
                                                                                  );
                                                                              String
                                                                              studentStatus;
                                                                              if (totalPaid <=
                                                                                  0.0) {
                                                                                studentStatus = 'Impayé';
                                                                              } else if (totalPaid <
                                                                                  totalPrice) {
                                                                                studentStatus = 'Partiel';
                                                                              } else {
                                                                                studentStatus = 'À jour';
                                                                              }
                                                                              await DatabaseService().updateStudent(
                                                                                {
                                                                                  'id': s.id,
                                                                                  'paymentStatus': studentStatus,
                                                                                },
                                                                              );

                                                                              // refresh UI
                                                                              reloadInscriptions();
                                                                              await _loadStudents();
                                                                            } catch (
                                                                              e
                                                                            ) {
                                                                              // ignore errors to avoid blocking the payment flow
                                                                            }

                                                                            // After saving a payment, ask user where to save the receipt
                                                                            final choice =
                                                                                await showDialog<
                                                                                  String?
                                                                                >(
                                                                                  context: context,
                                                                                  builder:
                                                                                      (
                                                                                        ctx,
                                                                                      ) => SimpleDialog(
                                                                                        title: const Text(
                                                                                          'Sauvegarder le reçu',
                                                                                        ),
                                                                                        children: [
                                                                                          SimpleDialogOption(
                                                                                            onPressed: () => Navigator.pop(
                                                                                              ctx,
                                                                                              'app',
                                                                                            ),
                                                                                            child: const Text(
                                                                                              "Sauvegarder dans l'app",
                                                                                            ),
                                                                                          ),
                                                                                          SimpleDialogOption(
                                                                                            onPressed: () => Navigator.pop(
                                                                                              ctx,
                                                                                              'choose',
                                                                                            ),
                                                                                            child: const Text(
                                                                                              'Choisir un répertoire',
                                                                                            ),
                                                                                          ),
                                                                                          SimpleDialogOption(
                                                                                            onPressed: () => Navigator.pop(
                                                                                              ctx,
                                                                                              null,
                                                                                            ),
                                                                                            child: const Text(
                                                                                              'Ne rien faire',
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                );

                                                                            if (choice ==
                                                                                'app') {
                                                                              try {
                                                                                final savedPath = await _generateAndSaveOrTemplateReceipt(
                                                                                  context,
                                                                                  s,
                                                                                  formation,
                                                                                  newPayment,
                                                                                  allPayments,
                                                                                  newBalance,
                                                                                  saveInApp: true,
                                                                                  inscriptionId: inscription.id,
                                                                                );
                                                                                ScaffoldMessenger.of(
                                                                                  context,
                                                                                ).showSnackBar(
                                                                                  SnackBar(
                                                                                    content: Text(
                                                                                      'Reçu sauvegardé dans l\'app: $savedPath',
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                                reloadDocs();
                                                                              } catch (
                                                                                e
                                                                              ) {
                                                                                NotificationService().showNotification(
                                                                                  NotificationItem(
                                                                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                                                    message: 'Échec de la sauvegarde du reçu.',
                                                                                    details: e.toString(),
                                                                                    backgroundColor: Colors.redAccent,
                                                                                  ),
                                                                                );
                                                                                await generateAndPrintReceipt(
                                                                                  s,
                                                                                  formation,
                                                                                  newPayment,
                                                                                  allPayments,
                                                                                  newBalance,
                                                                                );
                                                                              }
                                                                            } else if (choice ==
                                                                                'choose') {
                                                                              try {
                                                                                final dirPath = await FilePicker.platform.getDirectoryPath();
                                                                                if (dirPath !=
                                                                                    null) {
                                                                                  final bytes = await generateReceiptPdfBytes(
                                                                                    s,
                                                                                    formation,
                                                                                    newPayment,
                                                                                    allPayments,
                                                                                    newBalance,
                                                                                    companyInfo!,
                                                                                    inscriptionId: inscription.id,
                                                                                  );
                                                                                  final fileName = 'receipt_${inscription.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                                                                  final filePath = '$dirPath${Platform.pathSeparator}$fileName';
                                                                                  final file = File(
                                                                                    filePath,
                                                                                  );
                                                                                  await file.writeAsBytes(
                                                                                    bytes,
                                                                                    flush: true,
                                                                                  );

                                                                                  final doc = Document(
                                                                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                                                    formationId:
                                                                                        formation?.id ??
                                                                                        '',
                                                                                    studentId: s.id,
                                                                                    title: 'Reçu paiement ${formation?.title ?? ''}',
                                                                                    category: 'reçu',
                                                                                    fileName: fileName,
                                                                                    path: filePath,
                                                                                    mimeType: 'application/pdf',
                                                                                    size: bytes.length,
                                                                                  );
                                                                                  await DatabaseService().insertDocument(
                                                                                    doc,
                                                                                  );
                                                                                  reloadDocs();

                                                                                  NotificationService().showNotification(
                                                                                    NotificationItem(
                                                                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                                                      message: 'Reçu sauvegardé.',
                                                                                      // details: 'Fichier: ${p.basename(filePath)}',
                                                                                      backgroundColor: Colors.green,
                                                                                      onAction: () => _openFile(
                                                                                        filePath,
                                                                                      ),
                                                                                      actionLabel: 'Ouvrir',
                                                                                      duration: const Duration(
                                                                                        seconds: 10,
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                }
                                                                              } catch (
                                                                                e
                                                                              ) {
                                                                                NotificationService().showNotification(
                                                                                  NotificationItem(
                                                                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                                                    message: 'Échec de la sauvegarde du reçu.',
                                                                                    details: e.toString(),
                                                                                    backgroundColor: Colors.redAccent,
                                                                                  ),
                                                                                );
                                                                              }
                                                                            }

                                                                            setStateDialog(
                                                                              () {},
                                                                            );
                                                                          },
                                                                          child: const Text(
                                                                            'Enregistrer',
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                            // Communication
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Historique & Communication',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      if (s.email.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Aucun email disponible',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final subjectCtrl =
                                          TextEditingController();
                                      final bodyCtrl = TextEditingController();
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Nouveau message'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: subjectCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Objet',
                                                    ),
                                              ),
                                              TextField(
                                                controller: bodyCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Message',
                                                    ),
                                                maxLines: 4,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Annuler'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final subj = subjectCtrl.text;
                                                final body = bodyCtrl.text;
                                                // persist the communication
                                                await DatabaseService()
                                                    .insertCommunication({
                                                      'id': DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString(),
                                                      'studentId': s.id,
                                                      'type': 'relance',
                                                      'channel': 'email',
                                                      'subject': subj,
                                                      'body': body,
                                                      'createdAt': DateTime.now()
                                                          .millisecondsSinceEpoch,
                                                    });
                                                Navigator.pop(ctx);
                                                _sendEmail(
                                                  s.email,
                                                  subject: subj,
                                                  body: body,
                                                );
                                                // refresh the UI so the history reloads
                                                setState(() {});
                                              },
                                              child: const Text('Envoyer'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.message),
                                    label: const Text('Nouveau message'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditStudentWizard(Student s) async {
    final studentUpdated = await showDialog<bool>(
      context: context,
      builder: (c) => _EditStudentDialog(
        student: s,
        formations: _formations,
        formationMap: _formationMap,
      ),
    );

    if (studentUpdated == true) {
      await _loadStudents(); // Ensure students are loaded before showing notification
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Étudiant modifié avec succès.',
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _showNewStudentWizard() async {
    final studentAdded = await showDialog<bool>(
      context: context,
      builder: (c) => _NewStudentDialog(
        formations: _formations,
        formationMap: _formationMap,
      ),
    );

    if (studentAdded == true) {
      await _loadStudents(); // Ensure students are loaded before showing notification
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Nouvel étudiant ajouté avec succès.',
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071021),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher...',
                      filled: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterFormation,
                  items: [
                    const DropdownMenuItem(
                      value: 'Toutes',
                      child: Text('Toutes'),
                    ),
                    ..._formations
                        .map(
                          (fm) => DropdownMenuItem(
                            value: fm.id,
                            child: Text(fm.title),
                          ),
                        )
                        .toList(),
                  ],
                  onChanged: (v) =>
                      setState(() => _filterFormation = v ?? 'Toutes'),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterPayment,
                  items: ['Tous', 'À jour', 'Impayé', 'Partiel']
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _filterPayment = v ?? 'Tous'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bulk actions when one or more students are selected
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      '${_selected.length} sélectionné(s)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _bulkSendReminder(),
                      icon: const Icon(Icons.email),
                      label: const Text('Relancer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _bulkExportSelected(),
                      icon: const Icon(Icons.download),
                      label: const Text('Exporter'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _bulkDeleteSelected(),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),

            // Table / content
            Expanded(
              child: Card(
                color: const Color(0xFF0B1220),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _students.isEmpty
                      ? _buildEmptyState(
                          title: 'Aucun étudiant',
                          subtitle:
                              'Ajoutez de nouveaux étudiants ou importez-les depuis la base de données',
                          icon: Icons.people_outline,
                        )
                      : (_visible.isEmpty &&
                            (_search.isNotEmpty ||
                                _filterFormation != 'Toutes' ||
                                _filterPayment != 'Tous'))
                      ? _buildEmptyState(
                          title: 'Aucun résultat',
                          subtitle: _search.isNotEmpty
                              ? 'Aucun étudiant trouvé pour "${_search}"'
                              : 'Aucun étudiant correspondant aux filtres sélectionnés',
                          icon: Icons.search,
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              const Color(0xFF06121A),
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'N°',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Nom',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Formation',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Téléphone',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Email',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Statut',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Actions',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                            rows: _visible.map((s) {
                              return DataRow(
                                selected: _selected.contains(s.id),
                                onSelectChanged: (sel) => setState(
                                  () => sel == true
                                      ? _selected.add(s.id)
                                      : _selected.remove(s.id),
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      s.studentNumber,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formationMap[s.formation]?.title ??
                                          s.formation,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      s.phone,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      s.email,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      s.paymentStatus,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility),
                                          onPressed: () =>
                                              _showStudentDetails(s),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _showEditStudentWizard(s),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Supprimer l\'étudiant ?',
                                                ),
                                                content: Text(
                                                  'L\'étudiant "${s.name}" sera supprimé. Cette action est irréversible.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Annuler',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Supprimer',
                                                    ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true) {
                                              await DatabaseService()
                                                  .deleteStudent(s.id);
                                              await _loadStudents();
                                              NotificationService().showNotification(
                                                NotificationItem(
                                                  id: DateTime.now()
                                                      .millisecondsSinceEpoch
                                                      .toString(),
                                                  message:
                                                      'Étudiant "${s.name}" supprimé.',
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryAccent,
        onPressed: _showNewStudentWizard,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Recalculate the overall payment status for a single student and update the student record.
Future<void> recalcAndUpdateStudentStatus(
  String studentId,
  Map<String, Formation> formationMap,
) async {
  try {
    final inscriptions = await DatabaseService().getInscriptionsForStudent(
      studentId,
    );
    double totalPrice = 0.0;
    for (final ins in inscriptions) {
      final f = formationMap[ins.formationId];
      final base = f?.price ?? 0.0;
      final disc = ins.discountPercent ?? 0.0;
      totalPrice += base * (1 - (disc / 100.0));
    }

    final payments = await DatabaseService().getPaymentsByStudent(studentId);
    final totalPaid = payments.fold<double>(
      0,
      (prev, e) => prev + ((e['amount'] as num?)?.toDouble() ?? 0.0),
    );

    String studentStatus;
    if (totalPaid <= 0.0) {
      studentStatus = 'Impayé';
    } else if (totalPaid < totalPrice) {
      studentStatus = 'Partiel';
    } else {
      studentStatus = 'À jour';
    }

    await DatabaseService().updateStudent({
      'id': studentId,
      'paymentStatus': studentStatus,
    });
  } catch (e) {
    // don't block caller on failure
  }
}

class _EditStudentDialog extends StatefulWidget {
  final Student student;
  final List<Formation> formations;
  final Map<String, Formation> formationMap;

  const _EditStudentDialog({
    required this.student,
    required this.formations,
    required this.formationMap,
  });

  @override
  _EditStudentDialogState createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  static const Color primaryAccentDark = Color(0xFF0891B2);
  int currentStep = 0;
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController dateNaissanceCtrl;
  late final TextEditingController lieuNaissanceCtrl;
  late final TextEditingController idDocumentTypeCtrl; // New
  late final TextEditingController idNumberCtrl;       // New
  late final TextEditingController participantTitleCtrl; // New
  late final TextEditingController studentNumberCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController discountCtrl;
  late String formation;
  String? _selectedSessionId; // New field for selected session
  List<Session> _sessions = []; // New field to store sessions
  late String payment;
  late String photoPath;
  final formKey = GlobalKey<FormState>();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.student.name);
    emailCtrl = TextEditingController(text: widget.student.email);
    phoneCtrl = TextEditingController(text: widget.student.phone);
    addressCtrl = TextEditingController(text: widget.student.address);
  dateNaissanceCtrl = TextEditingController(text: widget.student.dateNaissance);
  lieuNaissanceCtrl = TextEditingController(text: widget.student.lieuNaissance);
    idDocumentTypeCtrl = TextEditingController(text: widget.student.idDocumentType); // Initialize new controller
    idNumberCtrl = TextEditingController(text: widget.student.idNumber);       // Initialize new controller
    participantTitleCtrl = TextEditingController(text: widget.student.participantTitle); // Initialize new controller
    studentNumberCtrl = TextEditingController(
      text: widget.student.studentNumber,
    );
    amountCtrl = TextEditingController();
    discountCtrl = TextEditingController(
      text: (widget.student.formation.isNotEmpty) ? '' : '',
    );

    formation = widget.student.formation;
    payment = widget.student.paymentStatus;
    photoPath = widget.student.photo;

    // Load sessions for the initial formation
    _loadSessionsForFormation(formation);

    nameCtrl.addListener(_validate);
    emailCtrl.addListener(_validate);
    _validate();
  }

  Future<void> _loadSessionsForFormation(String formationId) async {
    if (formationId.isEmpty) {
      setState(() {
        _sessions = [];
        _selectedSessionId = null;
      });
      return;
    }
    final sessions = await DatabaseService().getSessionsForFormation(formationId);
    setState(() {
      _sessions = sessions;
      // Try to pre-select the session if the student's inscription has one
      // This assumes we can get the inscription for the student and formation
      // For simplicity, we'll just set it to null for now, or you'd need to fetch the inscription here.
      _selectedSessionId = null; // TODO: Pre-select if inscription has a session
    });
  }

  @override
  void dispose() {
    nameCtrl.removeListener(_validate);
    emailCtrl.removeListener(_validate);
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    studentNumberCtrl.dispose();
    idDocumentTypeCtrl.dispose(); // Dispose new controller
    idNumberCtrl.dispose();       // Dispose new controller
    participantTitleCtrl.dispose(); // Dispose new controller
    amountCtrl.dispose();
    discountCtrl.dispose();
  dateNaissanceCtrl.dispose();
  lieuNaissanceCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final newIsValid =
        _isValidEmail(emailCtrl.text) && nameCtrl.text.trim().isNotEmpty;
    if (newIsValid != isValid) {
      setState(() {
        isValid = newIsValid;
      });
    }
  }

  bool _isValidEmail(String? v) {
    if (v == null || v.trim().isEmpty) return false;
    final re = RegExp(r"""^[^\s@]+@[^\s@]+\.[^\s@]+$""");
    return re.hasMatch(v.trim());
  }

  bool _isValidPhone(String? v) {
    if (v == null || v.isEmpty) return true;
    return RegExp(r'^[0-9 +()\-]{6,}$').hasMatch(v);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0B1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1000,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                const Text(
                  'Modifier étudiant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Stepper(
                    currentStep: currentStep,
                    onStepTapped: (i) => setState(() => currentStep = i),
                    controlsBuilder: (ctx, details) => const SizedBox.shrink(),
                    steps: <Step>[
                      Step(
                        title: const Text('Infos personnelles'),
                        isActive: currentStep >= 0,
                        content: Column(
                          children: [
                            TextFormField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requis'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) =>
                                  _isValidEmail(v) ? null : 'Email invalide',
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => _isValidPhone(v)
                                  ? null
                                  : 'Téléphone invalide',
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: addressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Adresse',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: dateNaissanceCtrl,
                              decoration: const InputDecoration(
                                labelText: "Né(e) le (JJ/MM/AAAA)",
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: lieuNaissanceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'À (lieu de naissance)',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: idDocumentTypeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Type de document d\'identité (e.g., CNI, Passeport)',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: idNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Numéro du document d\'identité',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: participantTitleCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Titre du participant (e.g., Mr., Mme, Dr.)',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: studentNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Numéro étudiant',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            if (photoPath.isNotEmpty)
                              CircleAvatar(
                                radius: 36,
                                backgroundImage: FileImage(File(photoPath)),
                              )
                            else
                              const SizedBox(),
                            TextButton.icon(
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                );
                                if (res == null || res.files.isEmpty) return;
                                final f = res.files.first;
                                final tmpPath = f.path!;
                                final documentsDir =
                                    await getApplicationDocumentsDirectory();
                                final attachmentsDir = Directory(
                                  p.join(
                                    documentsDir.path,
                                    'attachments',
                                    widget.student.id,
                                  ),
                                );
                                if (!attachmentsDir.existsSync())
                                  attachmentsDir.createSync(recursive: true);
                                final destPath = p.join(
                                  attachmentsDir.path,
                                  p.basename(tmpPath),
                                );
                                await File(tmpPath).copy(destPath);
                                setState(() => photoPath = destPath);
                              },
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Choisir photo'),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('Formation'),
                        isActive: currentStep >= 1,
                        content: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value:
                                  (formation.isNotEmpty &&
                                      widget.formationMap.containsKey(
                                        formation,
                                      ))
                                  ? formation
                                  : null,
                              items: widget.formationMap.values
                                  .map(
                                    (fm) => DropdownMenuItem(
                                      value: fm.id,
                                      child: Text(
                                        '${fm.title} — ${fm.price.toStringAsFixed(0)}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  formation = v ?? '';
                                  final found = widget.formationMap[formation];
                                  if (found != null)
                                    amountCtrl.text = found.price.toStringAsFixed(
                                      0,
                                    );
                                });
                                await _loadSessionsForFormation(formation);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Formation actuelle',
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedSessionId,
                              items: _sessions
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        '${s.name} (${DateFormat.yMMMd('fr_FR').format(s.startDate)} - ${DateFormat.yMMMd('fr_FR').format(s.endDate)})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: formation.isNotEmpty
                                  ? (v) => setState(() => _selectedSessionId = v)
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Session (optionnel)',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('Modalités paiement'),
                        isActive: currentStep >= 2,
                        content: Column(
                          children: [
                            // payment status is calculated automatically; removed manual selector
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: amountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Montant total',
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: discountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Remise (%)',
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isValid
                          ? () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                setState(() => currentStep = 0);
                                return;
                              }
                              final updated = Student(
                                id: widget.student.id,
                                studentNumber: studentNumberCtrl.text.isNotEmpty
                                    ? studentNumberCtrl.text
                                    : widget.student.studentNumber,
                                name: nameCtrl.text,
                                email: emailCtrl.text,
                                phone: phoneCtrl.text,
                                address: addressCtrl.text,
                                formation: formation,
                                // paymentStatus is computed automatically
                                paymentStatus: widget.student.paymentStatus,
                                photo: photoPath,
                                dateNaissance: dateNaissanceCtrl.text,
                                lieuNaissance: lieuNaissanceCtrl.text,
                                idDocumentType: idDocumentTypeCtrl.text, // New field
                                idNumber: idNumberCtrl.text,             // New field
                                participantTitle: participantTitleCtrl.text, // New field
                              );
                              await DatabaseService().updateStudent(
                                updated.toMap(),
                              );

                              // recompute the student's payment status after editing
                              await recalcAndUpdateStudentStatus(
                                widget.student.id,
                                widget.formationMap,
                              );

                              if (formation.isNotEmpty &&
                                  formation != widget.student.formation) {
                                final inscription = Inscription(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  studentId: widget.student.id,
                                  formationId: formation,
                                  sessionId: _selectedSessionId, // Pass selected session ID
                                  inscriptionDate: DateTime.now(),
                                  status: 'En cours',
                                  discountPercent:
                                      double.tryParse(discountCtrl.text) ?? 0.0,
                                );
                                await DatabaseService().addInscription(
                                  inscription.toMap(),
                                );
                              }

                              Navigator.pop(context, true);
                            }
                          : null,
                      child: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccentDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewStudentDialog extends StatefulWidget {
  final List<Formation> formations;
  final Map<String, Formation> formationMap;

  const _NewStudentDialog({
    required this.formations,
    required this.formationMap,
  });

  @override
  _NewStudentDialogState createState() => _NewStudentDialogState();
}

class _NewStudentDialogState extends State<_NewStudentDialog> {
  static const Color primaryAccentDark = Color(0xFF0891B2);
  int currentStep = 0;
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController dateNaissanceCtrl;
  late final TextEditingController lieuNaissanceCtrl;
  late final TextEditingController idDocumentTypeCtrl; // New
  late final TextEditingController idNumberCtrl;       // New
  late final TextEditingController participantTitleCtrl; // New
  late final TextEditingController amountCtrl;
  late final TextEditingController discountCtrl;
  String formation = '';
  String? _selectedSessionId; // New field for selected session
  List<Session> _sessions = []; // New field to store sessions
  String payment = 'À jour';
  String photoPath = '';
  final formKey = GlobalKey<FormState>();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    addressCtrl = TextEditingController();
  dateNaissanceCtrl = TextEditingController();
  lieuNaissanceCtrl = TextEditingController();
    idDocumentTypeCtrl = TextEditingController(); // Initialize new controller
    idNumberCtrl = TextEditingController();       // Initialize new controller
    participantTitleCtrl = TextEditingController(); // Initialize new controller
    amountCtrl = TextEditingController();
    discountCtrl = TextEditingController();

    nameCtrl.addListener(_validate);
    emailCtrl.addListener(_validate);
    _validate();
  }

  Future<void> _loadSessionsForFormation(String formationId) async {
    if (formationId.isEmpty) {
      setState(() {
        _sessions = [];
        _selectedSessionId = null;
      });
      return;
    }
    final sessions = await DatabaseService().getSessionsForFormation(formationId);
    setState(() {
      _sessions = sessions;
      _selectedSessionId = null; // Reset selected session when formation changes
    });
  }

  @override
  void dispose() {
    nameCtrl.removeListener(_validate);
    emailCtrl.removeListener(_validate);
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
  dateNaissanceCtrl.dispose();
  lieuNaissanceCtrl.dispose();
    idDocumentTypeCtrl.dispose(); // Dispose new controller
    idNumberCtrl.dispose();       // Dispose new controller
    participantTitleCtrl.dispose(); // Dispose new controller
    amountCtrl.dispose();
    discountCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final newIsValid =
        _isValidEmail(emailCtrl.text) && nameCtrl.text.trim().isNotEmpty;
    if (newIsValid != isValid) {
      setState(() {
        isValid = newIsValid;
      });
    }
  }

  bool _isValidEmail(String? v) {
    if (v == null || v.trim().isEmpty) return false;
    final re = RegExp(r"""^[^\s@]+@[^\s@]+\.[^\s@]+$""");
    return re.hasMatch(v.trim());
  }

  bool _isValidPhone(String? v) {
    if (v == null || v.isEmpty) return true;
    return RegExp(r'^[0-9 +()\-]{6,}$').hasMatch(v);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0B1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1000,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                const Text(
                  'Nouvel étudiant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Stepper(
                    currentStep: currentStep,
                    onStepTapped: (i) => setState(() => currentStep = i),
                    controlsBuilder: (ctx, details) => const SizedBox.shrink(),
                    steps: <Step>[
                      Step(
                        title: const Text('Infos personnelles'),
                        isActive: currentStep >= 0,
                        content: Column(
                          children: [
                            TextFormField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requis'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) =>
                                  _isValidEmail(v) ? null : 'Email invalide',
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                              ),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => _isValidPhone(v)
                                  ? null
                                  : 'Téléphone invalide',
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: addressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Adresse',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: dateNaissanceCtrl,
                              decoration: const InputDecoration(
                                labelText: "Né(e) le (JJ/MM/AAAA)",
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: lieuNaissanceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'À (lieu de naissance)',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: idDocumentTypeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Type de document d\'identité (e.g., CNI, Passeport)',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: idNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Numéro du document d\'identité',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: participantTitleCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Titre du participant (e.g., Mr., Mme, Dr.)',
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            if (photoPath.isNotEmpty)
                              CircleAvatar(
                                radius: 36,
                                backgroundImage: FileImage(File(photoPath)),
                              )
                            else
                              const SizedBox(),
                            TextButton.icon(
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                );
                                if (res == null || res.files.isEmpty) return;
                                final f = res.files.first;
                                setState(() {
                                  photoPath = f.path!;
                                });
                              },
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Choisir photo'),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('Formation'),
                        isActive: currentStep >= 1,
                        content: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value:
                                  (formation.isNotEmpty &&
                                      widget.formationMap.containsKey(
                                        formation,
                                      ))
                                  ? formation
                                  : null,
                              items: widget.formationMap.values
                                  .map(
                                    (fm) => DropdownMenuItem(
                                      value: fm.id,
                                      child: Text(
                                        '${fm.title} — ${fm.price.toStringAsFixed(0)}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  formation = v ?? '';
                                  final found = widget.formationMap[formation];
                                  if (found != null)
                                    amountCtrl.text = found.price.toStringAsFixed(
                                      0,
                                    );
                                });
                                await _loadSessionsForFormation(formation);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Formation souhaitée',
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedSessionId,
                              items: _sessions
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        '${s.name} (${DateFormat.yMMMd('fr_FR').format(s.startDate)} - ${DateFormat.yMMMd('fr_FR').format(s.endDate)})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: formation.isNotEmpty
                                  ? (v) => setState(() => _selectedSessionId = v)
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Session (optionnel)',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('Modalités paiement'),
                        isActive: currentStep >= 2,
                        content: Column(
                          children: [
                            // payment status is calculated automatically; removed manual selector
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: amountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Montant total',
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: discountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Remise (%)',
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isValid
                          ? () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                setState(() => currentStep = 0);
                                return;
                              }
                              final studentId = DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString();
                              final studentNumber =
                                  'ST${DateTime.now().millisecondsSinceEpoch}';
                              String savedPhoto = '';
                              if (photoPath.isNotEmpty) {
                                final documentsDir =
                                    await getApplicationDocumentsDirectory();
                                final attachmentsDir = Directory(
                                  p.join(
                                    documentsDir.path,
                                    'attachments',
                                    studentId,
                                  ),
                                );
                                if (!attachmentsDir.existsSync())
                                  attachmentsDir.createSync(recursive: true);
                                final destPath = p.join(
                                  attachmentsDir.path,
                                  p.basename(photoPath),
                                );
                                await File(photoPath).copy(destPath);
                                savedPhoto = destPath;
                              }
                              final s = Student(
                                id: studentId,
                                studentNumber: studentNumber,
                                name: nameCtrl.text,
                                photo: savedPhoto,
                                address: addressCtrl.text,
                                email: emailCtrl.text,
                                phone: phoneCtrl.text,
                                formation: formation,
                                paymentStatus:
                                    'Impayé', // initial placeholder; will be recalculated
                                dateNaissance: dateNaissanceCtrl.text,
                                lieuNaissance: lieuNaissanceCtrl.text,
                                idDocumentType: idDocumentTypeCtrl.text, // New field
                                idNumber: idNumberCtrl.text,             // New field
                                participantTitle: participantTitleCtrl.text, // New field
                              );
                              await DatabaseService().insertStudent(s.toMap());

                              if (formation.isNotEmpty) {
                                final inscription = Inscription(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  studentId: studentId,
                                  formationId: formation,
                                  sessionId: _selectedSessionId, // Pass selected session ID
                                  inscriptionDate: DateTime.now(),
                                  status: 'En cours',
                                  discountPercent:
                                      double.tryParse(discountCtrl.text) ?? 0.0,
                                );
                                await DatabaseService().addInscription(
                                  inscription.toMap(),
                                );
                              }

                              // Recalculate and update the student's payment status now that the record (and inscription) exist
                              await recalcAndUpdateStudentStatus(
                                studentId,
                                widget.formationMap,
                              );

                              Navigator.pop(context, true);
                            }
                          : null,
                      child: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccentDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
