import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/communication_models.dart';
import '../../models/client_model.dart';

class SmsSendingPage extends StatefulWidget {
  const SmsSendingPage({super.key});

  @override
  State<SmsSendingPage> createState() => _SmsSendingPageState();
}

class _SmsSendingPageState extends State<SmsSendingPage> {
  bool _isLoading = true;
  List<Client> _clients = [];
  List<MessageTemplate> _templates = [];

  Client? _selectedClient;
  MessageTemplate? _selectedTemplate;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final clients = await DatabaseService().getClients();
      final templates = await DatabaseService().getMessageTemplates();
      setState(() {
        _clients = clients;
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onTemplateChanged(MessageTemplate? template) {
    setState(() {
      _selectedTemplate = template;
      if (template != null) {
        _messageController.text = _applyPlaceholders(
          template.content,
          _selectedClient,
        );
      }
    });
  }

  void _onClientChanged(Client? client) {
    setState(() {
      _selectedClient = client;
      if (_selectedTemplate != null) {
        _messageController.text = _applyPlaceholders(
          _selectedTemplate!.content,
          client,
        );
      }
    });
  }

  String _applyPlaceholders(String content, Client? client) {
    if (client == null) return content;
    return content
        .replaceAll('{NOM}', client.nom)
        .replaceAll('{PRENOM}', client.prenoms)
        .replaceAll('{NUMERO}', client.numeroClient)
        .replaceAll(
          '{MONTANT}',
          '150 000 FCFA',
        ) // Mock or fetch from active loan
        .replaceAll(
          '{DATE}',
          DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.now().add(const Duration(days: 3))),
        )
        .replaceAll('{JOURS}', '5');
  }

  Future<void> _sendSms() async {
    if (_selectedClient == null || _messageController.text.isEmpty) return;

    setState(() => _isSending = true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      final log = NotificationLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clientId: _selectedClient!.id.toString(),
        recipient: _selectedClient!.telephone ?? 'N/A',
        message: _messageController.text,
        status: NotificationStatus.sent,
        timestamp: DateTime.now(),
        type: CommunicationType.sms,
      );

      await DatabaseService().insertNotificationLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS envoyé avec succès (Simulé)'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _selectedClient = null;
          _selectedTemplate = null;
          _messageController.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 32),
                    _buildForm(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.send_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Envoi de SMS',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              'Composez et envoyez des messages personnalisés à vos clients.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Sélectionner le destinataire',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<Client>(
                      displayStringForOption: (Client c) =>
                          '${c.nom} ${c.prenoms} (${c.telephone})',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '')
                          return const Iterable<Client>.empty();
                        return _clients.where((Client c) {
                          return c.nom.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ) ||
                              c.prenoms.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                        });
                      },
                      onSelected: _onClientChanged,
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Rechercher un client...',
                                prefixIcon: const Icon(
                                  Icons.person_search_rounded,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2. Choisir un modèle (optionnel)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<MessageTemplate>(
                      value: _selectedTemplate,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Sélectionner un modèle...',
                      ),
                      items: _templates.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.title));
                      }).toList(),
                      onChanged: _onTemplateChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            '3. Message final',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Saisissez votre message ici...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Taille estimée: ${_messageController.text.length} caractères (${(_messageController.text.length / 160).ceil()} SMS)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed:
                  _isSending ||
                      _selectedClient == null ||
                      _messageController.text.isEmpty
                  ? null
                  : _sendSms,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSending ? 'ENVOI EN COURS...' : 'ENVOYER LE SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
