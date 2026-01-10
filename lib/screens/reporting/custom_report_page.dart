import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/reporting/custom_report_config_model.dart';
import 'package:intl/intl.dart';

class CustomReportPage extends StatefulWidget {
  const CustomReportPage({super.key});

  @override
  State<CustomReportPage> createState() => _CustomReportPageState();
}

class _CustomReportPageState extends State<CustomReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _config = CustomReportConfig();

  // Available indicators
  final Map<String, String> _availableIndicators = {
    'outstanding_volume': 'Volume Encours Crédit',
    'active_loans': 'Nombre de Prêts Actifs',
    'par_30': 'PAR 30 Jours (%)',
    'par_90': 'PAR 90 Jours (%)',
    'savings_collected': 'Épargne Collectée',
    'new_clients': 'Nouveaux Clients',
    'disbursements': 'Décaissements (Volume)',
    'repayment_rate': 'Taux de Remboursement',
  };

  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    // Determine background color based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Custom App Bar for Dialog
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Générateur de Rapport Personnalisé',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: Stepper(
                  type: StepperType.horizontal,
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep < 3) {
                      setState(() => _currentStep += 1);
                    } else {
                      _generateReport();
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) {
                      setState(() => _currentStep -= 1);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Row(
                        children: [
                          if (_currentStep > 0) ...[
                            TextButton(
                              onPressed: details.onStepCancel,
                              child: const Text('Retour'),
                            ),
                            const SizedBox(width: 12),
                          ],
                          ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              _currentStep == 3
                                  ? 'Générer le Rapport'
                                  : 'Suivant',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Configuration'),
                      content: _buildConfigStep(isDark),
                      isActive: _currentStep >= 0,
                    ),
                    Step(
                      title: const Text('Indicateurs'),
                      content: _buildIndicatorsStep(isDark),
                      isActive: _currentStep >= 1,
                    ),
                    Step(
                      title: const Text('Filtres'),
                      content: _buildFiltersStep(isDark),
                      isActive: _currentStep >= 2,
                    ),
                    Step(
                      title: const Text('Export & Envoi'),
                      content: _buildExportStep(isDark),
                      isActive: _currentStep >= 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations générales',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Titre du rapport',
            border: OutlineInputBorder(),
            hintText: 'Ex: Rapport Mensuel Agence Abidjan',
          ),
          onChanged: (value) => _config.title = value,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer un titre';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Description (Optionnel)',
            border: OutlineInputBorder(),
            hintText: 'Description brève du contenu...',
          ),
          maxLines: 3,
          onChanged: (value) => _config.description = value,
        ),
        const SizedBox(height: 24),
        Text(
          'Format de sortie',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: ReportFormat.values.map((format) {
            final isSelected = _config.format == format;
            return ChoiceChip(
              label: Text(format.name.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _config.format = format);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIndicatorsStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sélectionnez les indicateurs à inclure',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cochez les cases pour ajouter des métriques à votre rapport.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ..._availableIndicators.entries.map((entry) {
          final isChecked = _config.selectedIndicators.contains(entry.key);
          return CheckboxListTile(
            title: Text(entry.value),
            value: isChecked,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _config.selectedIndicators.add(entry.key);
                } else {
                  _config.selectedIndicators.remove(entry.key);
                }
              });
            },
            secondary: Icon(
              Icons.bar_chart_rounded,
              color: isChecked ? AppColors.primary : Colors.grey,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFiltersStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtres & Période',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Date de début'),
          subtitle: Text(
            _config.startDate != null
                ? DateFormat('dd/MM/yyyy').format(_config.startDate!)
                : 'Non définie (Tout)',
          ),
          trailing: const Icon(Icons.calendar_today),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _config.startDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _config.startDate = picked);
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Date de fin'),
          subtitle: Text(
            _config.endDate != null
                ? DateFormat('dd/MM/yyyy').format(_config.endDate!)
                : 'Non définie (Tout)',
          ),
          trailing: const Icon(Icons.calendar_today),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _config.endDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _config.endDate = picked);
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Agences (Mock)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Toutes les agences'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Toutes les agences')),
            DropdownMenuItem(value: 'ag1', child: Text('Siège Principal')),
            DropdownMenuItem(value: 'ag2', child: Text('Agence Nord')),
          ],
          onChanged: (val) {}, // Mock
        ),
      ],
    );
  }

  Widget _buildExportStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Planifier un envoi automatique'),
          subtitle: const Text('Recevoir ce rapport par email régulièrement'),
          value: _config.isScheduled,
          onChanged: (val) => setState(() => _config.isScheduled = val),
        ),
        if (_config.isScheduled) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<ReportFrequency>(
            value: _config.frequency,
            decoration: const InputDecoration(
              labelText: 'Fréquence',
              border: OutlineInputBorder(),
            ),
            items: ReportFrequency.values.map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(f.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _config.frequency = val);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Destinataires (séparés par virgule)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            onChanged: (val) {
              _config.emailRecipients = val
                  .split(',')
                  .map((e) => e.trim())
                  .toList();
            },
          ),
        ],
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cliquez sur "Générer le Rapport" pour créer le document immédiatement. Si la planification est active, il sera également envoyé selon la fréquence choisie.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _generateReport() {
    if (_formKey.currentState!.validate()) {
      // Mock generation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rapport en cours de génération'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Création du rapport "${_config.title}" en format ${_config.format.name.toUpperCase()}...',
              ),
            ],
          ),
        ),
      );

      // Simulate delay
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rapport "${_config.title}" généré avec succès !'),
            backgroundColor: Colors.green,
            action: SnackBarAction(label: 'Ouvrir', onPressed: () {}),
          ),
        );
        Navigator.pop(context); // Return to catalog
      });
    }
  }
}
