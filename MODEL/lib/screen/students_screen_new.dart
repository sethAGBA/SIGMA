// import 'dart:io';

// import 'package:afroforma/models/inscription.dart';
// import 'package:afroforma/utils/receipt_generator.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';

// import '../models/document.dart';
// import '../models/formation.dart';
// import '../models/student.dart';
// import '../services/database_service.dart';

// class StudentsScreen extends StatefulWidget {
//   @override
//   _StudentsScreenState createState() => _StudentsScreenState();
// }

// class _StudentsScreenState extends State<StudentsScreen> {
//   static const Color primaryAccent = Color(0xFF06B6D4);
//   static const Color primaryAccentDark = Color(0xFF0891B2);

//   final List<Student> _students = [];
//   final List<Formation> _formations = [];
//   final Map<String, Formation> _formationMap = {};
//   final Set<String> _selected = {};

//   String _search = '';
//   String _filterFormation = 'Toutes';
//   String _filterPayment = 'Tous';

//   @override
//   void initState() {
//     super.initState();
//     _loadStudents();
//     _loadFormations();
//   }

//   Future<void> _loadStudents() async {
//     final rows = await DatabaseService().getStudents();
//     setState(() {
//       _students
//         ..clear()
//         ..addAll(rows);
//     });
//   }

//   Future<void> _loadFormations() async {
//     try {
//       final rows = await DatabaseService().getFormations();
//       setState(() {
//         _formations
//           ..clear()
//           ..addAll(rows);
//         _formationMap.clear();
//         for (final f in rows) _formationMap[f.id] = f;
//       });
//     } catch (_) {}
//   }

//   bool _isValidEmail(String? v) {
//     if (v == null || v.trim().isEmpty) return false;
//     final re = RegExp(r"""^[^\s@]+@[^\s@]+\.[^\s@]+$""");
//     return re.hasMatch(v.trim());
//   }

//   bool _isValidPhone(String? v) {
//     if (v == null || v.isEmpty) return true;
//     return RegExp(r'^[0-9 +()\-]{6,}$').hasMatch(v);
//   }

//   Future<void> _openFile(String path) async {
//     try {
//       final f = File(path);
//       if (!f.existsSync()) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Fichier introuvable')));
//         return;
//       }
//       if (Platform.isMacOS)
//         await Process.run('open', [path]);
//       else if (Platform.isLinux)
//         await Process.run('xdg-open', [path]);
//       else if (Platform.isWindows)
//         await Process.run('cmd', ['/c', 'start', '', path]);
//       else
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Ouverture non supportée')),
//         );
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Erreur ouverture fichier: $e')));
//     }
//   }

//   Future<void> _sendEmail(
//     String to, {
//     String subject = '',
//     String body = '',
//   }) async {
//     if (to.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Aucun email disponible')));
//       return;
//     }
//     try {
//       final mailto =
//           'mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
//       if (Platform.isMacOS)
//         await Process.run('open', [mailto]);
//       else if (Platform.isLinux)
//         await Process.run('xdg-open', [mailto]);
//       else if (Platform.isWindows)
//         await Process.run('cmd', ['/c', 'start', '', mailto]);
//       else
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Envoi d'email non supporté")),
//         );
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Erreur ouverture mail: $e')));
//     }
//   }

//   List<Student> get _visible => _students.where((s) {
//     final matchesSearch =
//         _search.isEmpty ||
//         s.name.toLowerCase().contains(_search.toLowerCase()) ||
//         s.phone.contains(_search) ||
//         s.email.toLowerCase().contains(_search.toLowerCase());
//     final matchesFormation =
//         _filterFormation == 'Toutes' || s.formation == _filterFormation;
//     final matchesPayment =
//         _filterPayment == 'Tous' || s.paymentStatus == _filterPayment;
//     return matchesSearch && matchesFormation && matchesPayment;
//   }).toList();

//   Future<void> _showStudentDetails(Student s) async {
//     await showDialog(
//       context: context,
//       builder: (c) => StatefulBuilder(
//         builder: (context, setStateDialog) {
//           Future<List<Document>> docsFuture =
//               DatabaseService().getDocumentsByStudent(s.id);
//           Future<List<Inscription>> inscriptionsFuture =
//               DatabaseService().getInscriptionsForStudent(s.id);

//           void reloadDocs() => setStateDialog(
//             () => docsFuture = DatabaseService().getDocumentsByStudent(s.id),
//           );

//           void reloadInscriptions() => setStateDialog(
//             () => inscriptionsFuture =
//                 DatabaseService().getInscriptionsForStudent(s.id),
//           );

