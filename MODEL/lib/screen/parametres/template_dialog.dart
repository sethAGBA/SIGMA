import 'package:flutter/material.dart';
import 'models.dart';
import '../../services/database_service.dart';

class TemplateDialog extends StatefulWidget {
  final DocumentTemplate? template;

  const TemplateDialog({Key? key, this.template}) : super(key: key);

  @override
  _TemplateDialogState createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<TemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _contentController = TextEditingController(text: widget.template?.content ?? '');
  _selectedType = widget.template?.type ?? 'facture';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (_formKey.currentState!.validate()) {
      final template = DocumentTemplate(
        id: widget.template?.id ?? 'template_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        type: _selectedType!,
        content: _contentController.text,
        lastModified: DateTime.now(),
      );
      await DatabaseService().saveDocumentTemplate(template);
  Navigator.of(context).pop(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.template == null ? 'Nouveau Modèle' : 'Modifier le Modèle', style: const TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nom du modèle', labelStyle: TextStyle(color: Colors.white70)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                dropdownColor: const Color(0xFF334155),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Type de modèle', labelStyle: TextStyle(color: Colors.white70)),
                // Ensure that if the template has a custom type (eg. 'inscription')
                // not in the default choices, we still provide it as a single
                // DropdownMenuItem. This avoids the DropdownButton assertion that
                // requires exactly one matching item for the current value.
                items: (() {
                  final base = ['facture', 'recu', 'attestation', 'canvas'];
                  final types = List<String>.from(base);
                  if (_selectedType != null && !types.contains(_selectedType)) {
                    types.add(_selectedType!);
                  }
                  return types.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList();
                })(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                validator: (value) => value == null ? 'Veuillez sélectionner un type' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Contenu du modèle', labelStyle: TextStyle(color: Colors.white70)),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un contenu';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saveTemplate,
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }
}
