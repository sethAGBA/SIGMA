import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../services/database_service.dart';
import 'models.dart';
import '../../services/template_renderer.dart';

class TemplatesPreviewScreen extends StatefulWidget {
  const TemplatesPreviewScreen({Key? key}) : super(key: key);

  @override
  _TemplatesPreviewScreenState createState() => _TemplatesPreviewScreenState();
}

class _TemplatesPreviewScreenState extends State<TemplatesPreviewScreen> {
  late Future<List<DocumentTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _templatesFuture = DatabaseService().getDocumentTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu des modèles')),
      body: FutureBuilder<List<DocumentTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
          final templates = snapshot.data ?? [];
          if (templates.isEmpty) return const Center(child: Text('Aucun modèle à prévisualiser'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, i) {
              final t = templates[i];
              QuillController controller;
              try {
                // Render placeholders with empty data so previews don't show raw {{...}}
                dynamic rendered = t.content;
                try {
                  rendered = renderTemplateJsonContent(t.content, <String, dynamic>{});
                } catch (_) {}
                final parsed = rendered is String ? jsonDecode(rendered) : rendered;
                controller = QuillController(document: Document.fromJson(parsed), selection: const TextSelection.collapsed(offset: 0));
              } catch (_) {
                controller = QuillController.basic();
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 240,
                        child: Container(
                          color: Colors.white,
                          child: AbsorbPointer(
                            absorbing: true,
                            child: QuillEditor(
                              controller: controller,
                              focusNode: FocusNode(),
                              scrollController: ScrollController(),
                              config: QuillEditorConfig(
                                padding: const EdgeInsets.all(12),
                                autoFocus: false,
                                expands: false,
                                embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Modal dialog variant for previewing templates. Use this with showDialog()
class TemplatesPreviewDialog extends StatelessWidget {
  const TemplatesPreviewDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Future<List<DocumentTemplate>> _templatesFuture = DatabaseService().getDocumentTemplates();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              child: Row(
                children: [
                  const Expanded(child: Text('Aperçu des modèles', style: TextStyle(color: Colors.white, fontSize: 18))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DocumentTemplate>>(
                future: _templatesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                  final templates = snapshot.data ?? [];
                  if (templates.isEmpty) return const Center(child: Text('Aucun modèle à prévisualiser'));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: templates.length,
                    itemBuilder: (context, i) {
                      final t = templates[i];
                      QuillController controller;
                      try {
                        dynamic rendered = t.content;
                        try {
                          rendered = renderTemplateJsonContent(t.content, <String, dynamic>{});
                        } catch (_) {}
                        final parsed2 = rendered is String ? jsonDecode(rendered) : rendered;
                        controller = QuillController(document: Document.fromJson(parsed2), selection: const TextSelection.collapsed(offset: 0));
                      } catch (_) {
                        controller = QuillController.basic();
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 240,
                                child: Container(
                                  color: Colors.white,
                                  child: AbsorbPointer(
                                    absorbing: true,
                                    child: QuillEditor(
                                      controller: controller,
                                      focusNode: FocusNode(),
                                      scrollController: ScrollController(),
                                      config: QuillEditorConfig(
                                        padding: const EdgeInsets.all(12),
                                        autoFocus: false,
                                        expands: false,
                                        embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