//           return Dialog(
//             backgroundColor: const Color(0xFF0B1220),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: SizedBox(
//               width: 1000,
//               height: 560,
//               child: Padding(
//                 padding: const EdgeInsets.all(24.0),
//                 child: DefaultTabController(
//                   length: 4,
//                   child: Column(
//                     children: [
//                       // Header
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text(
//                             'Fiche Étudiant',
//                             style: TextStyle(
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.close, color: Colors.white),
//                             onPressed: () => Navigator.pop(context),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         child: const TabBar(
//                           tabs: [
//                             Tab(text: 'Infos'),
//                             Tab(text: 'Parcours'),
//                             Tab(text: 'Finances'),
//                             Tab(text: 'Communication'),
//                           ],
//                         ),
//                       ),
//                       Expanded(
//                         child: TabBarView(
//                           children: [
//                             // Infos
//                             SingleChildScrollView(
//                               padding: const EdgeInsets.all(16),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       CircleAvatar(
//                                         radius: 48,
//                                         backgroundImage: s.photo.isNotEmpty
//                                             ? FileImage(File(s.photo))
//                                             : null,
//                                         child: s.photo.isNotEmpty
//                                             ? null
//                                             : Text(s.name.isNotEmpty
//                                                 ? s.name[0]
//                                                 : '?'),
//                                       ),
//                                       const SizedBox(width: 12),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               s.name,
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 18,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 6),
//                                             Text(
//                                               'Formation: ${_formationMap[s.formation]?.title ?? s.formation}',
//                                               style: TextStyle(
//                                                 color: Colors.white.withOpacity(
//                                                   0.85,
//                                                 ),
//                                               ),
//                                             ),
//                                             if (s.email.isNotEmpty)
//                                               Text(
//                                                 'Email: ${s.email}',
//                                                 style: TextStyle(
//                                                   color:
//                                                       Colors.white.withOpacity(
//                                                     0.75,
//                                                   ),
//                                                 ),
//                                               ),
//                                             if (s.phone.isNotEmpty)
//                                               Text(
//                                                 'Téléphone: ${s.phone}',
//                                                 style: TextStyle(
//                                                   color:
//                                                       Colors.white.withOpacity(
//                                                     0.75,
//                                                   ),
//                                                 ),
//                                               ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 12),
//                                   const Text(
//                                     'Documents joints',
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 const SizedBox(height: 8),
//                                 FutureBuilder<List<Document>>(
//                                   future: docsFuture,
//                                   builder: (ctx, snap) {
//                                     if (snap.connectionState !=
//                                         ConnectionState.done)
//                                       return const SizedBox();
//                                     final docs = snap.data ?? [];
//                                     if (docs.isEmpty)
//                                       return const Text(
//                                         'Aucun document',
//                                         style: TextStyle(color: Colors.white70),
//                                       );
//                                     return Column(
//                                       children: docs
//                                           .map(
//                                             (d) => Card(
//                                               color: const Color(0xFF0F1724),
//                                               child: ListTile(
//                                                 title: Text(
//                                                   d.fileName,
//                                                   style: const TextStyle(
//                                                     color: Colors.white70,
//                                                   ),
//                                                 ),
//                                                 subtitle: Column(
//                                                   crossAxisAlignment:
//                                                       CrossAxisAlignment.start,
//                                                   children: [
//                                                     Text(
//                                                       'Titre: ${d.title}',
//                                                       style: const TextStyle(
//                                                         color: Colors.white54,
//                                                       ),
//                                                     ),
//                                                     Text(
//                                                       'Catégorie: ${d.category}',
//                                                       style: const TextStyle(
//                                                         color: Colors.white54,
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                                 trailing: Row(
//                                                   mainAxisSize:
//                                                       MainAxisSize.min,
//                                                   children: [
//                                                     IconButton(
//                                                       icon: const Icon(
//                                                         Icons.edit,
//                                                       ),
//                                                       onPressed: () async {
//                                                         final titleCtrl =
//                                                             TextEditingController(
//                                                               text: d.title,
//                                                             );
//                                                         final categoryCtrl =
//                                                             TextEditingController(
//                                                               text: d.category,
//                                                             );
//                                                         await showDialog(
//                                                           context: context,
//                                                           builder: (ctx) => AlertDialog(
//                                                             title: const Text(
//                                                               'Modifier document',
//                                                             ),
//                                                             content: Column(
//                                                               mainAxisSize:
//                                                                   MainAxisSize
//                                                                       .min,
//                                                               children: [
//                                                                 TextField(
//                                                                   controller:
//                                                                       titleCtrl,
//                                                                   decoration:
//                                                                       const InputDecoration(
//                                                                         labelText:
//                                                                             'Titre',
//                                                                       ),
//                                                                 ),
//                                                                 TextField(
//                                                                   controller:
//                                                                       categoryCtrl,
//                                                                   decoration:
//                                                                       const InputDecoration(
//                                                                         labelText:
//                                                                             'Catégorie',
//                                                                       ),
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                             actions: [
//                                                               TextButton(
//                                                                 onPressed: () =>
//                                                                     Navigator.pop(
//                                                                       ctx,
//                                                                     ),
//                                                                 child:
//                                                                     const Text(
//                                                                       'Annuler',
//                                                                     ),
//                                                               ),
//                                                               ElevatedButton(
//                                                                 onPressed: () async {
//                                                                   if (titleCtrl
//                                                                       .text
//                                                                       .trim()
//                                                                       .isEmpty) {
//                                                                     ScaffoldMessenger.of(
//                                                                       context,
//                                                                     ).showSnackBar(
//                                                                       const SnackBar(
//                                                                         content:
//                                                                             Text(
//                                                                               'Le titre est requis',
//                                                                             ),
//                                                                       ),
//                                                                     );
//                                                                     return;
//                                                                   }
//                                                                   await DatabaseService().updateDocument({
//                                                                     'id': d.id,
//                                                                     'title':
//                                                                         titleCtrl
//                                                                             .text,
//                                                                     'category':
//                                                                         categoryCtrl
//                                                                             .text,
//                                                                   });
//                                                                   reloadDocs();
//                                                                   Navigator.pop(
//                                                                     ctx,
//                                                                   );
//                                                                 },
//                                                                 child: const Text(
//                                                                   'Enregistrer',
//                                                                 ),
//                                                               ),
//                                                             ],
//                                                           ),
//                                                         );
//                                                       },
//                                                     ),
//                                                     IconButton(
//                                                       icon: const Icon(
//                                                         Icons.download,
//                                                       ),
//                                                       onPressed: () async {
//                                                         if (d.path.isNotEmpty)
//                                                           await _openFile(
//                                                             d.path,
//                                                           );
//                                                         else
//                                                           ScaffoldMessenger.of(
//                                                             context,
//                                                           ).showSnackBar(
//                                                             const SnackBar(
//                                                               content: Text(
//                                                                 'Aucun fichier',
//                                                               ),
//                                                             ),
//                                                           );
//                                                       },
//                                                     ),
//                                                     IconButton(
//                                                       icon: const Icon(
//                                                         Icons.delete,
//                                                       ),
//                                                       onPressed: () async {
//                                                         await DatabaseService()
//                                                             .deleteDocument(
//                                                               d.id,
//                                                             );
//                                                         reloadDocs();
//                                                       },
//                                                     ),
//                                                   ],
//                                                 ),
//                                               ),
//                                             ),
//                                           )
//                                           .toList(),
//                                     );
//                                   },
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Row(
//                                   children: [
//                                     ElevatedButton.icon(
//                                       onPressed: () async {
//                                         final res = await FilePicker.platform
//                                             .pickFiles();
//                                         if (res == null || res.files.isEmpty)
//                                           return;
//                                         final f = res.files.first;
//                                         final tmpPath = f.path!;
//                                         final fileName = p.basename(tmpPath);
//                                         final titleCtrl = TextEditingController(
//                                           text: fileName,
//                                         );
//                                         final categoryCtrl =
//                                             TextEditingController();
//                                         await showDialog(
//                                           context: context,
//                                           builder: (ctx) {
//                                             return AlertDialog(
//                                               title: const Text(
//                                                 'Ajouter document',
//                                               ),
//                                               content: Column(
//                                                 mainAxisSize: MainAxisSize.min,
//                                                 children: [
//                                                   TextField(
//                                                     controller: titleCtrl,
//                                                     decoration:
//                                                         const InputDecoration(
//                                                           labelText: 'Titre',
//                                                         ),
//                                                   ),
//                                                   TextField(
//                                                     controller: categoryCtrl,
//                                                     decoration:
//                                                         const InputDecoration(
//                                                           labelText:
//                                                               'Catégorie',
//                                                         ),
//                                                   ),
//                                                 ],
//                                               ),
//                                               actions: [
//                                                 TextButton(
//                                                   onPressed: () =>
//                                                       Navigator.pop(ctx),
//                                                   child: const Text('Annuler'),
//                                                 ),
//                                                 ElevatedButton(
//                                                   onPressed: () async {
//                                                     if (titleCtrl.text
//                                                         .trim()
//                                                         .isEmpty) {
//                                                       ScaffoldMessenger.of(
//                                                         context,
//                                                       ).showSnackBar(
//                                                         const SnackBar(
//                                                           content: Text(
//                                                             'Le titre est requis',
//                                                           ),
//                                                         ),
//                                                       );
//                                                       return;
//                                                     }
//                                                     final documentsDir =
//                                                         await getApplicationDocumentsDirectory();
//                                                     final attachmentsDir =
//                                                         Directory(
//                                                           p.join(
//                                                             documentsDir.path,
//                                                             'attachments',
//                                                             s.id,
//                                                           ),
//                                                         );
//                                                     if (!attachmentsDir
//                                                         .existsSync())
//                                                       attachmentsDir.createSync(
//                                                         recursive: true,
//                                                       );
//                                                     final destPath = p.join(
//                                                       attachmentsDir.path,
//                                                       fileName,
//                                                     );
//                                                     await File(
//                                                       tmpPath,
//                                                     ).copy(destPath);

//                                                     final doc = Document(
//                                                       id: DateTime.now()
//                                                           .millisecondsSinceEpoch
//                                                           .toString(),
//                                                       formationId: s.formation,
//                                                       studentId: s.id,
//                                                       title: titleCtrl.text,
//                                                       category:
//                                                           categoryCtrl.text,
//                                                       fileName: fileName,
//                                                       path: destPath,
//                                                     );
//                                                     await DatabaseService()
//                                                         .insertDocument(doc);
//                                                     reloadDocs();
//                                                     Navigator.pop(ctx);
//                                                   },
//                                                   child: const Text('Ajouter'),
//                                                 ),
//                                               ],
//                                             );
//                                           },
//                                         );
//                                       },
//                                       icon: const Icon(Icons.upload_file),
//                                       label: const Text('Ajouter document'),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     TextButton(
//                                       onPressed: () {},
//                                       child: const Text('Télécharger tout'),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),

//                           // Parcours
//                           FutureBuilder<List<Inscription>>(
//                             future: inscriptionsFuture,
//                             builder: (context, snapshot) {
//                               if (snapshot.connectionState ==
//                                   ConnectionState.waiting) {
//                                 return const Center(
//                                   child: CircularProgressIndicator(),
//                                 );
//                               }
//                               if (snapshot.hasError) {
//                                 return Center(
//                                   child: Text(
//                                     'Erreur: ${snapshot.error}',
//                                     style: const TextStyle(
//                                       color: Colors.white70,
//                                     ),
//                                   ),
//                                 );
//                               }
//                               final inscriptions = snapshot.data ?? [];
//                               if (inscriptions.isEmpty) {
//                                 return const Center(
//                                   child: Column(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       Icon(
//                                         Icons.school_outlined,
//                                         size: 48,
//                                         color: Colors.white54,
//                                       ),
//                                       SizedBox(height: 12),
//                                       Text(
//                                         'Aucun parcours académique trouvé',
//                                         style: TextStyle(color: Colors.white70),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               }
//                               return ListView.builder(
//                                 itemCount: inscriptions.length,
//                                 itemBuilder: (context, index) {
//                                   final inscription = inscriptions[index];
//                                   return Card(
//                                     color: const Color(0xFF0F1724),
//                                     margin: const EdgeInsets.symmetric(
//                                       vertical: 8,
//                                       horizontal: 16,
//                                     ),
//                                     child: ListTile(
//                                       leading: const Icon(
//                                         Icons.school,
//                                         color: primaryAccent,
//                                       ),
//                                       title: Text(
//                                         inscription.formationTitle ??
//                                             'Formation inconnue',
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                       subtitle: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             'Inscrit le: ${DateFormat.yMMMd('fr_FR').format(inscription.inscriptionDate)}',
//                                             style: const TextStyle(
//                                               color: Colors.white70,
//                                             ),
//                                           ),
//                                           Text(
//                                             'Statut: ${inscription.status}',
//                                             style: const TextStyle(
//                                               color: Colors.white70,
//                                             ),
//                                           ),
//                                           if (inscription.finalGrade != null)
//                                             Text(
//                                               'Note finale: ${inscription.finalGrade}',
//                                               style: const TextStyle(
//                                                 color: Colors.white70,
//                                               ),
//                                             ),
//                                         ],
//                                       ),
//                                       trailing: Row(
//                                         mainAxisSize: MainAxisSize.min,
//                                         children: [
//                                           if (inscription.certificatePath != null && inscription.certificatePath!.isNotEmpty)
//                                             IconButton(
//                                               icon: const Icon(
//                                                 Icons.card_membership,
//                                                 color: Colors.amber,
//                                               ),
//                                               tooltip: 'Voir le certificat',
//                                               onPressed: () => _openFile(inscription.certificatePath!),
//                                             ),
//                                           IconButton(
//                                             icon: const Icon(Icons.upload_file, color: Colors.white70),
//                                             tooltip: 'Joindre un certificat',
//                                             onPressed: () async {
//                                               final res = await FilePicker.platform.pickFiles(
//                                                 type: FileType.custom,
//                                                 allowedExtensions: ['pdf', 'png', 'jpg'],
//                                               );
//                                               if (res == null || res.files.isEmpty) return;

//                                               final f = res.files.first;
//                                               final tmpPath = f.path!;
//                                               final fileName = p.basename(tmpPath);

//                                               final documentsDir = await getApplicationDocumentsDirectory();
//                                               final certsDir = Directory(p.join(documentsDir.path, 'certificates', s.id));
//                                               if (!certsDir.existsSync()) certsDir.createSync(recursive: true);

//                                               final destPath = p.join(certsDir.path, fileName);
//                                               await File(tmpPath).copy(destPath);

//                                               await DatabaseService().updateInscriptionCertificate(inscription.id, destPath);
//                                               reloadInscriptions();

//                                               ScaffoldMessenger.of(context).showSnackBar(
//                                                 const SnackBar(content: Text('Certificat ajouté avec succès.')),
//                                               );
//                                             },
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               );
//                             },
//                           ),

//                           // Finances
//                           // Finances
//                           FutureBuilder<List<Inscription>>(
//                             future: inscriptionsFuture,
//                             builder: (context, snapshot) {
//                               if (snapshot.connectionState == ConnectionState.waiting) {
//                                 return const Center(child: CircularProgressIndicator());
//                               }
//                               if (snapshot.hasError) {
//                                 return Center(child: Text('Erreur: ${snapshot.error}'));
//                               }
//                               final inscriptions = snapshot.data ?? [];
//                               if (inscriptions.isEmpty) {
//                                 return const Center(child: Text('Aucune inscription trouvée.'));
//                               }
//                               return ListView.builder(
//                                 itemCount: inscriptions.length,
//                                 itemBuilder: (context, index) {
//                                   final inscription = inscriptions[index];
//                                   final formation = _formationMap[inscription.formationId];
//                                   return Card(
//                                     margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//                                     color: const Color(0xFF0F1724),
//                                     child: FutureBuilder<List<Map<String, Object?>>>(
//                                       future: DatabaseService().getPaymentsByStudent(s.id, inscriptionId: inscription.id),
//                                       builder: (context, paymentSnapshot) {
//                                         final payments = paymentSnapshot.data ?? [];
//                                         final totalPaid = payments.fold<double>(0, (prev, p) => prev + (p['amount'] as double? ?? 0));
//                                         final formationPrice = formation?.price ?? 0.0;
//                                         final balance = formationPrice - totalPaid;

//                                         Widget balanceWidget;
//                                         if (balance > 0.01) { // Use a small epsilon for float comparison
//                                           balanceWidget = Text('Solde restant: ${balance.toStringAsFixed(2)} XOF', style: const TextStyle(color: Colors.orange));
//                                         } else if (balance < -0.01) {
//                                           balanceWidget = Text('Avance: ${(-balance).toStringAsFixed(2)} XOF', style: const TextStyle(color: Colors.blueAccent));
//                                         } else {
//                                           balanceWidget = const Text('Soldé', style: TextStyle(color: Colors.green));
//                                         }

//                                         return ExpansionTile(
//                                           title: Text(inscription.formationTitle ?? 'Formation inconnue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//                                           subtitle: balanceWidget,
//                                           children: [
//                                             Padding(
//                                               padding: const EdgeInsets.all(16.0),
//                                               child: Column(
//                                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                                 children: [
//                                                   Text('Prix de la formation: ${formationPrice.toStringAsFixed(2)} XOF'),
//                                                   Text('Total payé: ${totalPaid.toStringAsFixed(2)} XOF'),
//                                                   const SizedBox(height: 16),
//                                                   const Text('Historique des paiements:', style: TextStyle(fontWeight: FontWeight.bold)),
//                                                   if (payments.isEmpty)
//                                                     const Text('Aucun paiement pour cette formation.')
//                                                   else
//                                                     ...payments.map((p) => ListTile(
//                                                       title: Text('${p['amount']} XOF - ${p['method']}'),
//                                                       subtitle: Text(DateFormat.yMMMd('fr_FR').format(DateTime.fromMillisecondsSinceEpoch(p['createdAt'] as int))),
//                                                       trailing: IconButton(
//                                                         icon: const Icon(Icons.print, color: Colors.white54),
//                                                         onPressed: () async {
//                                                           // let user choose where to save: app storage or external directory
//                                                           final choice = await showDialog<String?>(
//                                                             context: context,
//                                                             builder: (ctx) => SimpleDialog(
//                                                               title: const Text('Sauvegarder le reçu'),
//                                                               children: [
//                                                                 SimpleDialogOption(
//                                                                   onPressed: () => Navigator.pop(ctx, 'app'),
//                                                                   child: const Text("Sauvegarder dans l'app"),
//                                                                 ),
//                                                                 SimpleDialogOption(
//                                                                   onPressed: () => Navigator.pop(ctx, 'choose'),
//                                                                   child: const Text('Choisir un répertoire'),
//                                                                 ),
//                                                                 SimpleDialogOption(
//                                                                   onPressed: () => Navigator.pop(ctx, null),
//                                                                   child: const Text('Annuler'),
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           );

//                                                           if (choice == null) return;

//                                                           if (choice == 'app') {
//                                                             try {
//                                                               final savedPath = await generateAndSaveReceipt(s, formation, p, payments, balance, inscriptionId: inscription.id);
//                                                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reçu sauvegardé dans l\'app: $savedPath')));
//                                                                 reloadDocs();
//                                                             } catch (e) {
//                                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec sauvegarde: $e')));
//                                                               await generateAndPrintReceipt(s, formation, p, payments, balance);
//                                                             }
//                                                           } else if (choice == 'choose') {
//                                                             try {
//                                                               final dirPath = await FilePicker.platform.getDirectoryPath();
//                                                               if (dirPath == null) return; // user cancelled
//                                                               final bytes = await generateReceiptPdfBytes(s, formation, p, payments, balance, inscriptionId: inscription.id);
//                                                               final fileName = 'receipt_${inscription.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
//                                                               final filePath = '$dirPath${Platform.pathSeparator}$fileName';
//                                                               final file = File(filePath);
//                                                               await file.writeAsBytes(bytes, flush: true);

//                                                               // register as document in DB pointing to external path
//                                                               final doc = Document(
//                                                                 id: DateTime.now().millisecondsSinceEpoch.toString(),
//                                                                 formationId: formation?.id ?? '',
//                                                                 studentId: s.id,
//                                                                 title: 'Reçu paiement ${formation?.title ?? ''}',
//                                                                 category: 'reçu',
//                                                                 fileName: fileName,
//                                                                 path: filePath,
//                                                                 mimeType: 'application/pdf',
//                                                                 size: bytes.length,
//                                                               );
//                                                               await DatabaseService().insertDocument(doc);
//                                                               reloadDocs();

//                                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reçu sauvegardé: $filePath')));
//                                                             } catch (e) {
//                                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur sauvegarde: $e')));
//                                                             }
//                                                           }
//                                                         },
//                                                       ),
//                                                       dense: true,
//                                                     )),
//                                                   const SizedBox(height: 8),
//                                                   ElevatedButton.icon(
//                                                     icon: const Icon(Icons.payment),
//                                                     label: const Text('Ajouter un paiement'),
//                                                     onPressed: () async {
//                                                       final amountCtrl = TextEditingController();
//                                                       final noteCtrl = TextEditingController();

//                                                       await showDialog(
//                                                         context: context,
//                                                         builder: (ctx) {
//                                                           String selectedMethod = '';
//                                                           final paymentMethods = ['Espèces', 'Carte', 'Mobile Money', 'Virement', 'Chèque', 'Autre'];
//                                                           return StatefulBuilder(
//                                                             builder: (ctx2, setStateInner) {
//                                                               return AlertDialog(
//                                                                 title: const Text('Ajouter paiement'),
//                                                                 content: Column(
//                                                                   mainAxisSize: MainAxisSize.min,
//                                                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                                                   children: [
//                                                                     Text('Solde restant: ${balance.toStringAsFixed(2)} XOF', style: const TextStyle(fontWeight: FontWeight.bold)),
//                                                                     const SizedBox(height: 16),
//                                                                     TextFormField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Montant'), keyboardType: TextInputType.number),
//                                                                     const SizedBox(height: 8),
//                                                                     DropdownButtonFormField<String>(
//                                                                       value: selectedMethod.isEmpty ? null : selectedMethod,
//                                                                       decoration: const InputDecoration(labelText: 'Méthode'),
//                                                                       items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
//                                                                       onChanged: (v) => setStateInner(() => selectedMethod = v ?? ''),
//                                                                     ),
//                                                                     const SizedBox(height: 8),
//                                                                     TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (facultatif)')),
//                                                                   ],
//                                                                 ),
//                                                                 actions: [
//                                                                   TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Annuler')),
//                                                                   ElevatedButton(
//                                                                     onPressed: () async {
//                                                                       final amount = double.tryParse(amountCtrl.text) ?? 0.0;
//                                                                       if (amount <= 0) {
//                                                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le montant doit être positif.')));
//                                                                         return;
//                                                                       }

//                                                                       if (amount > balance) {
//                                                                         final confirm = await showDialog<bool>(
//                                                                           context: context,
//                                                                           builder: (alertCtx) => AlertDialog(
//                                                                             title: const Text('Confirmation requise'),
//                                                                             content: const Text('Le montant saisi est supérieur au solde restant. Voulez-vous enregistrer ce paiement comme une avance ?'),
//                                                                             actions: [
//                                                                               TextButton(onPressed: () => Navigator.pop(alertCtx, false), child: const Text('Non')),
//                                                                               TextButton(onPressed: () => Navigator.pop(alertCtx, true), child: const Text('Oui')),
//                                                                             ],
//                                                                           ),
//                                                                         );
//                                                                         if (confirm != true) return;
//                                                                       }

//                                                                       final newPayment = {
//                                                                         'id': DateTime.now().millisecondsSinceEpoch.toString(),
//                                                                         'studentId': s.id,
//                                                                         'inscriptionId': inscription.id,
//                                                                         'amount': amount,
//                                                                         'method': selectedMethod,
//                                                                         'note': noteCtrl.text,
//                                                                         'createdAt': DateTime.now().millisecondsSinceEpoch,
//                                                                       };
//                                                                       await DatabaseService().insertPayment(newPayment);
//                                                                       Navigator.pop(ctx2);

//                                                                       final allPayments = await DatabaseService().getPaymentsByStudent(s.id, inscriptionId: inscription.id);
//                                                                       final newBalance = balance - amount;

//                                                                       // After saving a payment, ask user where to save the receipt
//                                                                       final choice = await showDialog<String?>(
//                                                                         context: context,
//                                                                         builder: (ctx) => SimpleDialog(
//                                                                           title: const Text('Sauvegarder le reçu'),
//                                                                           children: [
//                                                                             SimpleDialogOption(
//                                                                               onPressed: () => Navigator.pop(ctx, 'app'),
//                                                                               child: const Text("Sauvegarder dans l'app"),
//                                                                             ),
//                                                                             SimpleDialogOption(
//                                                                               onPressed: () => Navigator.pop(ctx, 'choose'),
//                                                                               child: const Text('Choisir un répertoire'),
//                                                                             ),
//                                                                             SimpleDialogOption(
//                                                                               onPressed: () => Navigator.pop(ctx, null),
//                                                                               child: const Text('Ne rien faire'),
//                                                                             ),
//                                                                           ],
//                                                                         ),
//                                                                       );

//                                                                       if (choice == 'app') {
//                                                                         try {
//                                                                           final savedPath = await generateAndSaveReceipt(s, formation, newPayment, allPayments, newBalance, inscriptionId: inscription.id);
//                                                                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reçu sauvegardé dans l\'app: $savedPath')));
//                                                                           reloadDocs();
//                                                                         } catch (e) {
//                                                                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec sauvegarde: $e')));
//                                                                           await generateAndPrintReceipt(s, formation, newPayment, allPayments, newBalance);
//                                                                         }
//                                                                       } else if (choice == 'choose') {
//                                                                         try {
//                                                                           final dirPath = await FilePicker.platform.getDirectoryPath();
//                                                                           if (dirPath != null) {
//                                                                             final bytes = await generateReceiptPdfBytes(s, formation, newPayment, allPayments, newBalance, inscriptionId: inscription.id);
//                                                                             final fileName = 'receipt_${inscription.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
//                                                                             final filePath = '$dirPath${Platform.pathSeparator}$fileName';
//                                                                             final file = File(filePath);
//                                                                             await file.writeAsBytes(bytes, flush: true);

//                                                                             final doc = Document(
//                                                                               id: DateTime.now().millisecondsSinceEpoch.toString(),
//                                                                               formationId: formation?.id ?? '',
//                                                                               studentId: s.id,
//                                                                               title: 'Reçu paiement ${formation?.title ?? ''}',
//                                                                               category: 'reçu',
//                                                                               fileName: fileName,
//                                                                               path: filePath,
//                                                                               mimeType: 'application/pdf',
//                                                                               size: bytes.length,
//                                                                             );
//                                                                             await DatabaseService().insertDocument(doc);
//                                                                             reloadDocs();

//                                                                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reçu sauvegardé: $filePath')));
//                                                                           }
//                                                                         } catch (e) {
//                                                                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur sauvegarde: $e')));
//                                                                         }
//                                                                       }
                                                                      
//                                                                       setStateDialog(() {});
//                                                                     },
//                                                                     child: const Text('Enregistrer'),
//                                                                   ),
//                                                                 ],
//                                                               );
//                                                             },
//                                                           );
//                                                         },
//                                                       );
//                                                     },
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ],
//                                         );
//                                       },
//                                     ),
//                                   );
//                                 },
//                               );
//                             },
//                           ),

