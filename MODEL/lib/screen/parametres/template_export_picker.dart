import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/inscription.dart';
import '../../models/formation.dart';

// Small modal to pick a student (and optionally an inscription) to bind to a template
class TemplateExportPicker extends StatefulWidget {
  const TemplateExportPicker({Key? key}) : super(key: key);

  @override
  _TemplateExportPickerState createState() => _TemplateExportPickerState();
}

class _TemplateExportPickerState extends State<TemplateExportPicker> {
  late Future<List<Student>> _studentsFuture;
  Student? _selectedStudent;
  List<Inscription> _inscriptions = [];
  Inscription? _selectedInscription;

  @override
  void initState() {
    super.initState();
    _studentsFuture = DatabaseService().getStudents();
  }

  Future<void> _loadInscriptions(String studentId) async {
    final ins = await DatabaseService().getInscriptionsForStudent(studentId);
    setState(() => _inscriptions = ins);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionnez un étudiant / inscription'),
      content: SizedBox(
        width: 600,
        height: 320,
        child: FutureBuilder<List<Student>>(
          future: _studentsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final students = snap.data ?? [];
            return Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, i) {
                      final s = students[i];
                      return ListTile(
                        title: Text(s.name),
                        subtitle: Text(s.id),
                        selected: _selectedStudent?.id == s.id,
                        onTap: () {
                          setState(() {
                            _selectedStudent = s;
                            _selectedInscription = null;
                            _inscriptions = [];
                          });
                          _loadInscriptions(s.id);
                        },
                      );
                    },
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Inscriptions', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _inscriptions.isEmpty
                            ? const Center(child: Text('Aucune inscription'))
                            : ListView.builder(
                                itemCount: _inscriptions.length,
                                itemBuilder: (context, j) {
                                  final ins = _inscriptions[j];
                                  return ListTile(
                                    title: Text(ins.formationTitle ?? 'Formation'),
                                    subtitle: Text('ID: ${ins.id}'),
                                    selected: _selectedInscription?.id == ins.id,
                                    onTap: () => setState(() => _selectedInscription = ins),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _selectedStudent == null
              ? null
              : () async {
                  // Return a richer map containing student + inscription + formation info
                  final map = <String, dynamic>{
                    // Student identifiers and contact
                    'student_name': _selectedStudent!.name,
                    'client_name': _selectedStudent!.name, // alias used in some templates
                    'student_id': _selectedStudent!.id,
                    'student_number': _selectedStudent!.studentNumber,
                    'student_photo': _selectedStudent!.photo,
                    'client_phone': _selectedStudent!.phone,
                    'client_email': _selectedStudent!.email,
                    'client_address': _selectedStudent!.address,
                    // convenience aliases
                    'studentName': _selectedStudent!.name,
                    'studentId': _selectedStudent!.id,
                    'clientPhone': _selectedStudent!.phone,
                    'clientEmail': _selectedStudent!.email,
                    'clientAddress': _selectedStudent!.address,
                  };

                  if (_selectedInscription != null) {
                    // Basic inscription fields
                    map.addAll({
                      'inscription_id': _selectedInscription!.id,
                      'inscriptionDate': _selectedInscription!.inscriptionDate.toIso8601String(),
                      'inscription_date': _selectedInscription!.inscriptionDate.toIso8601String(),
                      'formation_name': _selectedInscription!.formationTitle ?? '',
                      'formationName': _selectedInscription!.formationTitle ?? '',
                      // grade / appraisal
                      'finalGrade': _selectedInscription!.finalGrade,
                      'final_grade': _selectedInscription!.finalGrade,
                      'appreciation': _selectedInscription!.appreciation ?? '',
                      // certificate and discount info
                      'certificate_path': _selectedInscription!.certificatePath ?? '',
                      'certificatePath': _selectedInscription!.certificatePath ?? '',
                      'discount_percent': _selectedInscription!.discountPercent ?? 0,
                      'discountPercent': _selectedInscription!.discountPercent ?? 0,
                    });

                    // Enrich with formation/session info if available
                    try {
                      final formations = await DatabaseService().getFormations();
                      final formation = formations.firstWhere((f) => f.id == _selectedInscription!.formationId, orElse: () => Formation(id: '', title: '', description: '', duration: '', price: 0.0, imageUrl: '', category: '', level: ''));
                      if (formation.id.isNotEmpty) {
                        map['duration'] = formation.duration;
                        map['formation_duration'] = formation.duration;
                        map['formationDuration'] = formation.duration;

                        // pick a sensible start date: prefer first session start, else inscription date
                        DateTime start = formation.sessions.isNotEmpty ? formation.sessions.first.startDate : _selectedInscription!.inscriptionDate;
                        String human = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
                        map['start_date'] = human;
                        map['startDate'] = human;
                        map['start_date_iso'] = start.toIso8601String();
                      }
                    } catch (_) {
                      // ignore failures to enrich — map still contains basic fields
                    }
                  }

                  Navigator.of(context).pop(map);
                },
          child: const Text('Utiliser'),
        ),
      ],
    );
  }
}
