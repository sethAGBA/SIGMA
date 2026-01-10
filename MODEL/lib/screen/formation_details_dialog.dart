import "dart:io";
import 'package:flutter/material.dart';
import 'package:afroforma/models/formateur.dart';
import 'package:afroforma/models/session.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:afroforma/services/notification_service.dart';
import 'package:afroforma/models/formation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:afroforma/services/storage_service.dart' as storage_service;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document.dart'; // Assuming this Document model is compatible or will be adapted
import 'package:path/path.dart' as p;

class FormationDetailsDialog extends StatefulWidget {
  final Formation formation;

  const FormationDetailsDialog({Key? key, required this.formation}) : super(key: key);

  @override
  _FormationDetailsDialogState createState() => _FormationDetailsDialogState();
}

class _FormationDetailsDialogState extends State<FormationDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Formateur> _formateurs;
  late List<Session> _sessions;
  late double _revenue;
  late double _directCosts;
  late double _indirectCosts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  // Create local mutable copies so the dialog can manage them
  _formateurs = List<Formateur>.from(widget.formation.formateurs);
  _sessions = List<Session>.from(widget.formation.sessions);
  _revenue = widget.formation.revenue;
  _directCosts = widget.formation.directCosts;
  _indirectCosts = widget.formation.indirectCosts;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocumentToFirebase() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      try {
  final storageService = storage_service.StorageService();
        final remotePath = 'courses/${widget.formation.id}/documents/$fileName';
        final String downloadUrl = await storageService.uploadFile(remotePath, file);

        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.formation.id)
            .collection('documents')
            .add({
              'name': fileName,
              'url': downloadUrl,
              'uploadedAt': FieldValue.serverTimestamp(),
            });

        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Document uploaded to Firebase successfully!',
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh the UI to show the new document

      } on FirebaseException catch (e) {
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Error uploading document to Firebase: ${e.message ?? e.code}',
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Unexpected error uploading document: $e',
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'No file selected.',
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.formation.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Onglets
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicator: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: 'Général'),
                  Tab(icon: Icon(Icons.person), text: 'Formateurs'),
                  Tab(icon: Icon(Icons.calendar_today), text: 'Sessions'),
                  Tab(icon: Icon(Icons.insert_drive_file), text: 'Documents'),
                  Tab(icon: Icon(Icons.analytics), text: 'Financier'),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Contenu des onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildFormateurTab(),
                  _buildSessionsTab(),
                  _buildDocumentsTab(),
                  _buildFinancialTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _imageProviderFor(String? path) {
    if (path == null || path.isEmpty) return const AssetImage('assets/images/placeholder.png');
    try {
      final uri = Uri.parse(path);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return NetworkImage(path);
      }
      // treat as local file
      return FileImage(File(path));
    } catch (e) {
      return const AssetImage('assets/images/placeholder.png');
    }
  }

  // persistence is handled via _saveAndPersist which saves to DB and returns the updated Formation

  Future<void> _saveAndPersist() async {
    setState(() {}); // to show any UI changes if needed
    final updated = widget.formation.copyWith(
      formateurs: _formateurs,
      sessions: _sessions,
      revenue: _revenue,
      directCosts: _directCosts,
      indirectCosts: _indirectCosts,
    );
    // show a blocking progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await DatabaseService().saveFormationTransaction(updated);

    Navigator.pop(context); // remove progress
    Navigator.pop(context, updated);
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard('Description', widget.formation.description),
          const SizedBox(height: 16),
          _buildInfoCard('Objectifs', widget.formation.objectives.isEmpty 
              ? 'Aucun objectif défini' : widget.formation.objectives),
          const SizedBox(height: 16),
          _buildInfoCard('Prérequis', widget.formation.prerequisites.isEmpty 
              ? 'Aucun prérequis' : widget.formation.prerequisites),
          const SizedBox(height: 16),
          _buildInfoCard('Durée', widget.formation.duration),
          const SizedBox(height: 16),
          _buildInfoCard('Tarification', '${widget.formation.price} FCFA'),
        ],
      ),
    );
  }

  Widget _buildFormateurTab() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _showAddEditFormateurDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 12),
        _formateurs.isEmpty
            ? const Center(
                child: Text(
                  'Aucun formateur assigné',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              )
            : Expanded(
                child: ListView.builder(
                  itemCount: _formateurs.length,
                  itemBuilder: (context, index) {
                    final formateur = _formateurs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        leading: formateur.photo.isNotEmpty
                            ? CircleAvatar(backgroundImage: _imageProviderFor(formateur.photo))
                            : CircleAvatar(
                                backgroundColor: const Color(0xFF10B981),
                                child: Text(
                                  formateur.name.isNotEmpty ? formateur.name[0] : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                        title: Text(
                              formateur.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                        onTap: () => _showFormateurDetails(formateur),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formateur.speciality, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            if (formateur.email.isNotEmpty) Text(formateur.email, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                            if (formateur.phone.isNotEmpty) Text(formateur.phone, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${formateur.hourlyRate.toStringAsFixed(0)} FCFA/h',
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                            ),
                                // Edit button (styled)
                                IconButton(
                                  onPressed: () => _showAddEditFormateurDialog(existing: formateur, index: index),
                                  icon: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF2563EB),
                                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                  ),
                                ),
                                // Delete button (styled)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _formateurs.removeAt(index);
                                    });
                                  },
                                  icon: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.redAccent,
                                    child: const Icon(Icons.delete, size: 16, color: Colors.white),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _showAddEditSessionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 12),
        _sessions.isEmpty
            ? const Center(
                child: Text(
                  'Aucune session programmée',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              )
            : Expanded(
                child: ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return InkWell(
                      onTap: () => _showSessionPreview(session),
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                session.name.isNotEmpty ? session.name : 'Session ${index + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(session.status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                      child: Text(
                                        _statusLabel(session.status),
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                  ),
                                  IconButton(
                                    onPressed: () => _showAddEditSessionDialog(existing: session, index: index),
                                    icon: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFF2563EB),
                                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _sessions.removeAt(index);
                                      });
                                    },
                                    icon: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.redAccent,
                                      child: const Icon(Icons.delete, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Salle: ${session.room}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          Text(
                            'Taux de remplissage: ${session.fillRate.toStringAsFixed(1)}%',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ));
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildFinancialTab() {
    final revenueController = TextEditingController(text: _revenue.toStringAsFixed(0));
    final directController = TextEditingController(text: _directCosts.toStringAsFixed(0));
    final indirectController = TextEditingController(text: _indirectCosts.toStringAsFixed(0));

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildFinancialCard('CA Généré', '${_revenue.toStringAsFixed(0)} FCFA', Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildFinancialCard('Coûts Directs', '${_directCosts.toStringAsFixed(0)} FCFA', Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildFinancialCard('Coûts Indirects', '${_indirectCosts.toStringAsFixed(0)} FCFA', Colors.red)),
              const SizedBox(width: 16),
              Expanded(child: _buildFinancialCard('Marge', '${(_revenue - (_directCosts + _indirectCosts)).toStringAsFixed(0)} FCFA', Colors.blue)),
            ],
          ),
          const SizedBox(height: 16),
          _buildFinancialCard('Marge (%)', '${((_revenue - (_directCosts + _indirectCosts)) / (_revenue > 0 ? _revenue : 1) * 100).toStringAsFixed(1)}%', Colors.purple),
          const SizedBox(height: 24),
          // Inline editors
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: revenueController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'CA Généré', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: directController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Coûts Directs', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: indirectController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: 'Coûts Indirects', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _revenue = double.tryParse(revenueController.text) ?? _revenue;
                    _directCosts = double.tryParse(directController.text) ?? _directCosts;
                    _indirectCosts = double.tryParse(indirectController.text) ?? _indirectCosts;
                  });
                },
                child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveAndPersist,
                child: const Text('Fermer et sauvegarder', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditFormateurDialog({Formateur? existing, int? index}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final specialityController = TextEditingController(text: existing?.speciality ?? '');
    final rateController = TextEditingController(text: existing != null ? existing.hourlyRate.toStringAsFixed(0) : '0');
  final photoController = TextEditingController(text: existing?.photo ?? '');
  final emailController = TextEditingController(text: existing?.email ?? '');
  final phoneController = TextEditingController(text: existing?.phone ?? '');
  final addressController = TextEditingController(text: existing?.address ?? '');
    final _formKey = GlobalKey<FormState>();

  final result = await showDialog<bool?>( 
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existing == null ? 'Nouveau formateur' : 'Modifier le formateur',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Nom', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis' : null,
                  ),
                  const SizedBox(height: 8),
                    TextFormField(
                    controller: specialityController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Spécialité', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'La spécialité est requise' : null,
                  ),
                  const SizedBox(height: 8),
                  // New fields: photo (url), email, phone, address
                  // Image picker at top (reuse ImagePickerWidget used elsewhere)
                  // ImagePickerWidget(
                  //   imagePath: photoController.text.isNotEmpty ? photoController.text : null,
                  //   imagePathController: photoController,
                  //   onPickImage: () async {
                  //     final res = await FilePicker.platform.pickFiles(type: FileType.image);
                  //     if (res != null && res.files.isNotEmpty) {
                  //       final file = res.files.first;
                  //       photoController.text = file.path ?? file.name;
                  //       setState(() {});
                  //     }
                  //   },
                  // ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Email', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && !v.contains('@')) return 'Entrez un email valide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Téléphone', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: addressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Adresse', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: rateController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Tarif horaire (FCFA)', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Entrez un tarif horaire valide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      setState(() {
        final formateur = Formateur(
          id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: nameController.text.trim(),
          speciality: specialityController.text.trim(),
          hourlyRate: double.tryParse(rateController.text) ?? 0.0,
          photo: photoController.text.trim(),
          email: emailController.text.trim(),
          phone: phoneController.text.trim(),
          address: addressController.text.trim(),
        );
        if (existing != null && index != null) {
          _formateurs[index] = formateur;
        } else {
          _formateurs.add(formateur);
        }
      });
    }
  }

  Future<void> _showAddEditSessionDialog({Session? existing, int? index}) async {
  DateTime start = existing?.startDate ?? DateTime.now();
  DateTime end = existing?.endDate ?? DateTime.now().add(const Duration(days: 30));
  final nameController = TextEditingController(text: existing?.name ?? '');
  final roomController = TextEditingController(text: existing?.room ?? '');
    final capacityController = TextEditingController(text: existing?.maxCapacity.toString() ?? '0');
    final enrollController = TextEditingController(text: existing?.currentEnrollments.toString() ?? '0');
    String status = existing?.status ?? 'planned';

  final result = await showDialog<List<String>?>( 
      context: context,
      builder: (context) {
    final _formKey = GlobalKey<FormState>();
  // local mutable selection that survives chip state
  final selectedIds = List<String>.from(existing?.formateurIds ?? []);
  return StatefulBuilder(builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(existing == null ? 'Nouvelle session' : 'Modifier la session', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Assign formateurs (multi-select)
                    Align(alignment: Alignment.centerLeft, child: const Text('Formateurs assignés', style: TextStyle(color: Colors.white70))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _formateurs.map((f) {
                        final selected = selectedIds.contains(f.id);
                        return StatefulBuilder(builder: (c2, setStateChip) {
                          return FilterChip(
                            label: Text(f.name),
                            selected: selected,
                            onSelected: (v) {
                              setStateChip(() {
                                if (v) {
                                  if (!selectedIds.contains(f.id)) selectedIds.add(f.id);
                                }
                                 else {
                                  selectedIds.remove(f.id);
                                }
                              });
                            },
                          );
                        });
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Nom de la session', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom de la session est requis' : null),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: Text('Début: ${start.toLocal().toString().split(' ').first}', style: const TextStyle(color: Colors.white))), TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setStateDialog(() => start = d); }, child: const Text('Sélectionner', style: TextStyle(color: Colors.white70)))]),
                    Row(children: [Expanded(child: Text('Fin: ${end.toLocal().toString().split(' ').first}', style: const TextStyle(color: Colors.white))), TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setStateDialog(() => end = d); }, child: const Text('Sélectionner', style: TextStyle(color: Colors.white70)))]),
                    const SizedBox(height: 8),
                    TextFormField(controller: roomController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Salle', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)), validator: (v) => (v == null || v.trim().isEmpty) ? 'La salle est requise' : null),
                    const SizedBox(height: 8),
                    TextFormField(controller: capacityController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Capacité max', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)), validator: (v) => (int.tryParse(v ?? '') == null || int.tryParse(v ?? '')! < 0) ? 'Entrez une capacité valide' : null),
                    const SizedBox(height: 8),
                    TextFormField(controller: enrollController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Inscriptions', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black.withOpacity(0.25)), validator: (v) => (int.tryParse(v ?? '') == null || int.tryParse(v ?? '')! < 0) ? 'Entrez un nombre valide' : null),
                    const SizedBox(height: 8),
                    DropdownButton<String>(value: status, dropdownColor: const Color(0xFF111827), items: const [DropdownMenuItem(value: 'planned', child: Text('Planifiée')), DropdownMenuItem(value: 'ongoing', child: Text('En cours')), DropdownMenuItem(value: 'completed', child: Text('Terminée')), DropdownMenuItem(value: 'cancelled', child: Text('Annulée'))], onChanged: (v) => setStateDialog(() => status = v ?? status)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (!(_formKey.currentState?.validate() ?? false)) return;
                            final startMs = start.millisecondsSinceEpoch;
                            final endMs = end.millisecondsSinceEpoch;
                            final conflict = await DatabaseService().checkSessionConflict(
                              formationId: widget.formation.id,
                              startMs: startMs,
                              endMs: endMs,
                              excludeSessionId: existing?.id,
                            );
                            if (conflict) {
                              await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Conflit de planning'), content: const Text('Cette session entre en conflit avec une autre session existante.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
                              return;
                            }
                            Navigator.pop(context, selectedIds);
                          },
                          child: const Text('Enregistrer'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );

    if (result != null) {
    setState(() {
        final session = Session(
          id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: nameController.text.isNotEmpty ? nameController.text : (existing?.name ?? 'Nouvelle session'),
          startDate: start,
          endDate: end,
          room: roomController.text,
      formateurIds: result,
          maxCapacity: int.tryParse(capacityController.text) ?? 0,
          currentEnrollments: int.tryParse(enrollController.text) ?? 0,
          status: status,
        );
        if (existing != null && index != null) {
          _sessions[index] = session;
        } else {
          _sessions.add(session);
        }
      });
    }
  }

  Future<void> _showSessionPreview(Session s) async {
  final assigned = _formateurs.where((f) => s.formateurIds.contains(f.id)).toList();
  // If the session has assigned formateurs, show them. Otherwise, if the formation
  // has formateurs, show those. Fallback to 'Inconnu' only when there are none.
  final displayFormateurs = assigned.isNotEmpty ? assigned : (_formateurs.isNotEmpty ? _formateurs : []);
    await showDialog(context: context, builder: (c) {
      return Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text('${s.startDate.toLocal().toString().split(' ').first} → ${s.endDate.toLocal().toString().split(' ').first}', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.place, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(s.room, style: TextStyle(color: Colors.white.withOpacity(0.8))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: displayFormateurs.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Formateur(s):', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: displayFormateurs.map((f) {
                              return GestureDetector(
                                onTap: () => _showFormateurDetails(f),
                                child: Text(f.name, style: TextStyle(color: Colors.white.withOpacity(0.95), decoration: TextDecoration.underline)),
                              );
                            }).toList(),
                          ),
                        ],
                      )
                    : Text('Formateur(s): Inconnu', style: TextStyle(color: Colors.white.withOpacity(0.8))),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Capacité: ${s.maxCapacity} • Inscrits: ${s.currentEnrollments}', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Fermer'))
            ])
          ]),
        ),
      );
    });
  }

  Widget _buildInfoCard(String title, String content) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'planned': return Colors.blue;
      case 'ongoing': return Colors.green;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'planned': return 'Planifiée';
      case 'ongoing': return 'En cours';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  Widget _buildDocumentsTab() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(allowMultiple: false);
                  if (res == null || res.files.isEmpty) return;
                  final f = res.files.first;
                  final savedPath = f.path ?? '';
                  final doc = Document(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    formationId: widget.formation.id,
                    fileName: f.name,
                    path: savedPath,
                    mimeType: f.extension ?? '',
                    size: f.size,
                  );
                  await DatabaseService().insertDocument(doc);
                  setState(() {});
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Ajouter un document (SQLite)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _uploadDocumentToFirebase, // Call the new upload function
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Ajouter un document (Firebase)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<dynamic>>( 
            future: _getAllDocuments(), // Fetch from both sources
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!;
              if (docs.isEmpty) return const Center(child: Text('Aucun document', style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  String name;
                  String url;
                  bool isFirebaseDoc = false;

                  if (d is Document) { // SQLite Document
                    name = d.fileName;
                    url = d.path; // Local path for SQLite docs
                  } else { // Firebase Document (Map<String, dynamic>)
                    name = d['name'] ?? '';
                    url = d['url'] ?? '';
                    isFirebaseDoc = true;
                  }

                  return ListTile(
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(url, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    onTap: () => isFirebaseDoc ? _openUrl(url) : _openOrPreviewDocument(d as Document),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isFirebaseDoc) IconButton(icon: const Icon(Icons.open_in_new, color: Colors.white70), onPressed: () => _openUrl(url)),
                      if (!isFirebaseDoc) IconButton(icon: const Icon(Icons.download, color: Colors.white70), onPressed: () => _saveDocumentToFolder(d as Document)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () async {
                        if (isFirebaseDoc) {
                          await _deleteDocumentFromFirestore(d['id']);
                        } else {
                          await DatabaseService().deleteDocument(d.id);
                        }
                        setState(() {});
                      }),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<dynamic>> _getAllDocuments() async {
    final sqliteDocs = await DatabaseService().getDocumentsByFormation(widget.formation.id);
    final firebaseDocs = await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.formation.id)
        .collection('documents')
        .get();
    
    final List<dynamic> allDocs = [];
    allDocs.addAll(sqliteDocs);
    allDocs.addAll(firebaseDocs.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
    return allDocs;
  }

  Future<void> _deleteDocumentFromFirestore(String docId) async {
    await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.formation.id)
        .collection('documents')
        .doc(docId)
        .delete();
    NotificationService().showNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: 'Document Firebase supprimé!',
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Impossible d\'ouvrir le lien: $url',
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFormateurDetails(Formateur f) async {
    await showDialog(context: context, builder: (c) {
      return Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 40, backgroundImage: _imageProviderFor(f.photo)),
            const SizedBox(height: 12),
            Text(f.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(f.speciality, style: TextStyle(color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 8),
            if (f.email.isNotEmpty) Text('Email: ${f.email}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            if (f.phone.isNotEmpty) Text('Téléphone: ${f.phone}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            if (f.address.isNotEmpty) Text('Adresse: ${f.address}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 12),
            Text('Tarif: ${f.hourlyRate.toStringAsFixed(0)} FCFA/h', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Fermer'))
          ]),
        ),
      );
    });
  }

  Future<void> _openOrPreviewDocument(Document d) async {
    final path = d.path;
    if (path.isEmpty) return;
    final lower = path.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif')) {
      // show image preview
      await showDialog(context: context, builder: (c) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(child: Image.file(File(path))),
      ));
      return;
    }
    // For others, try to open with OS default app
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      }
    } catch (e) {
      // fallback: show an alert
      NotificationService().showNotification(
        NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Impossible d\'ouvrir le document: ${e.toString()}',
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveDocumentToFolder(Document d) async {
    final targetDir = await FilePicker.platform.getDirectoryPath();
    if (targetDir == null) return; // user cancelled
    try {
      final src = File(d.path);
      final destPath = p.join(targetDir, d.fileName);
      await src.copy(destPath);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document enregistré')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }
}
