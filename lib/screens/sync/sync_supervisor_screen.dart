// lib/screens/sync/sync_supervisor_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sync_queue_entry.dart';
import '../../models/sync_conflict_model.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/connectivity_monitor.dart';
import '../../widgets/dialogs/conflict_resolution_dialog.dart';

class SyncSupervisorScreen extends StatefulWidget {
  const SyncSupervisorScreen({super.key});

  @override
  State<SyncSupervisorScreen> createState() => _SyncSupervisorScreenState();
}

class _SyncSupervisorScreenState extends State<SyncSupervisorScreen> {
  List<SyncQueueEntry> _entries = [];
  List<SyncConflict> _conflicts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    ConnectivityMonitor().statusNotifier.addListener(_onStatusChange);
  }

  @override
  void dispose() {
    ConnectivityMonitor().statusNotifier.removeListener(_onStatusChange);
    super.dispose();
  }

  void _onStatusChange() => _loadEntries();

  Future<void> _loadEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final entries = await SyncService().getAllEntries();
      final conflicts = await SyncService().getPendingConflicts();
      if (mounted) {
        setState(() {
          _entries = entries;
          _conflicts = conflicts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _retryEntry(String id) async {
    await SyncService().retryEntry(id);
    await _loadEntries();
    if (await SyncService().isOnline) {
      await SyncService().flushPendingOperations();
      await _loadEntries();
    }
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Cette opération sera définitivement supprimée de la file de synchronisation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SyncService().deleteEntry(id);
      await _loadEntries();
    }
  }

  Future<void> _flushAll() async {
    final online = await SyncService().isOnline;
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serveur indisponible — synchronisation impossible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await SyncService().flushPendingOperations();
    await _loadEntries();
  }

  // ── Helpers de couleur / label ────────────────────────────────────────────

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
        return Colors.blue;
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'conflict':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'in_progress':
        return 'En cours';
      case 'success':
        return 'Succès';
      case 'failed':
        return 'Échoué';
      case 'conflict':
        return 'Conflit';
      default:
        return status;
    }
  }

  // ── Construction des cartes ───────────────────────────────────────────────

  Widget _buildEntryCard(SyncQueueEntry entry) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormatter.format(entry.createdAt);
    final methodColor = _methodColor(entry.method);
    final priorityColor = _priorityColor(entry.priority);
    final statusColor = _statusColor(entry.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne supérieure : méthode + chemin + statut ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chip méthode HTTP
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: methodColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.method.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Chemin en gras
                Expanded(
                  child: Text(
                    entry.path,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Chip statut
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    _statusLabel(entry.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Ligne info : date, priorité, tentatives ───────────────────
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                // Date création
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                // Priorité
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, size: 14, color: priorityColor),
                    const SizedBox(width: 3),
                    Text(
                      'Priorité ${entry.priority}',
                      style: TextStyle(
                        fontSize: 12,
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Tentatives
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      '${entry.attemptCount}/3 tentatives',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Zone d'erreur (si lastError != null) ──────────────────────
            if (entry.lastError != null) ...[
              _ErrorExpansion(errorMessage: entry.lastError!),
              const SizedBox(height: 8),
            ],

            // ── Corps JSON (ExpansionTile) ─────────────────────────────────
            if (entry.body != null) ...[
              _BodyExpansion(body: entry.body!),
              const SizedBox(height: 4),
            ],

            // ── Boutons d'action ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry.status == 'failed')
                  IconButton(
                    tooltip: 'Réessayer',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _retryEntry(entry.id),
                  ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () => _deleteEntry(entry.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveConflict(SyncConflict conflict) async {
    final keepLocal = await showDialog<bool>(
      context: context,
      builder: (_) => ConflictResolutionDialog(conflict: conflict),
    );
    if (keepLocal == null) return;
    await SyncService().resolveConflict(conflict.id, keepLocal: keepLocal);
    await _loadEntries();
  }

  Widget _buildConflictCard(SyncConflict conflict) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text('${conflict.entityType} ${conflict.entityId ?? ''}'),
        subtitle: Text(
          'Local: ${conflict.localUpdatedAt?.toIso8601String() ?? '—'} | '
          'Serveur: ${conflict.serverUpdatedAt?.toIso8601String() ?? '—'}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: TextButton(
          onPressed: () => _resolveConflict(conflict),
          child: const Text('Résoudre'),
        ),
      ),
    );
  }

  // ── État vide ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Aucune opération en attente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervision de synchronisation'),
        actions: [
          IconButton(
            tooltip: 'Tout synchroniser',
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _flushAll,
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadEntries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_entries.isEmpty && _conflicts.isEmpty)
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (_conflicts.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Conflits (${_conflicts.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ..._conflicts.map(_buildConflictCard),
                      const Divider(height: 24),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(
                          'File de synchronisation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    ..._entries.map(_buildEntryCard),
                  ],
                ),
    );
  }
}

// ── Widgets auxiliaires ───────────────────────────────────────────────────────

/// Zone rouge expandable affichant le dernier message d'erreur.
class _ErrorExpansion extends StatefulWidget {
  final String errorMessage;
  const _ErrorExpansion({required this.errorMessage});

  @override
  State<_ErrorExpansion> createState() => _ErrorExpansionState();
}

class _ErrorExpansionState extends State<_ErrorExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Dernière erreur',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  widget.errorMessage,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ExpansionTile affichant le corps JSON formaté de la requête.
class _BodyExpansion extends StatelessWidget {
  final Map<String, dynamic> body;
  const _BodyExpansion({required this.body});

  @override
  Widget build(BuildContext context) {
    final formatted =
        const JsonEncoder.withIndent('  ').convert(body);

    return Theme(
      // Supprime le séparateur par défaut de ExpansionTile
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(Icons.code, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              'Voir la requête',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              formatted,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
