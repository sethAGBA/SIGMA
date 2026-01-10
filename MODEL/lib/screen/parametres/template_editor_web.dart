import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/database_service.dart';
import 'models.dart';

class TemplateEditorWeb extends StatefulWidget {
  final DocumentTemplate template;
  const TemplateEditorWeb({Key? key, required this.template}) : super(key: key);

  @override
  _TemplateEditorWebState createState() => _TemplateEditorWebState();
}

// Modal dialog wrapper for the web editor. Use showDialog to open.
class TemplateEditorWebDialog extends StatelessWidget {
  final DocumentTemplate template;
  const TemplateEditorWebDialog({Key? key, required this.template}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: TemplateEditorWeb(template: template),
      ),
    );
  }
}

class _TemplateEditorWebState extends State<TemplateEditorWeb> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();

    _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
  _controller.addJavaScriptChannel('Dart', onMessageReceived: (msg) async {
      // Expect JSON messages from the editor
      try {
        final Map<String, dynamic> data = jsonDecode(msg.message);
        final action = data['action'] as String? ?? '';
        if (action == 'ready') {
          // Send initial content (HTML) to the editor
          final html = _templateToHtml(widget.template);
          _controller.runJavaScript('window.loadContent(${jsonEncode(html)});');
        } else if (action == 'save') {
          final contentHtml = data['html'] as String? ?? '';
          // Persist HTML into the template content field (store HTML string)
          final updated = DocumentTemplate(
            id: widget.template.id,
            name: widget.template.name,
            type: widget.template.type,
            content: jsonEncode({'html': contentHtml}),
            lastModified: DateTime.now(),
          );
          await DatabaseService().saveDocumentTemplate(updated);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modèle sauvegardé (web)')));
        } else if (action == 'uploadImage') {
          final base64Data = data['data'] as String?;
          final filename = data['filename'] as String? ?? 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          final uploadId = data['uploadId'] as String? ?? '';
          if (base64Data != null) {
            final bytes = base64Decode(base64Data);
            final documents = await getApplicationDocumentsDirectory();
            final imagesDir = Directory('${documents.path}/template_images');
            if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
            final file = File('${imagesDir.path}/$filename');
            await file.writeAsBytes(bytes);
            // Respond with the saved file path and uploadId
            final resp = jsonEncode({'action': 'uploaded', 'url': file.path, 'uploadId': uploadId});
            // Call the JS callback with the JSON string
            _controller.runJavaScript('window.onImageUploaded(${jsonEncode(resp)})');
          }
        }
      } catch (e) {
        // ignore
      }
    });

    // Load local HTML asset
    _controller.loadFlutterAsset('assets/web/ckeditor_editor.html');
  }

  String _templateToHtml(DocumentTemplate t) {
    // If content is JSON wrapping HTML (as we store above), extract it
    try {
      final parsed = jsonDecode(t.content);
      if (parsed is Map && parsed['html'] is String) return parsed['html'] as String;
    } catch (_) {}
    // fallback: treat content as raw HTML or delta
    return t.content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Édition web: ${widget.template.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              _controller.runJavaScript('window.requestSave();');
            },
          )
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
