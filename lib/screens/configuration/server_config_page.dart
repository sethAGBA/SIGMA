// lib/screens/configuration/server_config_page.dart
//
// Permet de configurer l'adresse IP du serveur FastAPI depuis l'app.

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';

class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService().baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      await ApiService().setServerUrl(url);
    }

    final available = await ApiService().isServerAvailable();

    setState(() {
      _isTesting = false;
      _testSuccess = available;
      _testResult = available
          ? '✅ Connexion réussie ! Serveur SIGMA détecté.'
          : '❌ Serveur inaccessible. Vérifiez l\'IP et que le serveur est démarré.';
    });
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await ApiService().setServerUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL serveur sauvegardée'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration du Serveur',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adresse IP du PC serveur sur votre réseau local (LAN)',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Statut mode actuel
                _buildModeIndicator(isDark),
                const SizedBox(height: 24),

                // Champ URL
                Text(
                  'URL du serveur API',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.100:8000/api/v1',
                    prefixIcon: const Icon(Icons.dns_rounded),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText:
                        'Format : http://[IP_SERVEUR]:8000/api/v1\n'
                        'Pour trouver l\'IP : sur le PC serveur → cmd → ipconfig',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 24),

                // Boutons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find_rounded),
                      label: Text(_isTesting ? 'Test...' : 'Tester la connexion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Sauvegarder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                // Résultat du test
                if (_testResult != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_testSuccess == true
                              ? AppColors.success
                              : AppColors.error)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_testSuccess == true
                                ? AppColors.success
                                : AppColors.error)
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testSuccess == true
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // Aide
                _buildHelp(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeIndicator(bool isDark) {
    final isOnline = ApiService().baseUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: isOnline ? AppColors.success : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode actuel : ${isOnline ? "Réseau (LAN)" : "Hors ligne (SQLite local)"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Serveur configuré : ${ApiService().baseUrl}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelp(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comment trouver l\'IP du serveur ?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '1. Sur le PC serveur : ouvrir un terminal (cmd)\n'
          '2. Taper : ipconfig\n'
          '3. Relever l\'Adresse IPv4 (ex: 192.168.1.100)\n'
          '4. Entrer : http://192.168.1.100:8000/api/v1',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
}
