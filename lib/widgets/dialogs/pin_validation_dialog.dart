// lib/widgets/dialogs/pin_validation_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../models/audit_log_model.dart';

class PinValidationDialog extends StatefulWidget {
  const PinValidationDialog({super.key});

  @override
  State<PinValidationDialog> createState() => _PinValidationDialogState();
}

class _PinValidationDialogState extends State<PinValidationDialog> {
  final _pinController = TextEditingController();
  int _attempts = 0;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Le PIN doit contenir 4 chiffres.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ok = await AuthService().validateSupervisorPin(pin);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    _attempts++;
    if (_attempts >= 3) {
      await DatabaseService().insertAuditLog(
        AuditLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: AuthService().currentUsername.isNotEmpty
              ? AuthService().currentUsername
              : 'Inconnu',
          action: 'PIN_VALIDATION_BLOCKED',
          details: '3 tentatives PIN superviseur échouées',
          timestamp: DateTime.now(),
          severity: AuditSeverity.high,
        ),
      );
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isLoading = false;
      _error = 'PIN incorrect. Tentative $_attempts/3';
      _pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Validation superviseur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saisissez le code PIN superviseur (4 chiffres) pour valider cette opération.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'PIN superviseur',
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _validate(),
          ),
          const SizedBox(height: 8),
          Text(
            'Tentatives : $_attempts/3',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _validate,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}
