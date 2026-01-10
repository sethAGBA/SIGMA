import 'package:flutter/material.dart';
import '../../core/services/accounting_service.dart';
import '../../models/accounting_account_model.dart';

class PlanComptablePage extends StatefulWidget {
  const PlanComptablePage({super.key});

  @override
  State<PlanComptablePage> createState() => _PlanComptablePageState();
}

class _PlanComptablePageState extends State<PlanComptablePage> {
  final AccountingService _accountingService = AccountingService();
  List<AccountingAccount> _accounts = [];
  bool _isLoading = true;
  String? _selectedAccountCode;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final accounts = await _accountingService.getAccountingAccounts();
    // Sort by numero to ensure correct order
    accounts.sort((a, b) => a.numero.compareTo(b.numero));
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF0B1220) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.withOpacity(0.2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Plan Comptable',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: secondaryTextColor),
            onPressed: _loadAccounts,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blueAccent),
            onPressed: () => _showAccountDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Rechercher un compte (numero ou libellé)...',
                hintStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: secondaryTextColor),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tree View
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.only(
                            left: 16,
                            bottom: 16,
                            right: 8,
                          ),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: _buildAccountsTree(
                            textColor,
                            secondaryTextColor,
                          ),
                        ),
                      ),

                      // Detail Panel (Right Side for Desktop/Tablet)
                      // Only show on wider screens or if needed. For now keeping 2-pane for desktop feel.
                      Expanded(
                        flex: 4,
                        child: Container(
                          margin: const EdgeInsets.only(
                            right: 16,
                            bottom: 16,
                            left: 8,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: _buildDetailPanel(
                            textColor,
                            secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTree(Color textColor, Color secondaryTextColor) {
    List<AccountingAccount> displayedAccounts = _accounts;

    // Filter if search query exists
    if (_searchQuery.isNotEmpty) {
      displayedAccounts = _accounts.where((a) {
        return a.numero.toLowerCase().contains(_searchQuery) ||
            a.libelle.toLowerCase().contains(_searchQuery);
      }).toList();

      if (displayedAccounts.isEmpty) {
        return Center(
          child: Text(
            "Aucun compte trouvé",
            style: TextStyle(color: secondaryTextColor),
          ),
        );
      }

      // If searching, show flat list for better UX
      return ListView.builder(
        itemCount: displayedAccounts.length,
        itemBuilder: (context, index) {
          final account = displayedAccounts[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              '${account.numero} - ${account.libelle}',
              style: TextStyle(color: textColor),
            ),
            onTap: () => setState(() => _selectedAccountCode = account.numero),
            selected: _selectedAccountCode == account.numero,
            selectedTileColor: Colors.blueAccent.withOpacity(0.1),
          );
        },
      );
    }

    // Identify roots: Class titles (length 1).
    // Also include orphans (accounts with no parent in the list) to ensure nothing is hidden.
    // Optimization: Create a set of all account IDs (numeros) for fast lookup.
    final allNumeros = displayedAccounts.map((e) => e.numero).toSet();

    final roots = displayedAccounts.where((a) {
      bool isClass = a.numero.length == 1;
      bool hasNoParent = a.parentAccount == null || a.parentAccount!.isEmpty;
      bool parentDoesNotExist =
          a.parentAccount != null && !allNumeros.contains(a.parentAccount);

      return isClass || hasNoParent || parentDoesNotExist;
    }).toList();

    if (roots.isEmpty && displayedAccounts.isNotEmpty) {
      // Fallback: if logic fails, show top level by length
      return ListView.builder(
        itemCount: displayedAccounts.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(
            displayedAccounts[i].libelle,
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }

    return ListView(
      children: roots
          .map(
            (root) => _AccountNode(
              account: root,
              allAccounts: displayedAccounts,
              onSelect: (a) => setState(() => _selectedAccountCode = a.numero),
              selectedCode: _selectedAccountCode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
          )
          .toList(),
    );
  }

  Future<void> _deleteAccount(AccountingAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le compte ${account.numero} - ${account.libelle} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && account.id != null) {
      await _accountingService.deleteAccount(account.id!);
      setState(() {
        _selectedAccountCode = null;
      });
      _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Compte supprimé')));
      }
    }
  }

  void _showAccountDialog({AccountingAccount? account}) {
    final isEditing = account != null;
    final numeroController = TextEditingController(text: account?.numero);
    final libelleController = TextEditingController(text: account?.libelle);
    String type = account?.type ?? 'Actif';
    String? parentAccount = account?.parentAccount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Modifier le compte' : 'Nouveau compte'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: numeroController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro (Code)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: libelleController,
                    decoration: const InputDecoration(
                      labelText: 'Libellé (Nom)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Actif', child: Text('Actif')),
                      DropdownMenuItem(value: 'Passif', child: Text('Passif')),
                      DropdownMenuItem(value: 'Charge', child: Text('Charge')),
                      DropdownMenuItem(
                        value: 'Produit',
                        child: Text('Produit'),
                      ),
                      DropdownMenuItem(
                        value: 'Capitaux',
                        child: Text('Capitaux'),
                      ),
                    ],
                    onChanged: (val) => setStateDialog(() => type = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Compte Parent (Optionnel)',
                      hintText: 'Ex: 10',
                    ),
                    controller: TextEditingController(text: parentAccount),
                    onChanged: (val) =>
                        parentAccount = val.isEmpty ? null : val,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (numeroController.text.isEmpty ||
                      libelleController.text.isEmpty) {
                    return;
                  }

                  final newAccount = AccountingAccount(
                    id: account?.id,
                    numero: numeroController.text.trim(),
                    libelle: libelleController.text.trim(),
                    classe:
                        int.tryParse(
                          numeroController.text.trim().substring(0, 1),
                        ) ??
                        0,
                    type: type,
                    parentAccount: parentAccount,
                    isTitle: numeroController.text.trim().length <= 2,
                  );

                  try {
                    if (isEditing) {
                      await _accountingService.updateAccount(newAccount);
                    } else {
                      await _accountingService.addAccount(newAccount);
                    }
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      _loadAccounts();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Erreur'),
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Enregistrer' : 'Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailPanel(Color textColor, Color secondaryTextColor) {
    if (_selectedAccountCode == null) {
      return Center(
        child: Text(
          'Sélectionnez un compte pour voir les détails',
          style: TextStyle(color: secondaryTextColor),
        ),
      );
    }

    final account = _accounts.firstWhere(
      (a) => a.numero == _selectedAccountCode,
      orElse: () => _accounts.first, // Fallback
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance,
                color: Colors.blueAccent,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.numero,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Classe ${account.classe}',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Divider(color: secondaryTextColor.withOpacity(0.2)),
        const SizedBox(height: 16),
        Text(account.libelle, style: TextStyle(fontSize: 18, color: textColor)),
        const SizedBox(height: 24),
        _buildInfoRow('Type', account.type, textColor, secondaryTextColor),
        _buildInfoRow(
          'Parent',
          account.parentAccount ?? 'Aucun (Racine)',
          textColor,
          secondaryTextColor,
        ),
        _buildInfoRow(
          'Titre',
          account.isTitle ? 'Oui' : 'Non',
          textColor,
          secondaryTextColor,
        ),

        const Spacer(),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _showAccountDialog(account: account),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () => _deleteAccount(account),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryTextColor)),
          Text(
            value,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _AccountNode extends StatefulWidget {
  final AccountingAccount account;
  final List<AccountingAccount> allAccounts;
  final Function(AccountingAccount) onSelect;
  final String? selectedCode;
  final Color textColor;
  final Color secondaryTextColor;

  const _AccountNode({
    required this.account,
    required this.allAccounts,
    required this.onSelect,
    required this.selectedCode,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  State<_AccountNode> createState() => _AccountNodeState();
}

class _AccountNodeState extends State<_AccountNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Find children
    final children = widget.allAccounts
        .where((a) => a.parentAccount == widget.account.numero)
        .toList();

    final hasChildren = children.isNotEmpty;
    final isSelected = widget.selectedCode == widget.account.numero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          selected: isSelected,
          selectedTileColor: Colors.blueAccent.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          leading: hasChildren
              ? IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    color: widget.secondaryTextColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                )
              : const SizedBox(width: 40), // Indent for leaves
          title: Text(
            '${widget.account.numero} - ${widget.account.libelle}',
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : widget.textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            widget.onSelect(widget.account);
            if (hasChildren && !_expanded) {
              setState(() => _expanded = true);
            }
          },
        ),
        if (_expanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: children
                  .map(
                    (child) => _AccountNode(
                      account: child,
                      allAccounts: widget.allAccounts,
                      onSelect: widget.onSelect,
                      selectedCode: widget.selectedCode,
                      textColor: widget.textColor,
                      secondaryTextColor: widget.secondaryTextColor,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
