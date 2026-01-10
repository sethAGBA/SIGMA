import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
// image package not required for QR rendering; removed to avoid unused import
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
// QR generation handled via pdf's BarcodeWidget (avoid direct 'qr' package usage)
import '../services/template_renderer.dart';
import '../screen/parametres/models.dart';
import '../services/database_service.dart';

/// Generates a PDF from a JSON-based canvas template.
/// The `data` map should include all necessary dynamic content, including company information
/// (e.g., company_name, company_logo, company_address) if the template uses them.
Future<Uint8List> generatePdfFromCanvasTemplate(DocumentTemplate template, Map<String, dynamic> data) async {
  print('Generating PDF from canvas template: ${template.name}'); // Added print statement
  // Ensure company information is present in the data map. If it's not provided
  // by the caller, try to load it from the DB and merge it. This makes canvas
  // template exports automatically include the entreprise settings (logo,
  // name, address, contacts, etc.) from the Paramètres -> Entreprise tab.
  final mergedData = Map<String, dynamic>.from(data);
  final hasCompanyKey = mergedData.containsKey('company_name') || mergedData.containsKey('companyName') || mergedData.containsKey('company_logo') || mergedData.containsKey('companyLogo');
  if (!hasCompanyKey) {
    try {
      final company = await DatabaseService().getCompanyInfo();
      if (company != null) {
  mergedData['company_name'] = company.name;
  mergedData['companyName'] = company.name;
  mergedData['company_address'] = company.address;
  mergedData['companyAddress'] = company.address;
  mergedData['company_phone'] = company.phone;
  mergedData['companyPhone'] = company.phone;
  mergedData['company_email'] = company.email;
  mergedData['companyEmail'] = company.email;
  mergedData['company_logo'] = company.logoPath;
  mergedData['companyLogo'] = company.logoPath;
  mergedData['company_rccm'] = company.rccm;
  mergedData['company_nif'] = company.nif;
  mergedData['company_website'] = company.website;
  mergedData['academic_year'] = company.academic_year;
      }
    } catch (_) {
      // ignore failures to keep template rendering functional
    }
  }

  // Render template placeholders into the JSON structure using the merged data
  final rendered = renderTemplateJsonContent(template.content, mergedData);
  final parsed = rendered is String ? jsonDecode(rendered) : rendered;

  // Extract canvas and doc settings
  final canvas = parsed is Map && parsed['canvas'] is List ? List.from(parsed['canvas']) : <dynamic>[];
  final docInfo = parsed is Map && parsed['doc'] is Map ? Map<String, dynamic>.from(parsed['doc']) : <String, dynamic>{};

  final double width = (docInfo['width'] as num?)?.toDouble() ?? PdfPageFormat.a4.width;
  final double height = (docInfo['height'] as num?)?.toDouble() ?? PdfPageFormat.a4.height;

  final pdf = pw.Document();

  // Load a Unicode-capable font from assets to avoid missing glyphs (box drawing, unicode symbols)
  pw.Font? baseFont;
  try {
    final fontData = await rootBundle.load('assets/fonts/Nunito-Regular.ttf');
    baseFont = pw.Font.ttf(fontData.buffer.asByteData());
  } catch (_) {
    // fallback: use built-in font (may not support all glyphs)
    baseFont = null;
  }

  // Convert hex color string to PdfColor
  PdfColor? _maybeColorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return null;
    final r = int.parse(h.substring(0, 2), radix: 16);
    final g = int.parse(h.substring(2, 4), radix: 16);
    final b = int.parse(h.substring(4, 6), radix: 16);
    return PdfColor(r / 255.0, g / 255.0, b / 255.0);
  }

  bool _mapEquals(Map m1, Map m2) {
  if (m1.length != m2.length) return false;
  for (final key in m1.keys) {
    if (!m2.containsKey(key) || m1[key] != m2[key]) {
      return false;
    }
  }
  return true;
}

  // QR codes are rendered using pdf's BarcodeWidget when needed.

