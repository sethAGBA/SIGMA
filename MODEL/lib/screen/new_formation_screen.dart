import 'dart:io';

import 'package:afroforma/models/formation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class NewFormationScreen extends StatefulWidget {
  @override
  _NewFormationScreenState createState() => _NewFormationScreenState();
}

class _NewFormationScreenState extends State<NewFormationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imagePathController = TextEditingController(); // New controller for manual path
  String? _imagePath;

  Future<void> _pickImage() async {
    print('Attempting to pick image...');
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        setState(() {
          _imagePath = result.files.single.path;
          _imagePathController.text = _imagePath!; // Update manual input field
          print('Image picked: $_imagePath');
        });
      } else {
        print('Image picking cancelled or no file selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nouvelle Formation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: _titleController, labelText: 'Titre'),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: _descriptionController, labelText: 'Description', maxLines: 3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextFormField(controller: _durationController, labelText: 'Durée')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextFormField(controller: _priceController, labelText: 'Prix', keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: _categoryController, labelText: 'Catégorie'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final newFormation = Formation(
                          title: _titleController.text,
                          description: _descriptionController.text,
                          duration: _durationController.text,
                          price: double.parse(_priceController.text),
                          category: _categoryController.text,
                          imageUrl: _imagePathController.text.isNotEmpty ? _imagePathController.text : (_imagePath ?? 'assets/images/placeholder.png'), id: '', level: '',
                        );
                        Navigator.pop(context, newFormation);
                      }
                    },
                    child: const Text('Enregistrer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: _imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover, width: double.infinity),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: Colors.white.withOpacity(0.7), size: 40),
                        const SizedBox(height: 8),
                        Text('Choisir une image', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextFormField(controller: _imagePathController, labelText: 'Ou entrez le chemin de l\'image'),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer $labelText';
        }
        if (keyboardType == TextInputType.number && double.tryParse(value) == null) {
          return 'Veuillez entrer un nombre valide';
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imagePathController.dispose(); // Dispose new controller
    super.dispose();
  }
}


