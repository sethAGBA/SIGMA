// lib/widgets/dialogs/group_form_dialog.dart

import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/groupe_solidaire_model.dart';

class GroupFormDialog extends StatefulWidget {
  final GroupeSolidaire? group;

  const GroupFormDialog({super.key, this.group});

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late GroupStatus _status;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.group?.nom);
    _codeController = TextEditingController(text: widget.group?.code);
    _descController = TextEditingController(text: widget.group?.description);
    _status = widget.group?.statut ?? GroupStatus.active;

    if (widget.group == null) {
      // Générer un code par défaut
      _codeController.text =
          'GR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final group = GroupeSolidaire(
        id: widget.group?.id,
        code: _codeController.text,
        nom: _nomController.text,
        description: _descController.text,
        statut: _status,
        dateCreation: widget.group?.dateCreation ?? DateTime.now(),
        responsableId: widget.group?.responsableId,
        tresorierId: widget.group?.tresorierId,
      );

      if (widget.group == null) {
        await DatabaseService().insertGroupe(group);
      } else {
        await DatabaseService().updateGroupe(group);
      }

      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
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
                    widget.group == null ? 'Nouveau Groupe' : 'Modifier Groupe',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe',
                  prefixIcon: Icon(Icons.group_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code de groupe',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  prefixIcon: Icon(Icons.description_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Enregistrer'),
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
