import 'package:flutter/material.dart';
import 'dart:io'; // Keep this for File operations if needed by other helpers

Widget buildSection(String title, IconData icon, Widget child) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 24), // increased breathing room between icon and title
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ]),
      ),
      const SizedBox(height: 20), // larger gap before content
      child
    ]),
  );
}

Widget buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
  return TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)), prefixIcon: Icon(icon, color: Colors.white54), filled: true, fillColor: Colors.black.withOpacity(0.15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)));
}

Widget buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged, IconData icon) {
  return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, onChanged: onChanged, isExpanded: true, dropdownColor: const Color(0xFF1E293B), items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white)))).toList(), hint: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7))), icon: Icon(icon, color: Colors.white54), style: const TextStyle(color: Colors.white))));
}

Widget buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
  return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, color: Colors.white), label: Text(label, style: const TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
}
