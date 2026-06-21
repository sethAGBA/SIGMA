// lib/screens/configuration/server_config_page.dart
//
// Section « Connexion serveur » — accès ADMIN uniquement (Phase 0, req. 4).

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/connectivity_monitor.dart';
import '../../core/theme/app_colors.dart';

class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  late TextEditingController _urlController;
  String? _validationError;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  static final _urlRegex = RegExp(
    r'^https?://[a-zA-Z0-9\-\.]+:\d{1,5}(/.*)?$',
    caseSensitive: false,
  );

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
    final url = _urlController.text.trim();
    if (!_urlRegex.hasMatch(url)) {
      setState(() {
        _validationError =
            'Format invalide. Exemple : http://192.168.1.100:8000/api/v1';
        _testResult = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _validationError = null;
    });

    // Test sans persister l'URL (req. 4.7) — sauvegarde temporaire puis restauration
    final savedUrl = ApiService().baseUrl;
    try {
      await ApiService().setServerUrl(url);
      final available = await ApiService().isServerAvailable();
      await ApiService().setServerUrl(savedUrl);

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = available;
        _testResult = available
            ? 'Connexion réussie — serveur SIGMA détecté.'
            : 'Serveur inaccessible. Vérifiez l\'IP et que le serveur est démarré.';
      });
    } catch (_) {
      await ApiService().setServerUrl(savedUrl);
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = 'Serveur inaccessible. Vérifiez l\'IP et que le serveur est démarré.';
      });
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (!_urlRegex.hasMatch(url)) {
      setState(() {
        _validationError =
            'Format invalide. Exemple : http://192.168.1.100:8000/api/v1';
      });
      return;
    }

    setState(() => _validationError = null);
    await ApiService().setServerUrl(url);
    ConnectivityMonitor().start();

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
    if (!AuthService().isAdmin) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

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
                  'Connexion serveur',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adresse IP du PC serveur sur votre réseau local (LAN)',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                ValueListenableBuilder<ConnectivityStatus>(
                  valueListenable: ConnectivityMonitor().statusNotifier,
                  builder: (context, status, _) =>
                      _StatusIndicator(status: status),
                ),
                const SizedBox(height: 24),

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
                    errorText: _validationError,
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
                      label: Text(
                        _isTesting ? 'Test...' : 'Tester la connexion',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),

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
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final ConnectivityStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectivityStatus.online => Colors.green,
      ConnectivityStatus.syncing => Colors.orange,
      ConnectivityStatus.offline => Colors.red,
    };
    final label = switch (status) {
      ConnectivityStatus.online => 'Connecté',
      ConnectivityStatus.syncing => 'Synchronisation...',
      ConnectivityStatus.offline => 'Hors ligne',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
