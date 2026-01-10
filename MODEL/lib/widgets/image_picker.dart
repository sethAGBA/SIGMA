import 'dart:io';
import 'package:flutter/material.dart';

class ImagePickerWidget extends StatelessWidget {
  final String? imagePath;
  final TextEditingController imagePathController;
  final VoidCallback onPickImage;

  const ImagePickerWidget({required this.imagePath, required this.imagePathController, required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(imagePath!), fit: BoxFit.cover, width: double.infinity),
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
        TextFormField(
          controller: imagePathController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Ou entrez le chemin de l\'image',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
          ),
          validator: (value) => null, // No validation for manual path
        ),
      ],
    );
  }
}