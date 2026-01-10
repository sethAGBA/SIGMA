import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/audit_log_model.dart';
import 'package:intl/intl.dart';

class SecurityAuditPage extends StatefulWidget {
  const SecurityAuditPage({super.key});

  @override
  State<SecurityAuditPage> createState() => _SecurityAuditPageState();
}

class _SecurityAuditPageState extends State<SecurityAuditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingFromDb = true;
  List<AuditLog> _logs = [];

  // Security settings (mock for UI)
  int _sessionTimeout = 30;
  bool _twoFactorEnabled = false;
  int _failedAttemptsLocked = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingFromDb = true);
    try {
      final logs = await DatabaseService().getAuditLogs();
      setState(() {
        _logs = logs;
        _isLoadingFromDb = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      setState(() => _isLoadingFromDb = false);
    }
  }

  Future<void> _exportDatabase() async {
    try {
      // For MacOS/iOS/Android, the DB is usually in certain folders.
      // sqflite default path is often databases/sigma.db
      // Here we assume we can get it.

      // Since we are an agent, we know the DB path usually used in sigma is 'sigma.db'
      // We'll try to find it in the app support or documents dir.
      final directory = await getApplicationSupportDirectory();
      final dbPath = "${directory.path}/sigma.db";
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final backupPath =
              "${downloadsDir.path}/sigma_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db";
          await dbFile.copy(backupPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sauvegarde réussie ! Fichier copié dans Téléchargements : $backupPath',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          // Log the action
          await DatabaseService().insertAuditLog(
            AuditLog(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              username: 'Admin', // Static for now
              action: 'EXPORT_DB',
              details:
                  'Exportation manuelle de la base de données vers Téléchargements',
              timestamp: DateTime.now(),
              severity: AuditSeverity.medium,
            ),
          );
          _loadLogs();
        }
      } else {
        throw 'Fichier de base de données non trouvé à $dbPath';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sécurité & Audit'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.history_rounded), text: 'JOURNAL D\'AUDIT'),
            Tab(icon: Icon(Icons.backup_rounded), text: 'SAUVEGARDES'),
            Tab(icon: Icon(Icons.security_rounded), text: 'SÉCURITÉ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildBackupsTab(),
          _buildSecuritySettingsTab(),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    if (_isLoadingFromDb)
      return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activités récentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text('Aucun log d\'audit pour le moment.'),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          leading: _getSeverityIcon(log.severity),
                          title: Text(
                            log.action,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${log.username} • ${log.details}'),
                          trailing: Text(
                            DateFormat('dd/MM HH:mm').format(log.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _getSeverityIcon(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.low:
        return const Icon(Icons.info_outline, color: Colors.blue);
      case AuditSeverity.medium:
        return const Icon(Icons.warning_amber_rounded, color: Colors.orange);
      case AuditSeverity.high:
        return const Icon(Icons.error_outline, color: Colors.red);
      case AuditSeverity.critical:
        return const Icon(Icons.gpp_maybe_rounded, color: Colors.purple);
    }
  }

  Widget _buildBackupsTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.storage_rounded, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Maintenance de la base de données',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Effectuez des sauvegardes régulières pour prévenir la perte de données.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 300,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _exportDatabase,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Exporter la base de données (Backup)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: Le fichier sera enregistré dans votre dossier "Téléchargements".',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Politiques de Sécurité',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildSettingTile(
            'Expiration de session',
            'Déconnexion automatique après inactivité.',
            DropdownButton<int>(
              value: _sessionTimeout,
              items: [15, 30, 60, 120]
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text('$v minutes')),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _sessionTimeout = val!),
            ),
          ),
          const Divider(),
          _buildSettingTile(
            'Authentification à 2 facteurs (2FA)',
            'Ajoute une couche de sécurité supplémentaire lors de la connexion.',
            Switch(
              value: _twoFactorEnabled,
              onChanged: (val) => setState(() => _twoFactorEnabled = val),
              activeColor: AppColors.primary,
            ),
          ),
          const Divider(),
          _buildSettingTile(
            'Verrouillage après échecs',
            'Bloquer le compte après plusieurs tentatives infructueuses.',
            DropdownButton<int>(
              value: _failedAttemptsLocked,
              items: [3, 5, 10]
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text('$v tentatives'),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _failedAttemptsLocked = val!),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Paramètres mis à jour (Simulation)'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer les paramètres'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
