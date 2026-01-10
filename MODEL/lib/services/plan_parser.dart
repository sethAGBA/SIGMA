import 'dart:convert';

/// Parse the plan comptable text into a list of account maps.
Map<String, dynamic> parsePlanComptable(String content) {
  final lines = content.trim().replaceAll('\uFEFF', '').split('\n');
  final accounts = <Map<String, dynamic>>[];

  for (final line in lines) {
    final parts = line.split(';');
    if (parts.length >= 2) {
      final code = parts[0].trim();
      final title = parts[1].trim();
      String? parentId;
      if (code.length > 1) {
        for (int i = code.length - 1; i >= 1; i--) {
          final potentialParentCode = code.substring(0, i);
          // heuristic: top-level single digit classes are allowed
          if (accounts.any((a) => a['code'] == potentialParentCode) || (potentialParentCode.length == 1 && int.tryParse(potentialParentCode) != null)) {
            parentId = potentialParentCode;
            break;
          }
        }
      }
      accounts.add({'id': code, 'code': code, 'title': title, 'parentId': parentId});
    }
  }

  return {'accounts': accounts, 'count': accounts.length};
}
