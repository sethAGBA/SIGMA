import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'models.dart';
import '../../services/database_service.dart';
import 'template_dialog.dart';
import 'editor_dialog.dart';
import 'templates_preview.dart';
import 'template_editor_web.dart';
import 'template_canvas.dart';
import '../../utils/template_canvas_pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'template_export_picker.dart';
import '../../services/template_renderer.dart';
import 'package:pdf/widgets.dart' as pw;

class TemplatesTab extends StatefulWidget {
  @override
  _TemplatesTabState createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  late Future<List<DocumentTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    setState(() {
      _templatesFuture = DatabaseService().getDocumentTemplates();
    });
  }

  Future<void> _showTemplateDialog({DocumentTemplate? template}) async {
    final result = await showDialog<DocumentTemplate?>(
      context: context,
      builder: (context) => TemplateDialog(template: template),
    );
    // If the saved template is a canvas, open the designer immediately
    if (result != null) {
      if (result.type == 'canvas') {
        // Open the canvas designer
        await showDialog(context: context, builder: (_) => TemplateCanvasDialog(template: result));
      }
    }
    _loadTemplates(); // Refresh the list after dialog is closed
  }

  Future<void> _showEditorDialog(DocumentTemplate template) async {
    if (template.type == 'canvas') {
      await showDialog(context: context, builder: (_) => TemplateCanvasDialog(template: template));
    } else {
      await showDialog(
        context: context,
        builder: (context) => EditorDialog(template: template),
      );
    }
    _loadTemplates();
  }

  Future<void> _deleteTemplate(DocumentTemplate template) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirmer la suppression', style: TextStyle(color: Colors.white)),
        content: Text('Êtes-vous sûr de vouloir supprimer le modèle "${template.name}" ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().deleteDocumentTemplate(template.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modèle supprimé avec succès'), backgroundColor: Colors.green),
      );
      _loadTemplates();
    }
  }

  Future<void> _duplicateTemplate(DocumentTemplate template) async {
    final newTemplate = DocumentTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: '${template.name} (copie)',
      type: template.type,
      content: template.content,
      lastModified: DateTime.now(),
    );
    await DatabaseService().saveDocumentTemplate(newTemplate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Modèle "${template.name}" dupliqué avec succès'), backgroundColor: Colors.blue),
    );
    _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Templates de Documents', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Gérez les modèles de factures, reçus et attestations', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showTemplateDialog(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nouveau Template', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(context: context, builder: (_) => const TemplatesPreviewDialog());
                },
                icon: const Icon(Icons.preview, color: Colors.white),
                label: const Text('Aperçu', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      title: const Text('Restaurer les modèles par défaut', style: TextStyle(color: Colors.white)),
                      content: const Text('Cela remplacera tous les modèles existants. Continuer?', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
                        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restaurer')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await DatabaseService().resetDefaultTemplates();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modèles par défaut restaurés'), backgroundColor: Colors.green));
                    _loadTemplates();
                  }
                },
                icon: const Icon(Icons.restore_page, color: Colors.white),
                label: const Text('Restaurer modèles', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<List<DocumentTemplate>>(
            future: _templatesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Aucun modèle de document trouvé.', style: TextStyle(color: Colors.white70)));
              }

              final templates = snapshot.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) => buildTemplateCard(templates[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildTemplateCard(DocumentTemplate template) {
    return GestureDetector(
      onTap: () => _showEditorDialog(template),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  template.type == 'canvas'
                      ? CanvasThumbnail(template: template, width: 56, height: 56)
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getTemplateIcon(template.type), color: Colors.white, size: 24),
                        ),
                  const Spacer(),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
                    color: const Color(0xFF334155),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, color: Colors.white, size: 18), SizedBox(width: 8), Text('Modifier', style: TextStyle(color: Colors.white))]),
                      ),
                      const PopupMenuItem(
                        value: 'edit_web',
                        child: Row(children: [Icon(Icons.web, color: Colors.white, size: 18), SizedBox(width: 8), Text('Modifier (Web)', style: TextStyle(color: Colors.white))]),
                      ),
                      const PopupMenuItem(
                        value: 'designer',
                        child: Row(children: [Icon(Icons.design_services, color: Colors.white, size: 18), SizedBox(width: 8), Text('Designer', style: TextStyle(color: Colors.white))]),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(children: [Icon(Icons.copy, color: Colors.white, size: 18), SizedBox(width: 8), Text('Dupliquer', style: TextStyle(color: Colors.white))]),
                      ),
                      const PopupMenuItem(
                        value: 'export_pdf',
                        child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.white, size: 18), SizedBox(width: 8), Text('Exporter en PDF', style: TextStyle(color: Colors.white))]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))]),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _showTemplateDialog(template: template);
                      } else if (value == 'edit_web') {
                        // Open web editor as a modal dialog. If you prefer a full route,
                        // uncomment the Navigator.push option below.
                        showDialog(context: context, builder: (_) => TemplateEditorWebDialog(template: template));
                        // Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateEditorWeb(template: template)));
                      } else if (value == 'designer') {
                        showDialog(context: context, builder: (_) => TemplateCanvasDialog(template: template));
                      } else if (value == 'delete') {
                        _deleteTemplate(template);
                      } else if (value == 'export_pdf') {
                        // Export the template as-is (no student selection): use company info and empty defaults for student/placeholders
                        final company = await DatabaseService().getCompanyInfo();
                        final data = <String, dynamic>{
                          // company aliases
                          'company_name': company?.name ?? '',
                          'companyName': company?.name ?? '',
                          'company_address': company?.address ?? '',
                          'companyAddress': company?.address ?? '',
                          'company_phone': company?.phone ?? '',
                          'companyPhone': company?.phone ?? '',
                          'company_logo': company?.logoPath ?? '',
                          'companyLogo': company?.logoPath ?? '',
                          // empty student/inscription placeholders (export "tel quel")
                          'student_name': '',
                          'student_id': '',
                          'studentNumber': '',
                          'formation_name': '',
                          'start_date': '',
                          'duration': '',
                          'finalGrade': '',
                          'final_grade': '',
                          'appreciation': '',
                          'amount': '',
                          'invoice_number': '',
                          'invoice_date': '',
                        };
                        try {
                          if (template.type == 'canvas') {
                            generatePdfFromCanvasTemplate(template, data).then((bytes) async {
                              try {
                                String suggested = '${template.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                String? savePath;
                                try {
                                  savePath = await FilePicker.platform.saveFile(dialogTitle: 'Enregistrer le PDF', fileName: suggested);
                                } catch (_) {
                                  savePath = null;
                                }
                                if (savePath != null && savePath.isNotEmpty) {
                                  final out = File(savePath);
                                  await out.writeAsBytes(bytes);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF sauvegardé: ${out.path}')));
                                } else {
                                  final docs = await getApplicationDocumentsDirectory();
                                  final out = File('${docs.path}/$suggested');
                                  await out.writeAsBytes(bytes);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF sauvegardé: ${out.path} (fallback)')));
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la sauvegarde du PDF: $e')));
                              }
                            });
                          } else {
                            dynamic rendered = template.content;
                            try {
                              rendered = renderTemplateJsonContent(template.content, data);
                            } catch (_) {}
                            final parsed = jsonDecode(rendered is String ? rendered : jsonEncode(rendered));
                            final ops = parsed is List ? parsed : <dynamic>[];
                            final buffer = StringBuffer();
                            for (final op in ops) {
                              if (op is Map && op['insert'] is String) buffer.writeln(op['insert']);
                            }
                            final pdf = pw.Document();
                            pdf.addPage(pw.MultiPage(build: (c) => [pw.Text(buffer.toString())]));
                            final bytes = await pdf.save();
                            final docs = await getApplicationDocumentsDirectory();
                            final out = File('${docs.path}/${template.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
                            await out.writeAsBytes(bytes);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF généré: ${out.path}')));
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'export PDF: $e')));
                        }
                      } else if (value == 'duplicate') {
                        _duplicateTemplate(template);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _getTemplateColor(template.type), borderRadius: BorderRadius.circular(8)),
                child: Text(template.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
              const Spacer(),
              Text('Modifié le ${formatDate(template.lastModified)}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTemplateIcon(String type) {
    switch (type) {
      case 'facture':
        return Icons.receipt_long;
      case 'recu':
        return Icons.receipt;
      case 'attestation':
        return Icons.verified;
      case 'canvas':
        return Icons.design_services;
      default:
        return Icons.description;
    }
  }

  Color _getTemplateColor(String type) {
    switch (type) {
      case 'facture':
        return Colors.blue;
      case 'recu':
        return Colors.green;
      case 'attestation':
        return Colors.purple;
      case 'canvas':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class CanvasThumbnail extends StatelessWidget {
  final DocumentTemplate template;
  final double width;
  final double height;
  const CanvasThumbnail({Key? key, required this.template, this.width = 64, this.height = 64}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      final parsed = jsonDecode(template.content);
      if (parsed is Map && parsed['canvas'] is List) {
        final canvas = List<Map<String, dynamic>>.from(parsed['canvas'].map((e) => Map<String, dynamic>.from(e)));
        final doc = (parsed['doc'] is Map) ? Map<String, dynamic>.from(parsed['doc']) : <String, dynamic>{};
        final docW = (doc['width'] as num?)?.toDouble() ?? 595.0; // A4 width @72dpi
        final docH = (doc['height'] as num?)?.toDouble() ?? 842.0; // A4 height @72dpi
        final ar = docW > 0 ? (docW / docH) : (595.0 / 842.0);

        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: ar,
            child: LayoutBuilder(
              builder: (context, cons) {
                final pw = cons.maxWidth;
                final ph = cons.maxHeight;
                return Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: canvas.take(10).map((m) {
                      final left = (m['left'] as num?)?.toDouble() ?? 0.0;
                      final top = (m['top'] as num?)?.toDouble() ?? 0.0;
                      final elW = (m['width'] as num?)?.toDouble() ?? 80.0;
                      final elH = (m['height'] as num?)?.toDouble() ?? 20.0;
                      final text = (m['text'] as String?) ?? (m['type'] as String? ?? '');
                      final x = (left / docW).clamp(0.0, 1.0);
                      final y = (top / docH).clamp(0.0, 1.0);
                      final wRel = (elW / docW).clamp(0.0, 1.0);
                      final hRel = (elH / docH).clamp(0.0, 1.0);
                      return Positioned(
                        left: x * pw,
                        top: y * ph,
                        child: Container(
                          width: (wRel * pw).clamp(6.0, pw),
                          height: (hRel * ph).clamp(6.0, ph),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            text.length > 20 ? text.substring(0, 20) : text,
                            style: const TextStyle(fontSize: 8, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (_) {}
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 595 / 842,
        child: Container(
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.grid_view, size: width * 0.6),
        ),
      ),
    );
  }
}
