import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import '../../services/database_service.dart';
import '../../services/template_renderer.dart';

class TemplateCanvasDialog extends StatefulWidget {
  final DocumentTemplate template;
  const TemplateCanvasDialog({Key? key, required this.template}) : super(key: key);

  @override
  _TemplateCanvasDialogState createState() => _TemplateCanvasDialogState();
}

class CanvasElement {
  String id;
  String type; // 'text' | 'image' | 'placeholder' | 'shape' | 'qrcode' | 'icon'
  double left;
  double top;
  String text;
  String? imagePath;
  Map<String, dynamic>? style;
  String? shape; // 'rectangle' | 'line' | 'circle'

  double width;
  double height;
  double rotation; // degrees
  String align; // 'left' | 'center' | 'right'
  String? fontFamily;

  CanvasElement({
    required this.id,
    required this.type,
    required this.left,
    required this.top,
    this.text = '',
    this.imagePath,
    this.style,
    this.shape,
    this.width = 200.0,
    this.height = 40.0,
    this.rotation = 0.0,
    this.align = 'left',
    this.fontFamily,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'left': left,
        'top': top,
        'text': text,
        'imagePath': imagePath,
        'style': style,
        'shape': shape,
        'width': width,
        'height': height,
        'rotation': rotation,
        'align': align,
        'fontFamily': fontFamily,
      };

  CanvasElement clone() {
    return CanvasElement(
      id: id,
      type: type,
      left: left,
      top: top,
      text: text,
      imagePath: imagePath,
      style: style != null ? Map<String, dynamic>.from(style!) : null,
      shape: shape,
      width: width,
      height: height,
      rotation: rotation,
      align: align,
      fontFamily: fontFamily,
    );
  }

  static CanvasElement fromJson(Map<String, dynamic> j) => CanvasElement(
        id: j['id'] as String,
        type: j['type'] as String,
        left: (j['left'] as num).toDouble(),
        top: (j['top'] as num).toDouble(),
        text: j['text'] as String? ?? '',
        imagePath: j['imagePath'] as String?,
        style: j['style'] != null ? Map<String, dynamic>.from(j['style'] as Map) : null,
        shape: j['shape'] as String?,
        width: j['width'] != null ? (j['width'] as num).toDouble() : 200.0,
        height: j['height'] != null ? (j['height'] as num).toDouble() : 40.0,
        rotation: j['rotation'] != null ? (j['rotation'] as num).toDouble() : 0.0,
        align: j['align'] as String? ?? 'left',
        fontFamily: j['fontFamily'] as String?,
      );
}

class _TemplateCanvasDialogState extends State<TemplateCanvasDialog> {
  List<CanvasElement> elements = [];
  String? selectedId;
  final Map<String, TextEditingController> _textControllers = {};
  double docWidth = 595;
  double docHeight = 842;
  String docFormat = 'A4';
  String? docBackgroundHex;
  double docBorderWidth = 0.0;
  String? docBorderColorHex;
  final List<String> _colorPalette = [
    '#E5A81B', '#0E4064', '#000000', '#111827', '#374151', '#6B7280', '#9CA3AF', '#FFFFFF', '#F3F4F6', '#FCE7F3', '#FEE2E2',
    '#FEEBC8', '#FEE089', '#FEF3C7', '#ECFCCB', '#D1FAE5', '#D1FAFF', '#DBEAFE', '#E9D5FF', '#FDE68A', '#F97316', '#10B981', '#059669', '#7C3AED', '#EF4444'
  ];
  String docUnit = 'px';
  int docDpi = 72;
  TextEditingController _widthController = TextEditingController();
  TextEditingController _heightController = TextEditingController();

  bool _isFullScreen = false;
  bool _showSafetyMargin = true;
  final double _safetyMarginMm = 10.0;

  final List<List<CanvasElement>> _undoStack = [];
  final List<List<CanvasElement>> _redoStack = [];

  final transformationController = TransformationController();
  BoxConstraints? _canvasConstraints;
  double _overflowMargin = 200.0; // pixels allowed outside the document
  bool _fullScreenEditable = true;

  void _rebuildTextControllers() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _textControllers.clear();
    for (final el in elements) {
      if (el.type == 'text' || el.type == 'placeholder') {
        _textControllers[el.id] = TextEditingController(text: el.text);
      }
    }
  }

  void _pushHistory() {
    final currentState = elements.map((e) => e.clone()).toList();
    _undoStack.add(currentState);
    _redoStack.clear();
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    setState(() {});
  }