//                           // Communication
//                           SingleChildScrollView(
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   'Historique & Communication',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 8),
//                                 ElevatedButton.icon(
//                                   onPressed: () async {
//                                     if (s.email.isEmpty) {
//                                       ScaffoldMessenger.of(
//                                         context,
//                                       ).showSnackBar(
//                                         const SnackBar(
//                                           content: Text(
//                                             'Aucun email disponible',
//                                           ),
//                                         ),
//                                       );
//                                       return;
//                                     }
//                                     final subjectCtrl = TextEditingController();
//                                     final bodyCtrl = TextEditingController();
//                                     await showDialog(
//                                       context: context,
//                                       builder: (ctx) => AlertDialog(
//                                         title: const Text('Nouveau message'),
//                                         content: Column(
//                                           mainAxisSize: MainAxisSize.min,
//                                           children: [
//                                             TextField(
//                                               controller: subjectCtrl,
//                                               decoration: const InputDecoration(
//                                                 labelText: 'Objet',
//                                               ),
//                                             ),
//                                             TextField(
//                                               controller: bodyCtrl,
//                                               decoration: const InputDecoration(
//                                                 labelText: 'Message',
//                                               ),
//                                               maxLines: 4,
//                                             ),
//                                           ],
//                                         ),
//                                         actions: [
//                                           TextButton(
//                                             onPressed: () => Navigator.pop(ctx),
//                                             child: const Text('Annuler'),
//                                           ),
//                                           ElevatedButton(
//                                             onPressed: () {
//                                               final subj = subjectCtrl.text;
//                                               final body = bodyCtrl.text;
//                                               Navigator.pop(ctx);
//                                               _sendEmail(
//                                                 s.email,
//                                                 subject: subj,
//                                                 body: body,
//                                               );
//                                             },
//                                             child: const Text('Envoyer'),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   },
//                                   icon: const Icon(Icons.message),
//                                   label: const Text('Nouveau message'),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                   ],
//                 ),
//               ),
//             ),
//              )   );
//         },
//       ),
//     );
//   }

