// lib/widgets/dialogs/conflict_resolution_dialog.dart

import 'package:flutter/material.dart';
import '../../models/sync_conflict_model.dart';

class ConflictResolutionDialog extends StatelessWidget {
  final SyncConflict conflict;

  const ConflictResolutionDialog({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Conflit — ${conflict.entityType}'),
      content: SizedBox(
        width: 520,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPayloadColumn('Version locale', conflict.localPayload)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPayloadColumn('Version serveur', conflict.serverPayload),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Annuler'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Garder serveur'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Garder local'),
        ),
      ],
    );
  }

  Widget _buildPayloadColumn(String title, Map<String, dynamic> payload) {
    final keys = payload.keys.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...keys.map(
          (k) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('$k : ${payload[k]}', style: const TextStyle(fontSize: 12)),
          ),
        ),
        if (payload.isEmpty)
          const Text('(vide)', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
