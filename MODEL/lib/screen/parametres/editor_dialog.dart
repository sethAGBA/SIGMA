import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'models.dart';
import '../../services/database_service.dart';
import '../../services/template_renderer.dart';

class EditorDialog extends StatefulWidget {
  final DocumentTemplate template;
  final Map<String, dynamic>? previewData;

  const EditorDialog({Key? key, required this.template, this.previewData}) : super(key: key);

  @override
  _EditorDialogState createState() => _EditorDialogState();
}

class _EditorDialogState extends State<EditorDialog> {
  late QuillController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  // Save original ErrorWidget builder so we can restore it in dispose.
  late ErrorWidgetBuilder _originalErrorWidgetBuilder;

  void _loadDocument() {
    try {
      if (widget.template.content.isEmpty) {
        _controller = QuillController.basic();
        setState(() => _isLoading = false);
        return;
      }

      // If previewData is provided, render placeholders in the template JSON first
      dynamic maybeContent = widget.template.content;
      if (widget.previewData != null) {
        try {
          final rendered = renderTemplateJsonContent(widget.template.content, widget.previewData!);
          maybeContent = jsonEncode(rendered);
        } catch (_) {
          maybeContent = widget.template.content;
        }
      }

      final rawDoc = Document.fromJson(jsonDecode(maybeContent));

      // Normalize any existing image embeds that may contain a file:// prefix
      // (some older saved templates or external imports might store URIs).
      List<dynamic> ops = rawDoc.toDelta().toJson() as List<dynamic>;
      final normalizedOps = <Map<String, dynamic>>[];
      for (final op in ops) {
        if (op is Map<String, dynamic> && op['insert'] is Map && op['insert']['image'] != null) {
          final raw = op['insert']['image'] as String;
          final normalized = raw.startsWith('file://') ? raw.substring(7) : raw;
          // Log a diagnostic if the referenced file does not exist at load time
          try {
            final exists = File(normalized).existsSync();
            if (!exists) {
              DatabaseService().logImageDiagnostic(normalized, false);
            }
          } catch (_) {}
          normalizedOps.add({'insert': {'image': normalized}});
        } else {
          normalizedOps.add(Map<String, dynamic>.from(op));
        }
      }

      // If template contains the special placeholder {{company_logo}}, replace it
      // with an image embed pointing to the company logo stored in settings.
      if (widget.template.content.contains('{{company_logo}}')) {
        DatabaseService().getCompanyInfo().then((company) {
          final logoPath = company?.logoPath ?? '';
          if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
            final newOps = <Map<String, dynamic>>[];
            for (final op in normalizedOps) {
              final insert = op['insert'];
              if (insert is String && insert.contains('{{company_logo}}')) {
                // replace placeholder with image embed (use raw filesystem path)
                newOps.add({'insert': {'image': logoPath}});
                final s = insert;
                final after = s.replaceAll('{{company_logo}}', '');
                if (after.isNotEmpty) newOps.add({'insert': after});
              } else {
                newOps.add(Map<String, dynamic>.from(op));
              }
            }
            final doc = Document.fromJson(newOps);
            _controller = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
          } else {
            final doc = Document.fromJson(normalizedOps);
            _controller = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
          }
          if (mounted) setState(() => _isLoading = false);
        });
      } else {
        final doc = Document.fromJson(normalizedOps);
        _controller = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      final doc = Document()..insert(0, widget.template.content);
      _controller = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDocument() async {
    // Before saving, if the document contains an image that points to the
    // current company logo, convert that image back into the {{company_logo}}
    // placeholder so templates remain portable and always use the settings logo.
    final delta = _controller.document.toDelta();
    final ops = delta.toJson() as List<dynamic>;

    final company = await DatabaseService().getCompanyInfo();
    final logoPath = company?.logoPath ?? '';

    final newOps = <Map<String, dynamic>>[];
    for (final op in ops) {
      if (op is Map<String, dynamic> && op['insert'] is Map && op['insert']['image'] != null) {
        final img = op['insert']['image'] as String;
        // normalize possible file:// prefix
        final normalized = img.startsWith('file://') ? img.substring(7) : img;
        if (logoPath.isNotEmpty && normalized == logoPath) {
          newOps.add({'insert': '{{company_logo}}'});
          continue;
        }
      }
      newOps.add(Map<String, dynamic>.from(op));
    }

    final jsonContent = jsonEncode(newOps);
    final updatedTemplate = DocumentTemplate(
      id: widget.template.id,
      name: widget.template.name,
      type: widget.template.type,
      content: jsonContent,
      lastModified: DateTime.now(),
    );

    await DatabaseService().saveDocumentTemplate(updatedTemplate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modèle sauvegardé'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    }
  }

  // TODO: implement custom image pick/copy handling if needed with the
  // current version of flutter_quill_extensions — the toolbar uses default
  // embed buttons by default and accepts platform pickers.

  // Pick an image using file_picker, copy it to the app documents directory
  // with a unique filename, then insert an image embed into the editor.
  Future<void> _pickImageAndInsert() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return; // user cancelled

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;

      final file = File(pickedPath);
      if (!await file.exists()) return;

      final appDocDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDocDir.path}/template_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      final ext = path.extension(pickedPath);
      final destPath = '${imagesDir.path}/img_${DateTime.now().millisecondsSinceEpoch}$ext';
      final copied = await file.copy(destPath);

      // Verify the copy succeeded. If not, inform the user and skip inserting.
      final copiedExists = await copied.exists();
      // ignore: avoid_print
      print('Inserting image into template: ${copied.path}, exists: $copiedExists');
      // Log diagnostic to DB
      DatabaseService().logImageDiagnostic(copied.path, copiedExists);
      if (!copiedExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de copier l\'image dans le dossier de l\'application.')),
          );
        }
        return;
      }

      // Insert image embed at current selection
      final index = _controller.selection.baseOffset;
      final pos = index < 0 ? _controller.document.length : index;
      _controller.document.insert(pos, BlockEmbed.image(copied.path));
      _controller.updateSelection(TextSelection.collapsed(offset: pos + 1), ChangeSource.local);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'insertion de l\'image: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // restore original error widget builder (if we changed it)
    try {
      ErrorWidget.builder = _originalErrorWidgetBuilder;
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  // Optional: override global ErrorWidget while editor is active so any widget
  // build errors (for example image file not found) show a harmless placeholder
  // instead of crashing the editor UI.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save and override ErrorWidget.builder
    try {
      _originalErrorWidgetBuilder = ErrorWidget.builder;
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Image.asset('assets/images/placeholder.png', fit: BoxFit.contain);
      };
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: Text('Édition: ${widget.template.name}'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: QuillSimpleToolbar(
                          controller: _controller,
                          config: QuillSimpleToolbarConfig(
                            // Use default embed toolbar buttons to match installed flutter_quill_extensions API
                            embedButtons: FlutterQuillEmbeds.toolbarButtons(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Insérer une image',
                        icon: const Icon(Icons.image),
                        onPressed: _pickImageAndInsert,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: QuillEditor(
                        controller: _controller,
                        focusNode: FocusNode(),
                        scrollController: ScrollController(),
                        config: QuillEditorConfig(
                          // Use default embed builders. We handle missing image files
                          // by logging diagnostics and overriding ErrorWidget to show
                          // a placeholder when a builder fails.
                          embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                          padding: const EdgeInsets.all(16),
                          autoFocus: true,
                          expands: true,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        ElevatedButton(
          onPressed: _saveDocument,
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }
}