//   Future<void> _showEditStudentWizard(Student s) async {
//     final studentUpdated = await showDialog<bool>(
//       context: context,
//       builder: (c) => _EditStudentDialog(
//         student: s,
//         formations: _formations,
//         formationMap: _formationMap,
//       ),
//     );

//     if (studentUpdated == true) {
//       _loadStudents();
//     }
//   }

//   Future<void> _showNewStudentWizard() async {
//     final studentAdded = await showDialog<bool>(
//       context: context,
//       builder: (c) => _NewStudentDialog(
//         formations: _formations,
//         formationMap: _formationMap,
//       ),
//     );

//     if (studentAdded == true) {
//       _loadStudents();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF071021),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Filters row
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     onChanged: (v) => setState(() => _search = v),
//                     decoration: const InputDecoration(
//                       prefixIcon: Icon(Icons.search),
//                       hintText: 'Rechercher...',
//                       filled: true,
//                     ),
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 DropdownButton<String>(
//                   value: _filterFormation,
//                   items: [
//                     const DropdownMenuItem(
//                       value: 'Toutes',
//                       child: Text('Toutes'),
//                     ),
//                     ..._formations
//                         .map(
//                           (fm) => DropdownMenuItem(
//                             value: fm.id,
//                             child: Text(fm.title),
//                           ),
//                         )
//                         .toList(),
//                   ],
//                   onChanged: (v) =>
//                       setState(() => _filterFormation = v ?? 'Toutes'),
//                 ),
//                 const SizedBox(width: 12),
//                 DropdownButton<String>(
//                   value: _filterPayment,
//                   items: ['Tous', 'À jour', 'Impayé', 'Partiel']
//                       .map((f) => DropdownMenuItem(value: f, child: Text(f)))
//                       .toList(),
//                   onChanged: (v) =>
//                       setState(() => _filterPayment = v ?? 'Tous'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),

//             // Table / content
//             Expanded(
//               child: Card(
//                 color: const Color(0xFF0B1220),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: _students.isEmpty
//                       ? Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: const [
//                               Icon(
//                                 Icons.people_outline,
//                                 size: 48,
//                                 color: Colors.white54,
//                               ),
//                               SizedBox(height: 12),
//                               Text(
//                                 'Aucun étudiant',
//                                 style: TextStyle(color: Colors.white70),
//                               ),
//                             ],
//                           ),
//                         )
//                       : SingleChildScrollView(
//                           child: DataTable(
//                             headingRowColor: MaterialStateProperty.all(
//                               const Color(0xFF06121A),
//                             ),
//                             columns: const [
//                               DataColumn(
//                                 label: Text(
//                                   'N°',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                               DataColumn(
//                                 label: Text(
//                                   'Nom',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                               DataColumn(
//                                 label: Text(
//                                   'Formation',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                               DataColumn(
//                                 label: Text(
//                                   'Téléphone',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                               DataColumn(
//                                 label: Text(
//                                   'Email',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                               DataColumn(
//                                 label: Text(
//                                   'Statut',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                               DataColumn(
//                                 label: Text(
//                                   'Actions',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                             ],
//                             rows: _visible.map((s) {
//                               return DataRow(
//                                 selected: _selected.contains(s.id),
//                                 onSelectChanged: (sel) => setState(
//                                   () => sel == true
//                                       ? _selected.add(s.id)
//                                       : _selected.remove(s.id),
//                                 ),
//                                 cells: [
//                                   DataCell(
//                                     Text(
//                                       s.studentNumber,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                   ),
//                                   DataCell(
//                                     Text(
//                                       s.name,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                   ),
//                                   DataCell(
//                                     Text(
//                                       _formationMap[s.formation]?.title ??
//                                           s.formation,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                   ),
//                                   DataCell(
//                                     Text(
//                                       s.phone,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                   ),
//                                   DataCell(
//                                     Text(
//                                       s.email,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                   ),
//                                   DataCell(
//                                     Text(
//                                       s.paymentStatus,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                       ),
//                                     ),
//                                   ),
//                                   DataCell(
//                                     Row(
//                                       children: [
//                                         IconButton(
//                                           icon: const Icon(Icons.visibility),
//                                           onPressed: () =>
//                                               _showStudentDetails(s),
//                                         ),
//                                         IconButton(
//                                           icon: const Icon(Icons.edit),
//                                           onPressed: () =>
//                                               _showEditStudentWizard(s),
//                                         ),
//                                         IconButton(
//                                           icon: const Icon(Icons.delete),
//                                           onPressed: () async {
//                                             await DatabaseService()
//                                                 .deleteStudent(s.id);
//                                             await _loadStudents();
//                                           },
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: primaryAccent,
//         onPressed: _showNewStudentWizard,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

// class _EditStudentDialog extends StatefulWidget {
//   final Student student;
//   final List<Formation> formations;
//   final Map<String, Formation> formationMap;

//   const _EditStudentDialog({
//     required this.student,
//     required this.formations,
//     required this.formationMap,
//   });

//   @override
//   _EditStudentDialogState createState() => _EditStudentDialogState();
// }

// class _EditStudentDialogState extends State<_EditStudentDialog> {
//   static const Color primaryAccentDark = Color(0xFF0891B2);
//   int currentStep = 0;
//   late final TextEditingController nameCtrl;
//   late final TextEditingController emailCtrl;
//   late final TextEditingController phoneCtrl;
//   late final TextEditingController addressCtrl;
//   late final TextEditingController studentNumberCtrl;
//   late final TextEditingController amountCtrl;
//   late String formation;
//   late String payment;
//   late String photoPath;
//   final formKey = GlobalKey<FormState>();
//   bool isValid = false;

//   @override
//   void initState() {
//     super.initState();
//     nameCtrl = TextEditingController(text: widget.student.name);
//     emailCtrl = TextEditingController(text: widget.student.email);
//     phoneCtrl = TextEditingController(text: widget.student.phone);
//     addressCtrl = TextEditingController(text: widget.student.address);
//     studentNumberCtrl = TextEditingController(
//       text: widget.student.studentNumber,
//     );
//     amountCtrl = TextEditingController();

//     formation = widget.student.formation;
//     payment = widget.student.paymentStatus;
//     photoPath = widget.student.photo;

//     nameCtrl.addListener(_validate);
//     emailCtrl.addListener(_validate);
//     _validate();
//   }

//   @override
//   void dispose() {
//     nameCtrl.removeListener(_validate);
//     emailCtrl.removeListener(_validate);
//     nameCtrl.dispose();
//     emailCtrl.dispose();
//     phoneCtrl.dispose();
//     addressCtrl.dispose();
//     studentNumberCtrl.dispose();
//     amountCtrl.dispose();
//     super.dispose();
//   }

//   void _validate() {
//     final newIsValid =
//         _isValidEmail(emailCtrl.text) && nameCtrl.text.trim().isNotEmpty;
//     if (newIsValid != isValid) {
//       setState(() {
//         isValid = newIsValid;
//       });
//     }
//   }

//   bool _isValidEmail(String? v) {
//     if (v == null || v.trim().isEmpty) return false;
//     final re = RegExp(r"""^[^\s@]+@[^\s@]+\.[^\s@]+$""");
//     return re.hasMatch(v.trim());
//   }

//   bool _isValidPhone(String? v) {
//     if (v == null || v.isEmpty) return true;
//     return RegExp(r'^[0-9 +()\-]{6,}$').hasMatch(v);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: const Color(0xFF0B1220),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: SizedBox(
//         width: 1000,
//         height: 560,
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: formKey,
//             child: Column(
//               children: [
//                 const Text(
//                   'Modifier étudiant',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Expanded(
//                   child: Stepper(
//                     currentStep: currentStep,
//                     onStepTapped: (i) => setState(() => currentStep = i),
//                     controlsBuilder: (ctx, details) => const SizedBox.shrink(),
//                     steps: <Step>[
//                       Step(
//                         title: const Text('Infos personnelles'),
//                         isActive: currentStep >= 0,
//                         content: Column(
//                           children: [
//                             TextFormField(
//                               controller: nameCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Nom complet',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               validator: (v) => (v == null || v.trim().isEmpty)
//                                   ? 'Requis'
//                                   : null,
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: emailCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Email',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               validator: (v) =>
//                                   _isValidEmail(v) ? null : 'Email invalide',
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: phoneCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Téléphone',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               validator: (v) => _isValidPhone(v)
//                                   ? null
//                                   : 'Téléphone invalide',
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: addressCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Adresse',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: studentNumberCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Numéro étudiant',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                             const SizedBox(height: 8),
//                             if (photoPath.isNotEmpty)
//                               CircleAvatar(
//                                 radius: 36,
//                                 backgroundImage: FileImage(File(photoPath)),
//                               )
//                             else
//                               const SizedBox(),
//                             TextButton.icon(
//                               onPressed: () async {
//                                 final res = await FilePicker.platform.pickFiles(
//                                   type: FileType.image,
//                                 );
//                                 if (res == null || res.files.isEmpty) return;
//                                 final f = res.files.first;
//                                 final tmpPath = f.path!;
//                                 final documentsDir =
//                                     await getApplicationDocumentsDirectory();
//                                 final attachmentsDir = Directory(
//                                   p.join(
//                                     documentsDir.path,
//                                     'attachments',
//                                     widget.student.id,
//                                   ),
//                                 );
//                                 if (!attachmentsDir.existsSync())
//                                   attachmentsDir.createSync(recursive: true);
//                                 final destPath = p.join(
//                                   attachmentsDir.path,
//                                   p.basename(tmpPath),
//                                 );
//                                 await File(tmpPath).copy(destPath);
//                                 setState(() => photoPath = destPath);
//                               },
//                               icon: const Icon(Icons.photo_camera),
//                               label: const Text('Choisir photo'),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Step(
//                         title: const Text('Formation'),
//                         isActive: currentStep >= 1,
//                         content: Column(
//                           children: [
//                             DropdownButtonFormField<String>(
//                               value:
//                                   (formation.isNotEmpty &&
//                                       widget.formationMap.containsKey(
//                                         formation,
//                                       ))
//                                   ? formation
//                                   : null,
//                               items: widget.formationMap.values
//                                   .map(
//                                     (fm) => DropdownMenuItem(
//                                       value: fm.id,
//                                       child: Text(
//                                         '${fm.title} — ${fm.price.toStringAsFixed(0)}',
//                                       ),
//                                     ),
//                                   )
//                                   .toList(),
//                               onChanged: (v) => setState(() {
//                                 formation = v ?? '';
//                                 final found = widget.formationMap[formation];
//                                 if (found != null)
//                                   amountCtrl.text = found.price.toStringAsFixed(
//                                     0,
//                                   );
//                               }),
//                               decoration: const InputDecoration(
//                                 labelText: 'Formation actuelle',
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             const Text(
//                               'Sélectionner les formations suivies (extrait)',
//                               style: TextStyle(color: Colors.white70),
//                             ),
//                             const SizedBox(height: 6),
//                             Card(
//                               color: const Color(0xFF0F1724),
//                               child: ListTile(
//                                 title: const Text(
//                                   'Formation A',
//                                   style: TextStyle(color: Colors.white70),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Step(
//                         title: const Text('Modalités paiement'),
//                         isActive: currentStep >= 2,
//                         content: Column(
//                           children: [
//                             DropdownButtonFormField<String>(
//                               value: payment,
//                               items: ['À jour', 'Impayé', 'Partiel']
//                                   .map(
//                                     (e) => DropdownMenuItem(
//                                       value: e,
//                                       child: Text(e),
//                                     ),
//                                   )
//                                   .toList(),
//                               onChanged: (v) =>
//                                   setState(() => payment = v ?? payment),
//                               decoration: const InputDecoration(
//                                 labelText: 'Statut paiement',
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: amountCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Montant total',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               keyboardType: TextInputType.number,
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               decoration: const InputDecoration(
//                                 labelText: 'Remise (%)',
//                               ),
//                               keyboardType: TextInputType.number,
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(context, false),
//                       child: const Text('Annuler'),
//                     ),
//                     const SizedBox(width: 8),
//                     ElevatedButton(
//                       onPressed: isValid
//                           ? () async {
//                               if (!(formKey.currentState?.validate() ??
//                                   false)) {
//                                 setState(() => currentStep = 0);
//                                 return;
//                               }
//                               final updated = Student(
//                                 id: widget.student.id,
//                                 studentNumber: studentNumberCtrl.text.isNotEmpty
//                                     ? studentNumberCtrl.text
//                                     : widget.student.studentNumber,
//                                 name: nameCtrl.text,
//                                 email: emailCtrl.text,
//                                 phone: phoneCtrl.text,
//                                 address: addressCtrl.text,
//                                 formation: formation,
//                                 paymentStatus: payment,
//                                 photo: photoPath,
//                               );
//                               await DatabaseService().updateStudent(
//                                 updated.toMap(),
//                               );

//                               if (formation.isNotEmpty && formation != widget.student.formation) {
//                                 final inscription = Inscription(
//                                   id: DateTime.now().millisecondsSinceEpoch.toString(),
//                                   studentId: widget.student.id,
//                                   formationId: formation,
//                                   inscriptionDate: DateTime.now(),
//                                   status: 'En cours',
//                                 );
//                                 await DatabaseService().addInscription(inscription.toMap());
//                               }

//                               Navigator.pop(context, true);
//                             }
//                           : null,
//                       child: const Text('Enregistrer'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: primaryAccentDark,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _NewStudentDialog extends StatefulWidget {
//   final List<Formation> formations;
//   final Map<String, Formation> formationMap;

//   const _NewStudentDialog({
//     required this.formations,
//     required this.formationMap,
//   });

//   @override
//   _NewStudentDialogState createState() => _NewStudentDialogState();
// }

// class _NewStudentDialogState extends State<_NewStudentDialog> {
//   static const Color primaryAccentDark = Color(0xFF0891B2);
//   int currentStep = 0;
//   late final TextEditingController nameCtrl;
//   late final TextEditingController emailCtrl;
//   late final TextEditingController phoneCtrl;
//   late final TextEditingController addressCtrl;
//   late final TextEditingController amountCtrl;
//   String formation = '';
//   String payment = 'À jour';
//   String photoPath = '';
//   final formKey = GlobalKey<FormState>();
//   bool isValid = false;

//   @override
//   void initState() {
//     super.initState();
//     nameCtrl = TextEditingController();
//     emailCtrl = TextEditingController();
//     phoneCtrl = TextEditingController();
//     addressCtrl = TextEditingController();
//     amountCtrl = TextEditingController();

//     nameCtrl.addListener(_validate);
//     emailCtrl.addListener(_validate);
//     _validate();
//   }

//   @override
//   void dispose() {
//     nameCtrl.removeListener(_validate);
//     emailCtrl.removeListener(_validate);
//     nameCtrl.dispose();
//     emailCtrl.dispose();
//     phoneCtrl.dispose();
//     addressCtrl.dispose();
//     amountCtrl.dispose();
//     super.dispose();
//   }

//   void _validate() {
//     final newIsValid =
//         _isValidEmail(emailCtrl.text) && nameCtrl.text.trim().isNotEmpty;
//     if (newIsValid != isValid) {
//       setState(() {
//         isValid = newIsValid;
//       });
//     }
//   }

//   bool _isValidEmail(String? v) {
//     if (v == null || v.trim().isEmpty) return false;
//     final re = RegExp(r"""^[^\s@]+@[^\s@]+\.[^\s@]+$""");
//     return re.hasMatch(v.trim());
//   }

//   bool _isValidPhone(String? v) {
//     if (v == null || v.isEmpty) return true;
//     return RegExp(r'^[0-9 +()\-]{6,}$').hasMatch(v);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: const Color(0xFF0B1220),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: SizedBox(
//         width: 1000,
//         height: 560,
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: formKey,
//             child: Column(
//               children: [
//                 const Text(
//                   'Nouvel étudiant',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Expanded(
//                   child: Stepper(
//                     currentStep: currentStep,
//                     onStepTapped: (i) => setState(() => currentStep = i),
//                     controlsBuilder: (ctx, details) => const SizedBox.shrink(),
//                     steps: <Step>[
//                       Step(
//                         title: const Text('Infos personnelles'),
//                         isActive: currentStep >= 0,
//                         content: Column(
//                           children: [
//                             TextFormField(
//                               controller: nameCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Nom complet',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               validator: (v) => (v == null || v.trim().isEmpty)
//                                   ? 'Requis'
//                                   : null,
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: emailCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Email',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               validator: (v) =>
//                                   _isValidEmail(v) ? null : 'Email invalide',
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: phoneCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Téléphone',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               validator: (v) => _isValidPhone(v)
//                                   ? null
//                                   : 'Téléphone invalide',
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: addressCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Adresse',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                             const SizedBox(height: 8),
//                             if (photoPath.isNotEmpty)
//                               CircleAvatar(
//                                 radius: 36,
//                                 backgroundImage: FileImage(File(photoPath)),
//                               )
//                             else
//                               const SizedBox(),
//                             TextButton.icon(
//                               onPressed: () async {
//                                 final res = await FilePicker.platform.pickFiles(
//                                   type: FileType.image,
//                                 );
//                                 if (res == null || res.files.isEmpty) return;
//                                 final f = res.files.first;
//                                 setState(() {
//                                   photoPath = f.path!;
//                                 });
//                               },
//                               icon: const Icon(Icons.photo_camera),
//                               label: const Text('Choisir photo'),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Step(
//                         title: const Text('Formation'),
//                         isActive: currentStep >= 1,
//                         content: Column(
//                           children: [
//                             DropdownButtonFormField<String>(
//                               value:
//                                   (formation.isNotEmpty &&
//                                       widget.formationMap.containsKey(
//                                         formation,
//                                       ))
//                                   ? formation
//                                   : null,
//                               items: widget.formationMap.values
//                                   .map(
//                                     (fm) => DropdownMenuItem(
//                                       value: fm.id,
//                                       child: Text(
//                                         '${fm.title} — ${fm.price.toStringAsFixed(0)}',
//                                       ),
//                                     ),
//                                   )
//                                   .toList(),
//                               onChanged: (v) => setState(() {
//                                 formation = v ?? '';
//                                 final found = widget.formationMap[formation];
//                                 if (found != null)
//                                   amountCtrl.text = found.price.toStringAsFixed(
//                                     0,
//                                   );
//                               }),
//                               decoration: const InputDecoration(
//                                 labelText: 'Formation souhaitée',
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             const Text(
//                               'Options avancées de formation (planning, niveau...)',
//                               style: TextStyle(color: Colors.white70),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Step(
//                         title: const Text('Modalités paiement'),
//                         isActive: currentStep >= 2,
//                         content: Column(
//                           children: [
//                             DropdownButtonFormField<String>(
//                               value: payment,
//                               items: ['À jour', 'Impayé', 'Partiel']
//                                   .map(
//                                     (e) => DropdownMenuItem(
//                                       value: e,
//                                       child: Text(e),
//                                     ),
//                                   )
//                                   .toList(),
//                               onChanged: (v) =>
//                                   setState(() => payment = v ?? payment),
//                               decoration: const InputDecoration(
//                                 labelText: 'Statut paiement',
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: amountCtrl,
//                               decoration: const InputDecoration(
//                                 labelText: 'Montant total',
//                               ),
//                               style: const TextStyle(color: Colors.white),
//                               keyboardType: TextInputType.number,
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               decoration: const InputDecoration(
//                                 labelText: 'Remise (%)',
//                               ),
//                               keyboardType: TextInputType.number,
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(context, false),
//                       child: const Text('Annuler'),
//                     ),
//                     const SizedBox(width: 8),
//                     ElevatedButton(
//                       onPressed: isValid
//                           ? () async {
//                               if (!(formKey.currentState?.validate() ??
//                                   false)) {
//                                 setState(() => currentStep = 0);
//                                 return;
//                               }
//                               final studentId = DateTime.now()
//                                   .millisecondsSinceEpoch
//                                   .toString();
//                               final studentNumber =
//                                   'ST${DateTime.now().millisecondsSinceEpoch}';
//                               String savedPhoto = '';
//                               if (photoPath.isNotEmpty) {
//                                 final documentsDir =
//                                     await getApplicationDocumentsDirectory();
//                                 final attachmentsDir = Directory(
//                                   p.join(
//                                     documentsDir.path,
//                                     'attachments',
//                                     studentId,
//                                   ),
//                                 );
//                                 if (!attachmentsDir.existsSync())
//                                   attachmentsDir.createSync(recursive: true);
//                                 final destPath = p.join(
//                                   attachmentsDir.path,
//                                   p.basename(photoPath),
//                                 );
//                                 await File(photoPath).copy(destPath);
//                                 savedPhoto = destPath;
//                               }
//                               final s = Student(
//                                 id: studentId,
//                                 studentNumber: studentNumber,
//                                 name: nameCtrl.text,
//                                 photo: savedPhoto,
//                                 address: addressCtrl.text,
//                                 email: emailCtrl.text,
//                                 phone: phoneCtrl.text,
//                                 formation: formation,
//                                 paymentStatus: payment,
//                               );
//                               await DatabaseService().insertStudent(s.toMap());

//                               if (formation.isNotEmpty) {
//                                 final inscription = Inscription(
//                                   id: DateTime.now().millisecondsSinceEpoch.toString(),
//                                   studentId: studentId,
//                                   formationId: formation,
//                                   inscriptionDate: DateTime.now(),
//                                   status: 'En cours',
//                                 );
//                                 await DatabaseService().addInscription(inscription.toMap());
//                               }

//                               Navigator.pop(context, true);
//                             }
//                           : null,
//                       child: const Text('Enregistrer'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: primaryAccentDark,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
