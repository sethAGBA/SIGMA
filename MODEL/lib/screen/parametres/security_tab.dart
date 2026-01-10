import 'dart:io';

import 'package:afroforma/models/user.dart';
import 'package:afroforma/screen/parametres/models.dart';
import 'package:afroforma/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'helpers.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:otp/otp.dart';

class SecurityTab extends StatefulWidget {
  @override
  _SecurityTabState createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  bool _autoBackup = true;
  String _backupFrequency = 'Quotidienne';
  int _retentionDays = 30;
  bool _is2faEnabled = false;

  late CompanyInfo _companyInfo; // New field
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _companyInfo = (await DatabaseService().getCompanyInfo())!;
    _currentUser = AuthService.currentUser;
    setState(() {
      _autoBackup = _companyInfo.autoBackup;
      _backupFrequency = _companyInfo.backupFrequency;
      _retentionDays = _companyInfo.retentionDays;
      _is2faEnabled = _currentUser?.is2faEnabled ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: buildSection(
              'Sauvegarde & Restauration',
              Icons.backup,
              _buildBackupSection(),
            ),
          ),
          SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: buildSection(
              'Authentification à deux facteurs (2FA)',
              Icons.phonelink_lock,
              _build2faSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sauvegarde Automatique',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _autoBackup,
                    onChanged: (v) {
                      setState(() {
                        _autoBackup = v;
                        _saveSettings(); // Save settings on change
                      });
                    },
                    activeColor: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_autoBackup) ...[
                buildDropdownField(
                  'Fréquence',
                  _backupFrequency,
                  ['Quotidienne', 'Hebdomadaire', 'Mensuelle'],
                  (value) {
                    setState(() {
                      _backupFrequency = value!;
                      _saveSettings(); // Save settings on change
                    });
                  },
                  Icons.schedule,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Rétention (jours)', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: _retentionDays.toDouble(),
                        min: 7,
                        max: 90,
                        divisions: 83,
                        label: '$_retentionDays jours',
                        onChanged: (value) {
                          setState(() {
                            _retentionDays = value.toInt();
                            _saveSettings(); // Save settings on change
                          });
                        },
                        activeColor: const Color(0xFF10B981),
                        inactiveColor: Colors.white24,
                      ),
                    ),
                    Text('$_retentionDays', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        buildActionButton(
          'Sauvegarder Maintenant',
          Icons.backup,
          const Color(0xFF10B981),
          () => _performBackup(),
        ),
        const SizedBox(height: 12),
        buildActionButton(
          'Restaurer une Sauvegarde',
          Icons.restore,
          const Color(0xFF6366F1),
          () => _showRestoreDialog(),
        ),
      ],
    );
  }

  Widget _build2faSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activer le 2FA',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _is2faEnabled,
                onChanged: (value) {
                  if (value) {
                    _setup2FA();
                  } else {
                    _disable2FA();
                  }
                },
                activeColor: const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Lorsque cette option est activée, vous devrez fournir un code de votre application d\'authentification pour vous connecter.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }
  Future<void> _setup2FA() async {
    // Generate secret and show provisioning QR + manual secret (clean flow copied from XX)
    final rawSecret = OTP.randomSecret();
    final secret = rawSecret.replaceAll(' ', '').toUpperCase();
    final uri = 'otpauth://totp/AfroForma:${Uri.encodeComponent(_currentUser!.email)}?secret=$secret&issuer=AfroForma&algorithm=SHA1&digits=6&period=30';

    await showDialog(
      context: context,
      builder: (context) {
        final codeController = TextEditingController();
        final uriController = TextEditingController(text: uri);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Configurer le 2FA'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Scannez ce QR code avec votre application d\'authentification.'),
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: uriController.text,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Ou entrez ce code manuellement :'),
                    SelectableText(secret, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Align(alignment: Alignment.centerLeft, child: Text('Provisioning URI (otpauth) :', style: TextStyle(color: Colors.white70))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: uriController,
                            maxLines: 2,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton(
                              tooltip: 'Coller depuis le presse-papiers',
                              icon: const Icon(Icons.paste),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  uriController.text = data!.text!;
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URI collée')));
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Copier l\'URI',
                              icon: const Icon(Icons.copy),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: uriController.text));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URI copié dans le presse-papiers')));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Pour terminer la configuration, entrez le code à 6 chiffres généré par votre application.'),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Code de vérification',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final code = codeController.text;
                    if (code.length == 6) {
                      final trimmed = code.replaceAll(' ', '');
                      final nowMs = DateTime.now().millisecondsSinceEpoch;
                      bool isValid = false;
                      for (int offset = -1; offset <= 1; offset++) {
                        try {
                          final generated = OTP.generateTOTPCodeString(
                            secret,
                            nowMs + offset * 30 * 1000,
                            interval: 30,
                            length: 6,
                            algorithm: Algorithm.SHA1,
                            isGoogle: true,
                          );
                          if (generated == trimmed) {
                            isValid = true;
                            break;
                          }
                        } catch (_) {}
                      }

                      if (isValid) {
                        final updatedUser = _currentUser!.copyWith(
                          is2faEnabled: true,
                          twoFaSecret: secret,
                        );
                        await DatabaseService().updateUser(updatedUser);
                        setState(() {
                          _is2faEnabled = true;
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('2FA activé avec succès !')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code invalide. Veuillez réessayer.')),
                        );
                      }
                    }
                  },
                  child: const Text('Vérifier et Activer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _disable2FA() async {
    final updatedUser = _currentUser!.copyWith(
      is2faEnabled: false,
      twoFaSecret: null,
    );
    await DatabaseService().updateUser(updatedUser);
    setState(() {
      _is2faEnabled = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('2FA désactivé.')),
    );
  }


  Future<void> _saveSettings() async {
    _companyInfo.autoBackup = _autoBackup;
    _companyInfo.backupFrequency = _backupFrequency;
    _companyInfo.retentionDays = _retentionDays;
    await DatabaseService().saveCompanyInfo(_companyInfo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres de sauvegarde enregistrés.')),
    );
  }

  Future<void> _performBackup() async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Sauvegarder la base de données',
        fileName: 'afroforma_backup_${DateTime.now().millisecondsSinceEpoch}.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (outputFile != null) {
        final backupPath = await DatabaseService().backupDB(targetPath: outputFile);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sauvegarde réussie: $backupPath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde annulée.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de sauvegarde: $e')),
      );
    }
  }

  Future<void> _showRestoreDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la restauration'),
          content: Text('Êtes-vous sûr de vouloir restaurer la base de données à partir de "$filePath" ? Cela écrasera les données actuelles.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restaurer'),
            ),
          ],
        ),
      ) ?? false;

      if (confirm) {
        try {
          // Close current database connection before restoring
          await DatabaseService().close();
          // Restore the database
          // This is a simplified restore. In a real app, you might need to handle
          // database file replacement more carefully, e.g., by restarting the app.
          // For now, we'll just copy the file.
          // Get the current database path
          final appDocDir = await getApplicationDocumentsDirectory();
          final currentDbPath = p.join(appDocDir.path, 'afroforma.db');
          final backupFile = File(filePath);
          await backupFile.copy(currentDbPath);

          // Re-initialize the database service
          await DatabaseService().init();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restauration réussie à partir de "$filePath"')),
          );
          // You might want to restart the app or reload all data after restore
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de restauration: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier sélectionné.')),
      );
    }
  }
}
