
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/formation.dart';

class FormationListItem extends StatelessWidget {
  final Formation formation;

  const FormationListItem({required this.formation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget imageWidget;
    if (formation.imageUrl.isEmpty || formation.imageUrl.startsWith('assets/')) {
      imageWidget = Center(
        child: Icon(
          Icons.school,
          color: Colors.white.withOpacity(0.5),
          size: 40,
        ),
      );
    } else {
      final file = File(formation.imageUrl);
      if (file.existsSync()) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(file, fit: BoxFit.cover, width: 100, height: 100),
        );
      } else {
        imageWidget = Center(
          child: Icon(
            Icons.school,
            color: Colors.white.withOpacity(0.5),
            size: 40,
          ),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Image Display
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.grey.withOpacity(0.1),
              ),
              child: imageWidget,
            ),
            const SizedBox(width: 16.0),
            // Formation Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formation.title,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    formation.category,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16.0, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 4.0),
                      Text(formation.duration, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      const SizedBox(width: 16.0),
                      Icon(Icons.monetization_on, size: 16.0, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 4.0),
                      Text('${formation.price} FCFA', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            // Action Buttons
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Modifier'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.archive, size: 16),
                  label: Text('Archiver'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey.withOpacity(0.5),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
