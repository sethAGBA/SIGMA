import '../../models/accounting_account_model.dart';

class PlanParser {
  static List<AccountingAccount> parse(String content) {
    final lines = content.trim().replaceAll('\uFEFF', '').split('\n');
    final accounts = <AccountingAccount>[];
    final existingCodes = <String>{}; // To track codes for parent detection

    // First pass: collect all codes to help with parent resolution if needed,
    // though the provided CSV is ordered, so we can likely do it in one pass or assume parents exist.
    // The original parser did a heuristic look-back.

    for (final line in lines) {
      final parts = line.split(';');
      if (parts.length >= 2) {
        final code = parts[0].trim();
        final title = parts[1].trim();

        if (code.isEmpty) continue;
        existingCodes.add(code);

        String? parentId;
        if (code.length > 1) {
          // Try to find the immediate parent (e.g., for 101, parent is 10. For 10, parent is 1)
          // Heuristic: remove last digit until we find a match, or strict substring?
          // Syscohada is strictly hierarchical usually.
          for (int i = code.length - 1; i >= 1; i--) {
            final potentialParent = code.substring(0, i);
            // We accept single digit parents (Classes) even if they aren't explicitly in the 'existingCodes' set yet (if unordered),
            // but usually Classes are at the top.
            // Given the CSV structure, parents usually come before children.
            if (existingCodes.contains(potentialParent) ||
                potentialParent.length == 1) {
              parentId = potentialParent;
              break;
            }
          }
        }

        // Root classes (1 digit) have no parent in this scheme, or parent is root?
        // We'll leave parentId null for Class roots (1, 2, 3...)

        final int classe = int.tryParse(code[0]) ?? 0;
        final String type = _getTypeFromClass(classe);
        final bool isTitle =
            code.length <=
            2; // Heuristic: Classes and 2-digit groups are titles

        accounts.add(
          AccountingAccount(
            numero: code,
            libelle: title,
            classe: classe,
            type: type,
            parentAccount: parentId,
            isTitle: isTitle,
          ),
        );
      }
    }
    return accounts;
  }

  static String _getTypeFromClass(int classe) {
    switch (classe) {
      case 1:
        return 'Capitaux';
      case 2:
      case 3:
        return 'Actif';
      case 4:
        return 'Mixte'; // Tiers can be Actif or Passif
      case 5:
        return 'Mixte'; // Trésorerie
      case 6:
        return 'Charge';
      case 7:
        return 'Produit';
      case 8:
        return 'HAO';
      default:
        return 'Divers';
    }
  }
}