  void _undo() {
    if (_undoStack.length > 1) {
      final currentState = _undoStack.removeLast();
      _redoStack.add(currentState);
      setState(() {
        elements = _undoStack.last.map((e) => e.clone()).toList();
        _rebuildTextControllers();
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      final nextState = _redoStack.removeLast();
      _undoStack.add(nextState);
      setState(() {
        elements = nextState.map((e) => e.clone()).toList();
        _rebuildTextControllers();
      });
    }
  }

  void _loadFromTemplate() {
    try {
      dynamic content = widget.template.content;
      try {
        content = renderTemplateJsonContent(widget.template.content, <String, dynamic>{});
      } catch (_) {}
      final parsed = content is String ? jsonDecode(content) : content;
      if (parsed is Map) {
        if (parsed['canvas'] is List) {
          elements = (parsed['canvas'] as List).map((e) => CanvasElement.fromJson(Map<String, dynamic>.from(e))).toList();
        } else {
          elements = [];
        }
        if (parsed['doc'] is Map) {
          final doc = Map<String, dynamic>.from(parsed['doc']);
          docWidth = (doc['width'] as num?)?.toDouble() ?? docWidth;
          docHeight = (doc['height'] as num?)?.toDouble() ?? docHeight;
          docFormat = doc['format'] as String? ?? docFormat;
          docBackgroundHex = doc['background'] as String?;
          docBorderWidth = (doc['borderWidth'] as num?)?.toDouble() ?? docBorderWidth;
          docBorderColorHex = doc['borderColor'] as String? ?? docBorderColorHex;
        }
      } else {
        elements = [];
      }
    } catch (_) {
      elements = [];
    }
    if (docUnit == 'mm') {
      _widthController = TextEditingController(text: _pxToMm(docWidth).toStringAsFixed(1));
      _heightController = TextEditingController(text: _pxToMm(docHeight).toStringAsFixed(1));
    } else {
      _widthController = TextEditingController(text: docWidth.toInt().toString());
      _heightController = TextEditingController(text: docHeight.toInt().toString());
    }
    for (final el in elements) {
      if (el.type == 'text' || el.type == 'placeholder') {
        _textControllers[el.id] = TextEditingController(text: el.text);
      }
    }
    _pushHistory();
  }

  void _resetView() {
    if (_canvasConstraints == null) return;
    final constraints = _canvasConstraints!;
    // Compute a preview scale that lets larger formats occupy more visual space
    // while still fitting into the available area when necessary.
    const double a4Height = 842.0; // points @72dpi
    // Base preview height for an A4 document (in pixels). We scale other formats
    // proportionally to their height relative to A4 but we never exceed available
    // constraints.
    final double maxAvailableHeight = constraints.maxHeight;
    final double baseA4PreviewHeight = min(700.0, maxAvailableHeight);

    // Target preview height is proportional to document height (so bigger
    // formats render larger when there is room), capped to the available
    // height.
    double targetPreviewHeight = (docHeight / a4Height) * baseA4PreviewHeight;
    if (targetPreviewHeight > maxAvailableHeight) targetPreviewHeight = maxAvailableHeight;

    double scale = targetPreviewHeight / docHeight;

    // If, after the proportional calculation, it still doesn't fit horizontally
    // or vertically, fall back to a uniform fit scale (leave a small padding).
    final fitScale = min(constraints.maxWidth / docWidth, constraints.maxHeight / docHeight) * 0.95;
    if (docWidth * scale > constraints.maxWidth || docHeight * scale > constraints.maxHeight) {
      scale = fitScale;
    }

    final x = (constraints.maxWidth - (docWidth * scale)) / 2;
    final y = (constraints.maxHeight - (docHeight * scale)) / 2;

    transformationController.value = Matrix4.identity()
      ..translate(x, y)
      ..scale(scale);
  }

  @override
  void initState() {
    super.initState();
    _loadFromTemplate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canvasConstraints != null) {
        _resetView();
      }
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    transformationController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _mmToPx(double mm) => mm * docDpi / 25.4;
  double _pxToMm(double px) => px * 25.4 / docDpi;

  Future<void> _pickImageForElement(CanvasElement el) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final pth = result.files.single.path!;
      final file = File(pth);
      if (!await file.exists()) return;
      final docs = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${docs.path}/template_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final ext = path.extension(pth);
      final dest = '${imagesDir.path}/img_${DateTime.now().millisecondsSinceEpoch}$ext';
      final copied = await file.copy(dest);
      el.imagePath = copied.path;
      await DatabaseService().logImageDiagnostic(copied.path, await copied.exists());
      setState(() {});
    } catch (e) {
      // ignore
    }
  }

