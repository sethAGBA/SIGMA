import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_model.dart';
import '../../models/agency_model.dart';
import '../../models/accounting_account_model.dart';
import '../../core/services/database_service.dart';

class AgentFormDialog extends StatefulWidget {
  final Agent? agent;

  const AgentFormDialog({super.key, this.agent});

  @override
  State<AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<AgentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  AgentRole? _selectedRole;
  String? _selectedAgencyId;
  AccountingAccount? _selectedAccount;
  bool _isSaving = false;

  List<Agency> _agencies = [];
  bool _isLoadingAgencies = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.agent?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.agent?.lastName ?? '',
    );
    _emailController = TextEditingController(text: widget.agent?.email ?? '');
    _phoneController = TextEditingController(text: widget.agent?.phone ?? '');
    _selectedRole = widget.agent?.role;
    _selectedAgencyId = widget.agent?.agencyId;

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final agencies = await DatabaseService().getAgencies();
      AccountingAccount? account;

      if (widget.agent?.associatedAccountId != null) {
        account = await DatabaseService().getAccountByNumber(
          widget.agent!.associatedAccountId!,
        );
      }

      if (mounted) {
        setState(() {
          _agencies = agencies;
          _isLoadingAgencies = false;
          _selectedAccount = account;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAgencies = false);
      }
      print('Error loading agent data: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAgent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final agentId =
            widget.agent?.id ??
            DateTime.now().millisecondsSinceEpoch.toString();

        final agent = Agent(
          id: agentId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole!,
          agencyId: _selectedAgencyId!,
          isActive: widget.agent?.isActive ?? true, // Default to true for new
          hiredDate: widget.agent?.hiredDate ?? DateTime.now(),
          photoUrl: widget.agent?.photoUrl,
          associatedAccountId: _selectedAccount?.numero,
        );

        if (widget.agent == null) {
          await DatabaseService().insertAgent(agent);
        } else {
          await DatabaseService().updateAgent(agent);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.agent == null
                    ? 'Agent créé avec succès'
                    : 'Agent modifié avec succès',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to signal refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'enregistrement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.agent == null ? 'Nouvel Agent' : 'Modifier Agent',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v?.contains('@') == false ? 'Email invalide' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<AgentRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  border: OutlineInputBorder(),
                ),
                items: AgentRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedRole = val),
                validator: (v) => v == null ? 'Requis' : null,
              ),

              const SizedBox(height: 16),

              if (_isLoadingAgencies)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedAgencyId,
                  decoration: const InputDecoration(
                    labelText: 'Agence d\'affectation',
                    border: OutlineInputBorder(),
                  ),
                  items: _agencies
                      .map(
                        (agency) => DropdownMenuItem(
                          value: agency.id,
                          child: Text(agency.name),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAgencyId = val;
                      if (val != null) {
                        // _selectedAgency logic removed as unused
                      }
                    });
                  },
                  validator: (v) => v == null ? 'Requis' : null,
                ),

              const SizedBox(height: 16),

              // Accounting Account Autocomplete
              Autocomplete<AccountingAccount>(
                initialValue: TextEditingValue(
                  text: _selectedAccount != null
                      ? '${_selectedAccount!.numero} - ${_selectedAccount!.libelle}'
                      : '',
                ),
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<AccountingAccount>.empty();
                  }
                  return await DatabaseService().searchAccountingAccounts(
                    textEditingValue.text,
                    classPrefix: '42', // Filter for Personnel/Tiers
                  );
                },
                displayStringForOption: (AccountingAccount option) =>
                    '${option.numero} - ${option.libelle}',
                onSelected: (AccountingAccount selection) {
                  setState(() {
                    _selectedAccount = selection;
                  });
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      // If we have an initial account but the controller is empty (first load issue with async),
                      // update the controller.
                      if (_selectedAccount != null &&
                          textEditingController.text.isEmpty &&
                          !focusNode.hasFocus) {
                        textEditingController.text =
                            '${_selectedAccount!.numero} - ${_selectedAccount!.libelle}';
                      }

                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Compte Comptable Associé (Classe 42)',
                          border: OutlineInputBorder(),
                          helperText: 'Recherchez par nom ou numéro (ex: 4211)',
                          suffixIcon: Icon(Icons.search),
                        ),
                      );
                    },
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAgent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.agent == null
                              ? 'Créer l\'agent'
                              : 'Enregistrer les modifications',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
