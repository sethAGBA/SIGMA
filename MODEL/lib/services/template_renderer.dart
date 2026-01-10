import 'dart:convert';

/// Simple placeholder renderer: replaces {{key}} with value.toString() from data map.
String renderTemplateString(String template, Map<String, dynamic> data) {
  if (template.isEmpty) return template;
  String out = template;

  // 1. Handle #each blocks
  final eachRegex = RegExp(r'{{#each (\w+)}}(.*?){{\/each}}', dotAll: true);
  out = out.replaceAllMapped(eachRegex, (match) {
    final listKey = match.group(1);
    final blockContent = match.group(2) ?? '';
    if (listKey == null || !data.containsKey(listKey) || data[listKey] is! List) {
      return ''; // Key not found or not a list, remove block
    }

    final List<dynamic> list = data[listKey];
    final buffer = StringBuffer();

    for (final item in list) {
      if (item is Map<String, dynamic>) {
        String renderedBlock = blockContent;
        // Replace {{this.key}} placeholders
        item.forEach((key, value) {
          renderedBlock = renderedBlock.replaceAll('{{this.${key}}}', value?.toString() ?? '');
        });
        buffer.writeln(renderedBlock);
      }
    }
    return buffer.toString();
  });

  // 2. Handle simple {{key}} replacements
  final flat = <String, String>{};
  void flatten(String prefix, dynamic value) {
    if (value is Map<String, dynamic>) {
      value.forEach((k, v) => flatten(prefix.isEmpty ? k : '$prefix.$k', v));
    } else {
      flat[prefix] = value?.toString() ?? '';
    }
  }
  data.forEach((k, v) => flatten(k, v));

  flat.forEach((k, v) {
    out = out.replaceAll('{{${k}}}', v);
  });

  data.forEach((k, v) {
    if (v is! List && v is! Map) {
      out = out.replaceAll('{{${k}}}', v?.toString() ?? '');
    }
  });

  return out;
}

/// Render a JSON content that may be a Quill delta (List ops) or a canvas Map.
dynamic renderTemplateJsonContent(dynamic content, Map<String, dynamic> data) {
  if (content == null) return content;
  if (content is String) {
    try {
      final parsed = jsonDecode(content);
      return renderTemplateJsonContent(parsed, data);
    } catch (_) {
      // Not a JSON string, just a regular string. Render it.
      return renderTemplateString(content, data);
    }
  }

  if (content is List) {
    return content.map((item) => renderTemplateJsonContent(item, data)).toList();
  }

  if (content is Map) {
    final Map<String, dynamic> out = {};
    content.forEach((k, v) {
      // Specifically preserve the 'doc' object without rendering its internals,
      // as it contains formatting settings, not placeholders.
      if (k == 'doc') {
        out[k] = v;
      } else if (v is String) {
        out[k] = renderTemplateString(v, data);
      } else if (v is Map || v is List) {
        out[k] = renderTemplateJsonContent(v, data);
      } else {
        out[k] = v;
      }
    });
    return out;
  }
  return content;
}
