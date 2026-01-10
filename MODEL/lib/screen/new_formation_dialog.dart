
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/formation.dart';
import '../services/database_service.dart';

class NewFormationDialog extends StatefulWidget {
  final Function(Formation) onFormationCreated;

  const NewFormationDialog({Key? key, required this.onFormationCreated}) : super(key: key);

  @override
  _NewFormationDialogState createState() => _NewFormationDialogState();
}

class _NewFormationDialogState extends State<NewFormationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _prerequisitesController = TextEditingController();
  
  String selectedLevel = 'Débutant';
  bool isActive = true;
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nouvelle Formation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 16),
                      _buildTextField(_titleController, 'Titre'),
                      _buildTextField(_descriptionController, 'Description', maxLines: 3),
                      _buildTextField(_durationController, 'Durée (ex: 3 mois)'),
                      _buildTextField(_priceController, 'Prix', keyboardType: TextInputType.number),
                      _buildTextField(_categoryController, 'Catégorie'),
                      _buildTextField(_objectivesController, 'Objectifs', maxLines: 3),
                      _buildTextField(_prerequisitesController, 'Prérequis', maxLines: 3),
                      const SizedBox(height: 16),
                      _buildLevelDropdown(),
                      const SizedBox(height: 16),
                      _buildStatusSwitch(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('Créer la Formation' ,style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Ce champ ne peut pas être vide';
          }
          if (keyboardType == TextInputType.number && double.tryParse(value) == null) {
            return 'Veuillez entrer un nombre valide';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLevelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLevel,
          onChanged: (String? newValue) {
            setState(() {
              selectedLevel = newValue!;
            });
          },
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF1E293B),
          items: <String>['Débutant', 'Intermédiaire', 'Avancé']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusSwitch() {
    return SwitchListTile(
      title: const Text('Formation Active', style: TextStyle(color: Colors.white)),
      value: isActive,
      onChanged: (bool value) {
        setState(() {
          isActive = value;
        });
      },
      activeColor: const Color(0xFF10B981),
    );
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
      });
    } else {
      // User canceled the picker
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sélectionner une image',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: Colors.white.withOpacity(0.7), size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Choisir une image',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newFormation = Formation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        duration: _durationController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        imageUrl: _selectedImage?.path ?? '', // Placeholder
        category: _categoryController.text,
        level: selectedLevel,
        isActive: isActive,
        objectives: _objectivesController.text,
        prerequisites: _prerequisitesController.text,
      );
      // show progress
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      DatabaseService().saveFormationTransaction(newFormation).then((_) {
        Navigator.pop(context); // remove progress
        widget.onFormationCreated(newFormation);
        Navigator.pop(context);
      });
    }
  }
}
