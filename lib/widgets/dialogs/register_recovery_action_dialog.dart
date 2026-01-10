import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/recovery_action_model.dart';
import '../../models/agent_model.dart';

class RegisterRecoveryActionDialog extends StatefulWidget {
  final int loanId;
  final String clientName;
  final String numeroPret;
  final VoidCallback onActionSaved;

  const RegisterRecoveryActionDialog({
    super.key,
    required this.loanId,
    required this.clientName,
    required this.numeroPret,
    required this.onActionSaved,
  });

  @override
  State<RegisterRecoveryActionDialog> createState() =>
      _RegisterRecoveryActionDialogState();
}

class _RegisterRecoveryActionDialogState
    extends State<RegisterRecoveryActionDialog> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  RecoveryActionType _selectedType = RecoveryActionType.call;
  final _descriptionController = TextEditingController();
  final _resultController = TextEditingController();

  String? _selectedAgentId;
  List<Agent> _agents = [];
  bool _isLoadingAgents = true;
  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    try {
      final agents = await _db.getAgents();
      if (mounted) {
        setState(() {
          _agents = agents;
          if (agents.isNotEmpty) {
            _selectedAgentId = agents.first.id;
          }
          _isLoadingAgents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAgents = false);
      }
    }
  }

  Future<void> _saveAction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAgentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un agent')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final agent = _agents.firstWhere((a) => a.id == _selectedAgentId);
      final action = RecoveryAction(
        loanId: widget.loanId,
        date: _selectedDate,
        type: _selectedType,
        description: _descriptionController.text,
        agentName: agent.fullName,
        result: _resultController.text,
      );

      await _db.saveRecoveryAction(action);

      if (mounted) {
        widget.onActionSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action enregistrée avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_edu_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nouvelle action de recouvrement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Client: ${widget.clientName} | Prêt: ${widget.numeroPret}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<RecoveryActionType>(
                      value: _selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type d\'action',
                        prefixIcon: Icon(Icons.category_outlined),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: RecoveryActionType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoadingAgents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedAgentId,
                  decoration: const InputDecoration(
                    labelText: 'Agent responsable',
                    prefixIcon: Icon(Icons.person_outline),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _agents.map((agent) {
                    return DropdownMenuItem(
                      value: agent.id,
                      child: Text(
                        agent.fullName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAgentId = val),
                  validator: (val) =>
                      val == null ? 'Veuillez sélectionner un agent' : null,
                ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Détails de l\'intervention',
                  hintText: 'Ex: Appel effectué pour relancer le client...',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _resultController,
                decoration: const InputDecoration(
                  labelText: 'Résultat de l\'action',
                  hintText: 'Ex: Promesse de paiement le 20/01',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Champ requis' : null,
                style: const TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer l\'action'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