  Future<void> _editRichSpans(CanvasElement el) async {
    final textController = TextEditingController(text: el.text);
    List<Map<String, dynamic>> spans = el.style != null && el.style!['spans'] != null ? List<Map<String, dynamic>>.from(el.style!['spans']) : [];
    String? selectedColor;
    final List<List<Map<String, dynamic>>> _undoStack = [];
    final List<List<Map<String, dynamic>>> _redoStack = [];
    void _pushHistory() {
      _undoStack.add(spans.map((e) => Map<String, dynamic>.from(e)).toList());
      _redoStack.clear();
    }
    void _undo(StateSetter setDlgState) {
      if (_undoStack.isEmpty) return;
      _redoStack.add(spans.map((e) => Map<String, dynamic>.from(e)).toList());
      final prev = _undoStack.removeLast();
      setDlgState(() {
        spans..clear()..addAll(prev.map((e) => Map<String, dynamic>.from(e)));
      });
    }
    void _redo(StateSetter setDlgState) {
      if (_redoStack.isEmpty) return;
      _undoStack.add(spans.map((e) => Map<String, dynamic>.from(e)).toList());
      final next = _redoStack.removeLast();
      setDlgState(() {
        spans..clear()..addAll(next.map((e) => Map<String, dynamic>.from(e)));
      });
    }
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDlgState) => Dialog(
          child: SizedBox(
            width: 700,
            height: 480,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(controller: textController, maxLines: 6, onChanged: (_) {}, onEditingComplete: () {}),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  ElevatedButton(onPressed: () {
                    final sel = textController.selection;
                    if (sel.isValid && !sel.isCollapsed) {
                      _pushHistory();
                      setDlgState(() => spans.add({'start': sel.start, 'end': sel.end, 'bold': true}));
                    }
                  }, child: const Text('Bold')),
                  ElevatedButton(onPressed: () {
                    final sel = textController.selection;
                    if (sel.isValid && !sel.isCollapsed) {
                      _pushHistory();
                      setDlgState(() => spans.add({'start': sel.start, 'end': sel.end, 'italic': true}));
                    }
                  }, child: const Text('Italic')),
                  ElevatedButton(onPressed: () {
                    final sel = textController.selection;
                    if (sel.isValid && !sel.isCollapsed) {
                      _pushHistory();
                      setDlgState(() => spans.add({'start': sel.start, 'end': sel.end, 'fontSize': 18}));
                    }
                  }, child: const Text('Big')),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: () => _undo(setDlgState), child: const Text('Undo')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _redo(setDlgState), child: const Text('Redo')),
                ]),
                const SizedBox(height: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    ElevatedButton(onPressed: () {
                      final sel = textController.selection;
                      if (sel.isValid && !sel.isCollapsed && selectedColor != null) {
                        _pushHistory();
                        setDlgState(() => spans.add({'start': sel.start, 'end': sel.end, 'color': selectedColor}));
                      }
                    }, child: const Text('Appliquer couleur'))
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: _colorPalette.map((hex) => GestureDetector(onTap: () => setDlgState(() => selectedColor = hex), child: Container(width: 24, height: 18, decoration: BoxDecoration(color: _parseColor(hex), border: selectedColor == hex ? Border.all(color: Colors.black, width: 2) : null)))).toList()),
                ]),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: spans.length,
                    itemBuilder: (ctx, i) {
                      final s = spans[i];
                      final start = s['start'] as int;
                      final end = s['end'] as int;
                      final snippet = (start < end && end <= textController.text.length) ? textController.text.substring(start, end) : '<vide>';
                      return ListTile(
                        dense: true,
                        title: Text(snippet, style: TextStyle(fontSize: (s['fontSize'] as num?)?.toDouble() ?? 12, fontWeight: s['bold'] == true ? FontWeight.bold : FontWeight.normal, fontStyle: s['italic'] == true ? FontStyle.italic : FontStyle.normal)),
                        subtitle: s['color'] != null ? Text('${s['color']}', style: TextStyle(color: _parseColor(s['color']))): null,
                        trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () { _pushHistory(); setDlgState(() => spans.removeAt(i)); }),
                      );
                    },
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')), ElevatedButton(onPressed: () {
                  final merged = _mergeSpans(spans, textController.text.length);
                  setState(() {
                    el.text = textController.text;
                    el.style = {...?el.style, 'spans': merged};
                    if (_textControllers.containsKey(el.id)) {
                      _textControllers[el.id]!.text = el.text;
                    }
                  });
                  _pushHistory();
                  Navigator.of(context).pop();
                }, child: const Text('Enregistrer'))])
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mergeSpans(List<Map<String, dynamic>> spans, int textLen) {
    if (spans.isEmpty) return [];
    final normalized = spans.map((s) {
      final start = (s['start'] as int).clamp(0, textLen);
      final end = (s['end'] as int).clamp(0, textLen);
      final map = Map<String, dynamic>.from(s);
      map['start'] = start;
      map['end'] = end;
      return map;
    }).where((s) => (s['end'] as int) > (s['start'] as int)).toList();
    normalized.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
    return normalized;
  }

  List<InlineSpan> _composeSpans(String text, List<Map<String, dynamic>> spans, TextStyle baseStyle) {
    if (spans.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    final int n = text.length;
    final List<Map<String, dynamic>> attrs = List.generate(n, (_) => {});
    for (final s in spans) {
      final start = (s['start'] as int).clamp(0, n);
      final end = (s['end'] as int).clamp(0, n);
      for (int i = start; i < end; i++) {
        attrs[i] = {...attrs[i], ...s};
      }
    }
    final List<InlineSpan> out = [];
    int i = 0;
    while (i < n) {
      final curAttr = attrs[i];
      int j = i + 1;
      while (j < n && mapEquals(attrs[j], curAttr)) j++;
      final segment = text.substring(i, j);
      final segColor = _parseColor(curAttr['color']) ?? baseStyle.color;
      final segSize = (curAttr['fontSize'] as num?)?.toDouble() ?? baseStyle.fontSize ?? 14.0;
      final segWeight = (curAttr['bold'] == true) ? FontWeight.bold : baseStyle.fontWeight ?? FontWeight.normal;
      final segStyle = TextStyle(color: segColor, fontSize: segSize, fontWeight: segWeight, fontStyle: curAttr['italic'] == true ? FontStyle.italic : FontStyle.normal);
      out.add(TextSpan(text: segment, style: segStyle));
      i = j;
    }
    return out;
  }

  void _addElement(String type, {String? text, String? shape}) {
    double width = 300.0;
    double height = 40.0;
    if (type == 'shape') {
      if (shape == 'line') {
        width = 150;
        height = 5;
      } else if (shape == 'circle') {
        width = 100;
        height = 100;
      } else { // rectangle
        width = 100;
        height = 100;
      }
    } else if (type == 'image') {
      width = 160;
      height = 120;
    } else if (type == 'icon') {
      width = 24;
      height = 24;
    }

    final el = CanvasElement(
      id: 'el_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      shape: shape,
      left: 20,
      top: 20,
      text: text ?? (type == 'text' ? 'Texte' : ''),
      style: {
        'fontSize': 14,
        'fontWeight': 'normal',
        'color': type == 'shape' ? '#0E4064' : '#000000',
        'background': null,
        'borderColor': null,
        'borderWidth': 0,
        'borderRadius': 0,
        'padding': 6,
      },
      width: width,
      height: height,
      rotation: 0.0,
      align: 'left',
      fontFamily: 'Nunito',
    );
    setState(() {
      elements.add(el);
      selectedId = el.id;
      if (type == 'text' || type == 'placeholder') {
        if (!_textControllers.containsKey(el.id)) {
          _textControllers[el.id] = TextEditingController(text: el.text);
        }
      }
    });
    _pushHistory();
  }

  void _duplicateElement(CanvasElement original) {
    final newElement = CanvasElement(
      id: 'el_${DateTime.now().millisecondsSinceEpoch}',
      type: original.type,
      left: original.left + 20,
      top: original.top + 20,
      text: original.text,
      imagePath: original.imagePath,
      style: original.style != null ? Map<String, dynamic>.from(original.style!) : null,
      shape: original.shape,
      width: original.width,
      height: original.height,
      rotation: original.rotation,
      align: original.align,
      fontFamily: original.fontFamily,
    );

    if (newElement.type == 'text' || newElement.type == 'placeholder') {
      _textControllers[newElement.id] = TextEditingController(text: newElement.text);
    }

    setState(() {
      elements.add(newElement);
      selectedId = newElement.id;
    });
    _pushHistory();
  }

  Color? _parseColor(dynamic val) {
    if (val == null) return null;
    if (val is int) return Color(val);
    if (val is String) {
      var s = val.replaceAll('#', '').trim();
      if (s.length == 6) s = 'FF' + s;
      try {
        return Color(int.parse(s, radix: 16));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _saveCanvas() async {
    for (final el in elements) {
      if (_textControllers.containsKey(el.id)) {
        el.text = _textControllers[el.id]!.text;
      }
    }
    // Normalize: if elements are outside document bounds by more than overflowMargin,
    // expand document to include them so exports keep the visible layout.
    double minLeft = elements.isEmpty ? 0.0 : elements.map((e) => e.left).reduce(min);
    double minTop = elements.isEmpty ? 0.0 : elements.map((e) => e.top).reduce(min);
    double maxRight = elements.isEmpty ? 0.0 : elements.map((e) => e.left + e.width).reduce(max);
    double maxBottom = elements.isEmpty ? 0.0 : elements.map((e) => e.top + e.height).reduce(max);

    double leftOverflow = minLeft < -_overflowMargin ? minLeft : min(0.0, minLeft);
    double topOverflow = minTop < -_overflowMargin ? minTop : min(0.0, minTop);
    double rightOverflow = maxRight > docWidth + _overflowMargin ? maxRight - docWidth : 0.0;
    double bottomOverflow = maxBottom > docHeight + _overflowMargin ? maxBottom - docHeight : 0.0;

    if (leftOverflow < 0 || topOverflow < 0 || rightOverflow > 0 || bottomOverflow > 0) {
      // Expand document and shift elements so that minLeft/top align at 0
      final newLeft = leftOverflow < 0 ? -leftOverflow : 0.0;
      final newTop = topOverflow < 0 ? -topOverflow : 0.0;
      final newWidth = (docWidth + rightOverflow + newLeft).ceilToDouble();
      final newHeight = (docHeight + bottomOverflow + newTop).ceilToDouble();
      for (final el in elements) {
        el.left = el.left + newLeft;
        el.top = el.top + newTop;
      }
      docWidth = newWidth;
      docHeight = newHeight;
    }
    final canvasJson = jsonEncode({
      'canvas': elements.map((e) => e.toJson()).toList(),
      'doc': {
        'width': docWidth,
        'height': docHeight,
        'format': docFormat,
        'background': docBackgroundHex,
        'borderWidth': docBorderWidth,
        'borderColor': docBorderColorHex,
      }
    });
    final updated = DocumentTemplate(
      id: widget.template.id,
      name: widget.template.name,
      type: widget.template.type,
      content: canvasJson,
      lastModified: DateTime.now(),
    );
    await DatabaseService().saveDocumentTemplate(updated);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildFullScreenPreview() {
    const rulerSize = 20.0;
  // Local controller to track zoom/scale in the full-screen InteractiveViewer
  final fullTransController = TransformationController();
  // Initialize full-screen view at 100% (centered) so the preview shows true 1:1 by default
  {
    final mq = MediaQuery.of(context).size;
    final availW = mq.width - 48; // account for horizontal paddings
    final availH = mq.height - kToolbarHeight - 48; // account for appbar + paddings
    final dx = (availW - docWidth) / 2;
    final dy = (availH - docHeight) / 2;
    try {
      fullTransController.value = Matrix4.identity()..translate(dx.clamp(-10000.0, 10000.0), dy.clamp(-10000.0, 10000.0));
    } catch (_) {
      // noop
    }
  }

  return WillPopScope(
    onWillPop: () async {
      // persist transform back and dispose controller when user closes via back
      transformationController.value = fullTransController.value;
      try { fullTransController.dispose(); } catch (_) {}
      setState(() => _isFullScreen = false);
      return true;
    },
    child: Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: const Color(0xFFF0F0F0),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Aperçu 100% - $docFormat (${_pxToMm(docWidth).toStringAsFixed(1)}mm x ${_pxToMm(docHeight).toStringAsFixed(1)}mm)'),
          actions: [
            IconButton(
              icon: Icon(_fullScreenEditable ? Icons.lock_open : Icons.lock),
              tooltip: _fullScreenEditable ? 'Cliquer pour verrouiller' : 'Cliquer pour autoriser édition',
              onPressed: () => setState(() => _fullScreenEditable = !_fullScreenEditable),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // persist the full-screen transform back to the editor and dispose controller
                try { fullTransController.dispose(); } catch (_) {}
                setState(() {
                  transformationController.value = fullTransController.value;
                  _isFullScreen = false;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Static ribbon above the interactive area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(padding: const EdgeInsets.only(right: 12.0), child: Chip(label: Text(_fullScreenEditable ? 'Mode: Édition' : 'Mode: Aperçu'))),
                      ElevatedButton(onPressed: _fullScreenEditable ? () { _addElement('text'); } : null, child: const Text('Ajouter texte')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _fullScreenEditable ? () { _addElement('image'); } : null, child: const Text('Ajouter image')),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (v) { if (_fullScreenEditable) _addElement('placeholder', text: v); },
                        itemBuilder: (_) => <PopupMenuEntry<String>>[
                          const PopupMenuItem(value: '{{company_logo}}', child: Text('Logo entreprise')),
                          const PopupMenuItem(value: '{{student_name}}', child: Text('Nom étudiant')),
                          const PopupMenuItem(value: '{{current_date}}', child: Text('Date du jour')),
                        ],
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(4)), child: const Text('Espace réservé')),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: docFormat,
                        items: ['A0','A1','A2','A3','A4','A5'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          // update doc size and keep 100% scale in full-screen by setting transform to identity
                          setState(() {
                            docFormat = v;
                            switch (v) {
                              case 'A0': docWidth = 2384; docHeight = 3370; break;
                              case 'A1': docWidth = 1684; docHeight = 2384; break;
                              case 'A2': docWidth = 1191; docHeight = 1684; break;
                              case 'A3': docWidth = 842; docHeight = 1191; break;
                              case 'A4': docWidth = 595; docHeight = 842; break;
                              case 'A5': docWidth = 420; docHeight = 595; break;
                            }
                            // center the document at 100% scale in the full-screen viewer
                            final mq = MediaQuery.of(context).size;
                            final availW = mq.width - 48; // account for horizontal padding
                            final availH = mq.height - kToolbarHeight - 48; // account for appbar and vertical padding
                            final dx = (availW - docWidth) / 2;
                            final dy = (availH - docHeight) / 2;
                            try {
                              fullTransController.value = Matrix4.identity()..translate(dx.clamp(-10000.0, 10000.0), dy.clamp(-10000.0, 10000.0));
                            } catch (_) {}
                          });
                          _pushHistory();
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(onPressed: _redoStack.isNotEmpty ? _redo : null, child: const Text('Rétablir')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _undoStack.length > 1 ? _undo : null, child: const Text('Annuler')),
                      const SizedBox(width: 12),
                      ElevatedButton(onPressed: _fullScreenEditable ? _saveCanvas : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Enregistrer')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () {
                        // Fit to screen: compute scale and center
                        final mq = MediaQuery.of(context).size;
                        final availW = mq.width - 48;
                        final availH = mq.height - kToolbarHeight - 48;
                        final fitScale = (availW > 0 && availH > 0) ? ( (availW / docWidth).clamp(0.05, 10.0) < (availH / docHeight).clamp(0.05, 10.0) ? (availW / docWidth) : (availH / docHeight) ) : 1.0;
                        final scale = fitScale * 0.95;
                        final x = (availW - docWidth * scale) / 2;
                        final y = (availH - docHeight * scale) / 2;
                        try {
                          fullTransController.value = Matrix4.identity()..translate(x, y)..scale(scale);
                        } catch (_) {}
                      }, child: const Text('Fit')),
                      const SizedBox(width: 12),
                      Row(children: _colorPalette.map((hex) => GestureDetector(onTap: () { if (!_fullScreenEditable) return; setState(() => docBackgroundHex = hex); _pushHistory(); }, child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 24, height: 18, decoration: BoxDecoration(color: _parseColor(hex), border: docBackgroundHex == hex ? Border.all(color: Colors.black, width: 2) : null)))).toList()),
                      const SizedBox(width: 12),
                      Row(children: [Text('Marge sécurité'), Switch(value: _showSafetyMargin, onChanged: (v) { if (!_fullScreenEditable) return; setState(() => _showSafetyMargin = v); _pushHistory(); })]),
                    ],
                  ),
                ),
              ),
            ),
            // Interactive area
            Expanded(
              child: InteractiveViewer(
                transformationController: fullTransController,
                minScale: 0.1,
                maxScale: 4.0,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Horizontal Ruler
                        SizedBox(
                          height: rulerSize,
                          width: docWidth + rulerSize,
                          child: CustomPaint(
                            painter: RulerPainter(
                              axis: Axis.horizontal,
                              length: docWidth,
                              unit: docUnit,
                              dpi: docDpi,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                      // Vertical Ruler
                      SizedBox(
                        width: rulerSize,
                        height: docHeight,
                        child: CustomPaint(
                          painter: RulerPainter(
                            axis: Axis.vertical,
                            length: docHeight,
                            unit: docUnit,
                            dpi: docDpi,
                          ),
                        ),
                      ),
                      // Canvas
                      Container(
                        width: docWidth,
                        height: docHeight,
                        decoration: BoxDecoration(
                          color: _parseColor(docBackgroundHex) ?? Colors.white,
                          border: docBorderWidth > 0 ? Border.all(color: _parseColor(docBorderColorHex) ?? Colors.black, width: docBorderWidth) : null,
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ...elements.map((el) {
                              final scale = fullTransController.value.getMaxScaleOnAxis();
                              return Positioned(
                                left: el.left,
                                top: el.top,
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedId = el.id),
                                  onPanUpdate: (d) {
                                    setState(() {
                                      // convert gesture delta to document space using current scale
                                      final s = (scale <= 0) ? 1.0 : scale;
                                      el.left = (el.left + d.delta.dx / s).clamp(-_overflowMargin, docWidth - el.width + _overflowMargin);
                                      el.top = (el.top + d.delta.dy / s).clamp(-_overflowMargin, docHeight - el.height + _overflowMargin);
                                    });
                                  },
                                  onPanEnd: (_) => _pushHistory(),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(border: Border.all(color: selectedId == el.id ? Colors.blue : Colors.transparent, width: 1.0 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()))),
                                    child: Transform.rotate(
                                      angle: el.rotation * 3.1415926535 / 180.0,
                                      origin: Offset(el.width / 2, el.height / 2),
                                      child: SizedBox(
                                        width: el.width,
                                        height: el.height,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned.fill(child: _buildElementWidget(el)),
                                            if (selectedId == el.id)
                                              Positioned(
                                                right: -6 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()),
                                                bottom: -6 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()),
                                                child: GestureDetector(
                                                  onPanUpdate: (d) {
                                                    setState(() {
                                                      final s = (fullTransController.value.getMaxScaleOnAxis() <= 0) ? 1.0 : fullTransController.value.getMaxScaleOnAxis();
                                                      el.width = (el.width + d.delta.dx / s).clamp(24.0, 1200.0);
                                                      el.height = (el.height + d.delta.dy / s).clamp(1.0, 1200.0);
                                                    });
                                                  },
                                                  onPanEnd: (_) => _pushHistory(),
                                                  child: Container(width: 12 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()), height: 12 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis())))),
                                                ),
                                              ),
                                            if (selectedId == el.id)
                                              Positioned(
                                                top: -18 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()),
                                                left: (el.width / 2) - (12 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis())),
                                                child: GestureDetector(
                                                  onPanUpdate: (d) {
                                                    setState(() {
                                                      el.rotation = (el.rotation + d.delta.dx).clamp(-360.0, 360.0);
                                                    });
                                                  },
                                                  onPanEnd: (_) => _pushHistory(),
                                                  child: Container(width: 24 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()), height: 24 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()))), child: Icon(Icons.rotate_right, size: 16 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()))),
                                                ),
                                              ),
                                          if (selectedId == el.id && _fullScreenEditable)
                                            Positioned(
                                              top: -48 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()),
                                              right: -6 / (fullTransController.value.getMaxScaleOnAxis() <= 0 ? 1.0 : fullTransController.value.getMaxScaleOnAxis()),
                                              child: AnimatedOpacity(
                                                duration: const Duration(milliseconds: 180),
                                                opacity: (selectedId == el.id && _fullScreenEditable) ? 1.0 : 0.0,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(icon: const Icon(Icons.copy, size: 18), tooltip: 'Dupliquer', onPressed: _fullScreenEditable ? () { _duplicateElement(el); } : null),
                                                        IconButton(icon: const Icon(Icons.delete, size: 18), tooltip: 'Supprimer', onPressed: _fullScreenEditable ? () { setState(() { elements.removeWhere((e) => e.id == el.id); selectedId = elements.isNotEmpty ? elements.last.id : null; }); _pushHistory(); } : null),
                                                        IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: 'Éditer', onPressed: _fullScreenEditable ? () { if (el.type == 'text' || el.type == 'placeholder') _editRichSpans(el); else if (el.type == 'image') _pickImageForElement(el); } : null),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            if (_showSafetyMargin)
                              Positioned.fill(
                                child: Container(
                                  margin: EdgeInsets.all(_mmToPx(_safetyMarginMm)),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.0, style: BorderStyle.solid),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ), // Padding
        ), // SingleChildScrollView
      ), // InteractiveViewer
    ), // Scaffold
      ]  ), // Dialog
  ))); // WillPopScope
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) return _buildFullScreenPreview();
    final CanvasElement? selected = elements.isEmpty ? null : elements.firstWhere((e) => e.id == selectedId, orElse: () => elements.first);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Row(
          children: [
            // Toolbox
            Container(
              width: 160,
              color: const Color(0xFF111827),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.undo, color: Colors.white),
                          onPressed: _undoStack.length > 1 ? _undo : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.redo, color: Colors.white),
                          onPressed: _redoStack.isNotEmpty ? _redo : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                          onPressed: _resetView,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => _addElement('text'), child: const Text('Ajouter du texte')),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: () => _addElement('image'), child: const Text('Ajouter une image')),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        _addElement('icon', text: value);
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'check_box_outline_blank',
                          child: Text('Case à cocher (vide)'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'check_box',
                          child: Text('Case à cocher (cochée)'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: Text('Ajouter une icône', style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        _addElement('shape', shape: value);
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'rectangle',
                          child: Text('Rectangle'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'line',
                          child: Text('Ligne'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'circle',
                          child: Text('Cercle'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: Text('Ajouter une forme', style: TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        _addElement('placeholder', text: value);
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: '{{company_logo}}',
                          child: Text('Logo de l\'entreprise'),
                        ),
                        const PopupMenuItem<String>(
                          value: '{{student_name}}',
                          child: Text('Nom de l\'étudiant'),
                        ),
                        const PopupMenuItem<String>(
                          value: '{{formation_title}}',
                          child: Text('Titre de la formation'),
                        ),
                        const PopupMenuItem<String>(
                          value: '{{invoice_id}}',
                          child: Text('Numéro de facture'),
                        ),
                        const PopupMenuItem<String>(
                          value: '{{current_date}}',
                          child: Text('Date du jour'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Espace réservé',
                                style: TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Instructions', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('Déplacez les éléments sur la zone. Sélectionnez un élément pour modifier ses propriétés.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    const Text('Format', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: docFormat,
                      dropdownColor: const Color(0xFF334155),
                      items: ['A0','A1','A2','A3','A4','A5'].map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          docFormat = v;
                          switch (v) {
                            case 'A0': docWidth = 2384; docHeight = 3370; break;
                            case 'A1': docWidth = 1684; docHeight = 2384; break;
                            case 'A2': docWidth = 1191; docHeight = 1684; break;
                            case 'A3': docWidth = 842; docHeight = 1191; break;
                            case 'A4': docWidth = 595; docHeight = 842; break;
                            case 'A5': docWidth = 420; docHeight = 595; break;
                          }
                          if (docUnit == 'mm') {
                            _widthController.text = _pxToMm(docWidth).toStringAsFixed(1);
                            _heightController.text = _pxToMm(docHeight).toStringAsFixed(1);
                          } else {
                            _widthController.text = docWidth.toInt().toString();
                            _heightController.text = docHeight.toInt().toString();
                          }
                          _resetView();
                        });
                        _pushHistory();
                      }
                    ),
                    const SizedBox(height: 8),
                    Text('Taille personnalisée (${docUnit})', style: const TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: TextField(controller: _widthController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, onSubmitted: (v) { final val = double.tryParse(v); if (val != null) setState(() { docWidth = docUnit == 'mm' ? _mmToPx(val) : val; _widthController.text = docUnit == 'mm' ? _pxToMm(docWidth).toStringAsFixed(1) : docWidth.toInt().toString(); }); _pushHistory(); })),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _heightController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, onSubmitted: (v) { final val = double.tryParse(v); if (val != null) setState(() { docHeight = docUnit == 'mm' ? _mmToPx(val) : val; _heightController.text = docUnit == 'mm' ? _pxToMm(docHeight).toStringAsFixed(1) : docHeight.toInt().toString(); }); _pushHistory(); })),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Fond du document', style: TextStyle(color: Colors.white)),
                    Wrap(spacing: 6, children: _colorPalette.map((hex) => GestureDetector(onTap: () { setState(() => docBackgroundHex = hex); _pushHistory(); }, child: Container(width: 28, height: 20, decoration: BoxDecoration(color: _parseColor(hex), border: docBackgroundHex == hex ? Border.all(color: Colors.white, width: 2) : null)))).toList()),
                    const SizedBox(height: 12),
                    const Text('Bordure du document', style: TextStyle(color: Colors.white70)),
                    Slider(value: docBorderWidth, min: 0, max: 12, onChanged: (v) => setState(() => docBorderWidth = v), onChangeEnd: (v) => _pushHistory()),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: _colorPalette.map((hex) => GestureDetector(onTap: () { setState(() => docBorderColorHex = hex); _pushHistory(); }, child: Container(width: 28, height: 20, decoration: BoxDecoration(color: _parseColor(hex), border: docBorderColorHex == hex ? Border.all(color: Colors.white, width: 2) : null)))).toList()),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _saveCanvas, child: const Text('Enregistrer')),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    const Text('Affichage', style: TextStyle(color: Colors.white)),
                    SwitchListTile(
                      title: const Text('Marge de sécurité (10mm)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      value: _showSafetyMargin,
                      onChanged: (bool val) => setState(() => _showSafetyMargin = val),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Text('Zone de débord autorisée (${_overflowMargin.toInt()} px)', style: const TextStyle(color: Colors.white70)),
                    Slider(
                      value: _overflowMargin,
                      min: 0,
                      max: 1000,
                      divisions: 20,
                      label: '${_overflowMargin.toInt()} px',
                      onChanged: (v) => setState(() => _overflowMargin = v),
                      onChangeEnd: (v) => _pushHistory(),
                    ),
                    ElevatedButton(onPressed: () {
                      setState(() => _isFullScreen = true);
                    }, child: const Text('Aperçu plein écran')),
                    const SizedBox(height: 12),
                    Text('DPI: $docDpi | Unité: $docUnit', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(height: 12),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer'))
                  ],
                ),
              ),
            ),
            // Canvas
            Expanded(
              child: Container(
                color: const Color(0xFF0B1220),
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, constraints) {
                  _canvasConstraints = constraints;
                  final scale = transformationController.value.getMaxScaleOnAxis();
                  // Allow larger dragging area around the document so users can
                  // pan outside the white area. Scale margin with document size.
                  final double overflowMargin = max(_overflowMargin, max(docWidth, docHeight) * 0.5);
                  return InteractiveViewer(
                    transformationController: transformationController,
                    minScale: 0.05,
                    maxScale: 6.0,
                    panEnabled: true,
                    boundaryMargin: EdgeInsets.all(overflowMargin),
                    child: Container(
                      width: docWidth,
                      height: docHeight,
                      decoration: BoxDecoration(
                        color: _parseColor(docBackgroundHex) ?? Colors.white,
                        border: docBorderWidth > 0 ? Border.all(color: _parseColor(docBorderColorHex) ?? Colors.black, width: docBorderWidth) : null,
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)],
                      ),
                      child: Stack(
                        children: [
                          ...elements.map((el) {
                            final isSelected = selectedId == el.id;
                            return Positioned(
                              left: el.left,
                              top: el.top,
                              child: GestureDetector(
                                onTap: () => setState(() => selectedId = el.id),
                                onPanUpdate: (d) {
                                  setState(() {
                                    // Allow a small overflow beyond document edges so the
                                    // user can position elements slightly outside. We keep
                                    // a soft clamp to a negative overflow and doc+overflow.
                                    final double overflow = _overflowMargin; // px
                                    el.left = (el.left + d.delta.dx / scale).clamp(-overflow, docWidth - el.width + overflow);
                                    el.top = (el.top + d.delta.dy / scale).clamp(-overflow, docHeight - el.height + overflow);
                                  });
                                },
                                onPanEnd: (_) => _pushHistory(),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 1 / scale)),
                                  child: Transform.rotate(
                                    angle: el.rotation * 3.1415926535 / 180.0,
                                    origin: Offset(el.width / 2, el.height / 2),
                                    child: SizedBox(
                                      width: el.width,
                                      height: el.height,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(child: _buildElementWidget(el)),
                                          if (isSelected)
                                            Positioned(
                                              right: -6 / scale,
                                              bottom: -6 / scale,
                                              child: GestureDetector(
                                                onPanUpdate: (d) {
                                                  setState(() {
                                                    el.width = (el.width + d.delta.dx / scale).clamp(24.0, 1200.0);
                                                    el.height = (el.height + d.delta.dy / scale).clamp(1.0, 1200.0);
                                                  });
                                                },
                                                onPanEnd: (_) => _pushHistory(),
                                                child: Container(width: 12 / scale, height: 12 / scale, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1 / scale))),
                                              ),
                                            ),
                                          if (isSelected)
                                            Positioned(
                                              top: -18 / scale,
                                              left: (el.width / 2) - (12 / scale),
                                              child: GestureDetector(
                                                onPanUpdate: (d) {
                                                  setState(() {
                                                    el.rotation = (el.rotation + d.delta.dx).clamp(-360.0, 360.0);
                                                  });
                                                },
                                                onPanEnd: (_) => _pushHistory(),
                                                child: Container(width: 24 / scale, height: 24 / scale, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1 / scale)), child: Icon(Icons.rotate_right, size: 16 / scale)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          if (_showSafetyMargin)
                            Positioned.fill(
                              child: Container(
                                margin: EdgeInsets.all(_mmToPx(_safetyMarginMm)),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.0 / scale, style: BorderStyle.solid),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            Container(
              width: 280,
              color: const Color(0xFF111827),
              padding: const EdgeInsets.all(12),
              child: selected == null
                  ? const Center(child: Text('Aucune sélection', style: TextStyle(color: Colors.white70)))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Propriétés', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 12),
                          const Text('Type', style: TextStyle(color: Colors.white70)),
                          Text(selected.type, style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 12),
                          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Largeur', style: TextStyle(color: Colors.white70)), Slider(value: selected.width.clamp(24.0, 1000.0), min: 24, max: 1000, onChanged: (v) => setState(() => selected.width = v), onChangeEnd: (v) => _pushHistory())])),
                          ]),
                          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Hauteur', style: TextStyle(color: Colors.white70)), Slider(value: selected.height.clamp(1.0, 1200.0), min: 1, max: 1200, onChanged: (v) => setState(() => selected.height = v), onChangeEnd: (v) => _pushHistory())])),
                          ]),
                          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rotation', style: TextStyle(color: Colors.white70)), Slider(value: selected.rotation.clamp(-360.0, 360.0), min: -360, max: 360, onChanged: (v) => setState(() => selected.rotation = v), onChangeEnd: (v) => _pushHistory())])),
                          ]),
                          const SizedBox(height: 8),
                          const Text('Alignement', style: TextStyle(color: Colors.white70)),
                          Wrap(spacing: 8, children: [
                            ChoiceChip(label: const Text('Gauche'), selected: selected.align == 'left', onSelected: (_) { setState(() => selected.align = 'left'); _pushHistory(); }),
                            ChoiceChip(label: const Text('Centre'), selected: selected.align == 'center', onSelected: (_) { setState(() => selected.align = 'center'); _pushHistory(); }),
                            ChoiceChip(label: const Text(' Droite'), selected: selected.align == 'right', onSelected: (_) { setState(() => selected.align = 'right'); _pushHistory(); }),
                          ]),
                          const SizedBox(height: 8),
                          const Text('Police', style: TextStyle(color: Colors.white70)),
                          DropdownButton<String>(value: selected.fontFamily ?? 'Nunito', dropdownColor: const Color(0xFF334155), items: ['Nunito', 'JosefinSans', 'Arial', 'Times New Roman'].map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: Colors.white)))).toList(), onChanged: (v) { setState(() => selected.fontFamily = v); _pushHistory(); }),
                          const SizedBox(height: 8),
                          const Text('Taille', style: TextStyle(color: Colors.white70)),
                          Slider(value: ((selected.style?['fontSize'] as num?)?.toDouble() ?? 14.0).clamp(8.0, 48.0), min: 8, max: 48, onChanged: (v) => setState(() => selected.style = {...?selected.style, 'fontSize': v}), onChangeEnd: (v) => _pushHistory()),
                          const SizedBox(height: 8),
                          const Text('Couleur', style: TextStyle(color: Colors.white70)),
                          Wrap(spacing: 8, children: _colorPalette.map((hex) => GestureDetector(onTap: () { setState(() => selected.style = {...?selected.style, 'color': hex}); _pushHistory(); }, child: Container(width: 28, height: 20, color: _parseColor(hex)))).toList()),
                          const SizedBox(height: 8),
                          const Text('Fond', style: TextStyle(color: Colors.white70)),
                          Wrap(spacing: 8, children: _colorPalette.map((hex) => GestureDetector(onTap: () { setState(() => selected.style = {...?selected.style, 'background': hex}); _pushHistory(); }, child: Container(width: 28, height: 20, color: _parseColor(hex)))).toList()),
                          const SizedBox(height: 8),
                          const Text('Bordure (px)', style: TextStyle(color: Colors.white70)),
                          Slider(value: ((selected.style?['borderWidth'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 8.0), min: 0, max: 8, onChanged: (v) => setState(() => selected.style = {...?selected.style, 'borderWidth': v}), onChangeEnd: (v) => _pushHistory()),
                          const SizedBox(height: 8),
                          const Text('Couleur bordure', style: TextStyle(color: Colors.white70)),
                          Wrap(spacing: 8, children: _colorPalette.map((hex) => GestureDetector(onTap: () { setState(() => selected.style = {...?selected.style, 'borderColor': hex}); _pushHistory(); }, child: Container(width: 28, height: 20, color: _parseColor(hex)))).toList()),
                          const SizedBox(height: 8),
                          const Text('Rayon bordure', style: TextStyle(color: Colors.white70)),
                          Slider(value: ((selected.style?['borderRadius'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 32.0), min: 0, max: 32, onChanged: (v) => setState(() => selected.style = {...?selected.style, 'borderRadius': v}), onChangeEnd: (v) => _pushHistory()),
                          const SizedBox(height: 8),
                          if (selected.type == 'text' || selected.type == 'placeholder') ...[
                            const Text('Texte', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                          TextField(
                            controller: _textControllers[selected.id] ??= TextEditingController(text: selected.text),
                            maxLines: 4,
                            onChanged: (v) {
                              selected.text = v;
                            },
                            onEditingComplete: () => _pushHistory(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: () => _editRichSpans(selected), child: const Text('Éditer (texte riche)')),
                          ],
                          if (selected.type == 'image') ...[
                            const Text('Image', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            if (selected.imagePath != null) ...[
                              Image.file(File(selected.imagePath!), height: 120),
                              const SizedBox(height: 8),
                            ],
                            ElevatedButton(onPressed: () => _pickImageForElement(selected), child: const Text('Choisir une image'))
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              _duplicateElement(selected);
                            },
                            child: const Text('Dupliquer l\'élément'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (selectedId != null && _textControllers.containsKey(selectedId)) {
                                  _textControllers[selectedId]!.dispose();
                                  _textControllers.remove(selectedId);
                                }
                                elements.removeWhere((e) => e.id == selectedId);
                                selectedId = elements.isNotEmpty ? elements.last.id : null;
                              });
                              _pushHistory();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Supprimer l\'élément'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElementWidget(CanvasElement el) {
    final bg = _parseColor(el.style?['background']);
    final color = _parseColor(el.style?['color']);
    final borderColor = _parseColor(el.style?['borderColor']);
    final borderWidth = (el.style?['borderWidth'] as num?)?.toDouble() ?? 0.0;
    final borderRadius = (el.style?['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final padding = (el.style?['padding'] as num?)?.toDouble() ?? 4.0;
    final fontSize = (el.style?['fontSize'] as num?)?.toDouble() ?? 14.0;
    final fontWeightStr = el.style?['fontWeight'] as String? ?? 'normal';
    final fw = fontWeightStr == 'bold' ? FontWeight.bold : FontWeight.normal;

    switch (el.type) {
      case 'text':
      case 'placeholder':
        if (el.style != null && el.style!['spans'] != null) {
          final spans = List<Map<String, dynamic>>.from(el.style!['spans']);
          final text = el.text;
          final merged = _mergeSpans(spans, text.length);
          final baseStyle = TextStyle(color: color ?? (el.type == 'placeholder' ? Colors.grey : Colors.black), fontSize: fontSize, fontWeight: fw);
          final children = _composeSpans(text, merged, baseStyle);
          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(color: bg ?? Colors.transparent, border: borderWidth > 0 ? Border.all(color: borderColor ?? Colors.black, width: borderWidth) : null, borderRadius: BorderRadius.circular(borderRadius)),
            child: RichText(text: TextSpan(children: children)),
          );
        }
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: bg ?? Colors.transparent,
            border: borderWidth > 0 ? Border.all(color: borderColor ?? Colors.black, width: borderWidth) : null,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Text(
            el.text,
            style: TextStyle(color: color ?? (el.type == 'placeholder' ? Colors.grey : Colors.black), fontSize: fontSize, fontWeight: fw),
          ),
        );
      case 'image':
        if (el.imagePath != null && File(el.imagePath!).existsSync()) {
          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: bg ?? Colors.transparent,
              border: borderWidth > 0 ? Border.all(color: borderColor ?? Colors.black, width: borderWidth) : null,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Image.file(File(el.imagePath!), fit: BoxFit.contain),
          );
        }
        return Container(padding: EdgeInsets.all(padding), child: const Text('Pas d\'image'));
      case 'icon':
        IconData iconData;
        switch (el.text) {
          case 'check_box_outline_blank':
            iconData = Icons.check_box_outline_blank;
            break;
          case 'check_box':
            iconData = Icons.check_box;
            break;
          case 'verified':
            iconData = Icons.verified;
            break;
          case 'school':
            iconData = Icons.school;
            break;
          case 'star':
            iconData = Icons.star;
            break;
          default:
            iconData = Icons.info;
            break;
        }
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: bg ?? Colors.transparent,
            border: borderWidth > 0 ? Border.all(color: borderColor ?? Colors.black, width: borderWidth) : null,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(iconData, size: fontSize * 1.6, color: color ?? Colors.black),
        );
      case 'shape':
        final style = el.style ?? {};
        final color = _parseColor(style['color']) ?? Colors.black;
        if (el.shape == 'line') {
          return Container(
            width: el.width,
            height: el.height,
            color: color,
          );
        } else if (el.shape == 'circle') {
          return Container(
            width: el.width,
            height: el.height,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: _parseColor(style['borderColor']) ?? Colors.transparent,
                width: (style['borderWidth'] as num?)?.toDouble() ?? 0.0,
              ),
            ),
          );
        }
        // Default to rectangle
        return Container(
          width: el.width,
          height: el.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 0.0),
            border: Border.all(
              color: _parseColor(style['borderColor']) ?? Colors.transparent,
              width: (style['borderWidth'] as num?)?.toDouble() ?? 0.0,
            ),
          ),
        );
      case 'qrcode':
        return Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(Icons.qr_code, color: Colors.white, size: min(el.width, el.height) * 0.8),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class RulerPainter extends CustomPainter {
  final Axis axis;
  final double length;
  final String unit;
  final int dpi;

  RulerPainter({required this.axis, required this.length, required this.unit, required this.dpi});

  double _mmToPx(double mm) => mm * dpi / 25.4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 0.5;

    final textStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 8,
    );

    final double startOffset = (axis == Axis.horizontal) ? size.width - length : size.height - length;

    if (axis == Axis.horizontal) {
      for (double i = 0; i <= length; i += _mmToPx(1)) {
        final mmValue = (i / _mmToPx(1)).round();
        final isCm = mmValue % 10 == 0;
        final isHalfCm = mmValue % 5 == 0;
        final y = isCm ? 10.0 : (isHalfCm ? 14.0 : 16.0);
        canvas.drawLine(Offset(startOffset + i, y), Offset(startOffset + i, size.height), paint);
        if (isCm && i > 0) {
          final textSpan = TextSpan(
            text: '${mmValue ~/ 10}',
            style: textStyle,
          );
          final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(minWidth: 20);
          textPainter.paint(canvas, Offset(startOffset + i - (textPainter.width / 2), 0));
        }
      }
    } else {
      for (double i = 0; i <= length; i += _mmToPx(1)) {
        final mmValue = (i / _mmToPx(1)).round();
        final isCm = mmValue % 10 == 0;
        final isHalfCm = mmValue % 5 == 0;
        final x = isCm ? 10.0 : (isHalfCm ? 14.0 : 16.0);
        canvas.drawLine(Offset(x, startOffset + i), Offset(size.width, startOffset + i), paint);
        if (isCm && i > 0) {
          final textSpan = TextSpan(
            text: '${mmValue ~/ 10}',
            style: textStyle,
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(0, startOffset + i - textPainter.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