// New function to compose PdfSpans from the editor's span format
List<pw.TextSpan> _composePdfSpans(String text, List<Map<String, dynamic>> spans, pw.TextStyle baseStyle) {
  if (spans.isEmpty) return [pw.TextSpan(text: text, style: baseStyle)];

  final int n = text.length;
  final List<Map<String, dynamic>> attrs = List.generate(n, (_) => {});

  for (final s in spans) {
    final start = (s['start'] as int).clamp(0, n);
    final end = (s['end'] as int).clamp(0, n);
    for (int i = start; i < end; i++) {
      attrs[i] = {...attrs[i], ...s};
    }
  }

  final List<pw.TextSpan> out = [];
  int i = 0;
  while (i < n) {
    final curAttr = attrs[i];
    int j = i + 1;
    while (j < n && _mapEquals(attrs[j], curAttr)) j++;

    final segment = text.substring(i, j);
    final segColor = _maybeColorFromHex(curAttr['color'] as String?) ?? baseStyle.color;
    final segSize = (curAttr['fontSize'] as num?)?.toDouble() ?? baseStyle.fontSize ?? 12.0;
    final segWeight = (curAttr['bold'] == true) ? pw.FontWeight.bold : baseStyle.fontWeight ?? pw.FontWeight.normal;
    final segStyle = pw.TextStyle(
      font: baseStyle.font,
      color: segColor,
      fontSize: segSize,
      fontWeight: segWeight,
      fontStyle: (curAttr['italic'] == true) ? pw.FontStyle.italic : pw.FontStyle.normal,
      decoration: (curAttr['underline'] == true) ? pw.TextDecoration.underline : null,
      fontFallback: [pw.Font.helvetica()], // Added font fallback
    );
    out.add(pw.TextSpan(text: segment, style: segStyle));
    i = j;
  }
  return out;
}

  // Quill delta conversion logic consolidated in _composePdfSpans; old helper removed.

  // Note: use _maybeColorFromHex(...) and provide fallbacks where necessary.

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width, height),
      build: (context) {
        // Prepare children; optionally draw a full-page background if specified in doc
        final children = <pw.Widget>[];
        final pageBg = _maybeColorFromHex(docInfo['background'] as String? ?? docInfo['backgroundColor'] as String?);
        if (pageBg != null) {
          children.add(
            pw.Positioned(
              left: 0,
              top: 0,
              child: pw.Container(width: width, height: height, color: pageBg),
            ),
          );
        }

        // Determine document-level default text color
        final docDefaultColor = _maybeColorFromHex(docInfo['color'] as String? ?? docInfo['textColor'] as String?);

        children.addAll(canvas.map<pw.Widget>((el) {
          try {
            final m = el is Map ? Map<String, dynamic>.from(el) : <String, dynamic>{};
            final left = (m['left'] as num?)?.toDouble() ?? 0.0;
            final top = (m['top'] as num?)?.toDouble() ?? 0.0;
            final w = (m['width'] as num?)?.toDouble();
            final h = (m['height'] as num?)?.toDouble();
            final type = m['type'] as String? ?? 'text';
            // If element explicitly declares an imagePath, prefer rendering it as an image.
            if (type == 'image' && (m['imagePath'] as String?) != null) {
              final imgPath = m['imagePath'] as String;
              if (imgPath.isNotEmpty && File(imgPath).existsSync()) {
                final bytes = File(imgPath).readAsBytesSync();
                final image = pw.MemoryImage(bytes);
                return pw.Positioned(left: left, top: top, child: pw.Container(width: w, height: h, child: pw.Image(image, fit: pw.BoxFit.cover)));
              }
              return pw.Container();
            }

            if (type == 'qrcode') {
              final qrData = m['text'] as String? ?? ''; // Assuming QR data is stored in 'text' field
              if (qrData.isNotEmpty) {
                // Use pdf's BarcodeWidget to render QR code directly into the PDF
                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: w,
                    height: h,
                    child: pw.Center(
                      child: pw.BarcodeWidget(
                        data: qrData,
                        barcode: pw.Barcode.qrCode(),
                        width: w ?? 100,
                        height: h ?? 100,
                      ),
                    ),
                  ),
                );
              }
              return pw.Container();
            }

            if (type == 'shape') {
              final style = m['style'] as Map<String, dynamic>? ?? {};
              final color = _maybeColorFromHex(style['color'] as String?);
              final shape = m['shape'] as String? ?? 'rectangle';

              if (shape == 'rectangle') {
                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: w,
                    height: h,
                    decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: pw.BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 0),
                    ),
                  ),
                );
              } else if (shape == 'circle') {
                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: w,
                    height: h,
                    decoration: pw.BoxDecoration(
                      color: color,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                );
              } else if (shape == 'line') {
                 return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: w ?? (h != null && h > 1 ? 1 : 100),
                    height: h ?? (w != null && w > 1 ? 1 : 1),
                    color: color ?? PdfColors.black,
                  ),
                );
              }
              return pw.Container();
            }

            // reuse existing element rendering logic
            // element text may be a plain String, a JSON-stringified Quill delta, or a List of ops
            final dynamic textRaw = m['text'];
            String text = '';
            final style = m['style'] as Map<String, dynamic>? ?? <String, dynamic>{};
            final fontSize = (style['fontSize'] as num?)?.toDouble() ?? 12.0;
            final styleColor = _maybeColorFromHex(style['color'] as String?);
            final color = styleColor ?? docDefaultColor ?? PdfColors.black;
            final bgColor = _maybeColorFromHex(style['background'] as String? ?? style['backgroundColor'] as String?);
            final isBold = (style['fontWeight'] as String?) == 'bold' || (style['bold'] as bool?) == true;
            final alignStr = m['align'] as String? ?? 'left';
            pw.TextAlign align = pw.TextAlign.left;
            if (alignStr == 'center') align = pw.TextAlign.center;
            if (alignStr == 'right') align = pw.TextAlign.right;

            final padding = (style['padding'] as num?)?.toDouble() ?? 0.0;
            final borderRadius = (style['borderRadius'] as num?)?.toDouble() ?? 0.0;

            try {
              if (textRaw is String && textRaw.isNotEmpty && File(textRaw).existsSync()) {
                final imgBytes = File(textRaw).readAsBytesSync();
                final image = pw.MemoryImage(imgBytes);
                return pw.Positioned(left: left, top: top, child: pw.Container(width: w, height: h, child: pw.Image(image, fit: pw.BoxFit.contain)));
              }
            } catch (_) {}

            if (type == 'icon') {
              final iconName = m['text'] as String? ?? '';

              if (iconName == 'check_box_outline_blank' || iconName == 'check_box') {
                final style = m['style'] as Map<String, dynamic>? ?? {};
                final color = _maybeColorFromHex(style['color'] as String?) ?? PdfColors.black;
                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: w ?? 14,
                    height: h ?? 14,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: color, width: 1),
                    ),
                    child: iconName == 'check_box'
                        ? pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              pw.Transform.rotate(
                                angle: 0.785398, // 45 degrees
                                child: pw.Container(
                                  width: (w ?? 14) * 0.15,
                                  height: (h ?? 14) * 1.2,
                                  color: color,
                                ),
                              ),
                              pw.Transform.rotate(
                                angle: -0.785398, // -45 degrees
                                child: pw.Container(
                                  width: (w ?? 14) * 0.15,
                                  height: (h ?? 14) * 1.2,
                                  color: color,
                                ),
                              ),
                            ],
                          )
                        : pw.Container(),
                  ),
                );
              }

              String glyph = '';
              // Use simple ASCII fallbacks to avoid missing glyphs in fonts used by the Flutter UI.
              if (iconName == 'verified' || iconName == 'check' || iconName == 'done') glyph = 'OK';
              else if (iconName == 'close' || iconName == 'cancel') glyph = 'X';
              else if (iconName == 'star') glyph = '*';

              return pw.Positioned(
                left: left,
                top: top,
                child: pw.Container(
                  width: w,
                  height: h,
                  padding: pw.EdgeInsets.all(padding),
                  decoration: pw.BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius > 0 ? pw.BorderRadius.circular(borderRadius) : null,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      glyph,
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: fontSize > 0 ? fontSize : (h != null ? h / 2 : 14),
                        color: color,
                        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        fontFallback: [pw.Font.symbol()], // Use symbol font as fallback
                      ),
                    ),
                  ),
                ),
              );
            }

            // If textRaw contains a Quill delta (either a List of ops or a JSON string), render as rich text
            if (textRaw is String && textRaw.isNotEmpty) {
              try {
                final parsed = jsonDecode(textRaw);
                if (parsed is List) {
                  // leave parsed for later rich text handling
                }
              } catch (_) {
                text = textRaw;
              }
            }

            final List<Map<String, dynamic>>? spans = style['spans'] is List ? List.from(style['spans']) : null;

            // Apply rich text only if it's not a placeholder, due to dynamic text length issues
            if (spans != null && spans.isNotEmpty && type != 'placeholder') {
              final baseTextStyle = pw.TextStyle(
                font: baseFont,
                fontSize: fontSize,
                color: color,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              );
              final childrenSpans = _composePdfSpans(textRaw is String ? textRaw : '', spans, baseTextStyle);
              return pw.Positioned(
                left: left,
                top: top,
                child: pw.Container(
                  width: w,
                  height: h,
                  padding: pw.EdgeInsets.all(padding),
                  decoration: pw.BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius > 0 ? pw.BorderRadius.circular(borderRadius) : null,
                  ),
                  child: pw.RichText(text: pw.TextSpan(children: childrenSpans), textAlign: align),
                ),
              );
            }

            // Fallback: if no spans, render plain text (use textRaw if it's a string)
            if (text.isEmpty && textRaw is String) text = textRaw;
            else if (textRaw is String) text = textRaw; // Ensure text is set if it was a plain string

            return pw.Positioned(
              left: left,
              top: top,
              child: pw.Container(
                width: w,
                height: h,
                padding: pw.EdgeInsets.all(padding),
                decoration: pw.BoxDecoration(
                  color: bgColor,
                  borderRadius: borderRadius > 0 ? pw.BorderRadius.circular(borderRadius) : null,
                ),
                child: pw.Text(
                  text,
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: fontSize,
                    color: color,
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontFallback: [pw.Font.helvetica()], // Added font fallback
                  ),
                  textAlign: align,
                ),
              ),
            );
          } catch (_) {
            return pw.Container();
          }
        }).toList());

        return pw.Stack(children: children);
      },
    ),
  );

  return pdf.save();
}
