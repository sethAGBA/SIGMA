import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/communication_models.dart';
import '../../models/client_model.dart';

class SmsSendingPage extends StatefulWidget {
  final List<int> preSelectedClientIds;

  const SmsSendingPage({
    super.key,
    this.preSelectedClientIds = const [],
  });

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

  // Bulk mode state
  bool _isBulkMode = false;
  List<Client> _bulkClients = [];

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

        if (widget.preSelectedClientIds.length == 1) {
          // Pré-remplir le client unique
          final match = _clients
              .where((c) => c.id == widget.preSelectedClientIds.first)
              .firstOrNull;
          if (match != null) _selectedClient = match;
        } else if (widget.preSelectedClientIds.length > 1) {
          // Mode bulk
          _isBulkMode = true;
          _bulkClients = _clients
              .where((c) => widget.preSelectedClientIds.contains(c.id))
              .toList();
        }

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

  Future<void> _sendBulkSms() async {
    if (_messageController.text.isEmpty) return;

    setState(() => _isSending = true);

    int sentCount = 0;
    try {
      for (final client in _bulkClients) {
        final log = NotificationLog(
          id: '${DateTime.now().millisecondsSinceEpoch}_${client.id}',
          clientId: client.id.toString(),
          recipient: client.telephone ?? 'N/A',
          message: _messageController.text,
          status: NotificationStatus.sent,
          timestamp: DateTime.now(),
          type: CommunicationType.sms,
        );
        await DatabaseService().insertNotificationLog(log);
        sentCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'SMS envoyés : ${_bulkClients.length}/${_bulkClients.length}'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _messageController.clear();
          _selectedTemplate = null;
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur après $sentCount envois : $e'),
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
                    _isBulkMode
                        ? _buildBulkForm(isDark)
                        : _buildForm(isDark),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Envoi de SMS',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              _isBulkMode
                  ? 'Envoi groupé à ${_bulkClients.length} destinataire(s).'
                  : 'Composez et envoyez des messages personnalisés à vos clients.',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulkForm(bool isDark) {
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
          // En-tête avec le nombre de destinataires
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  '${_bulkClients.length} destinataires sélectionnés',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Liste des destinataires
          const Text(
            '1. Destinataires',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _bulkClients.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final client = _bulkClients[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        client.nom[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text('${client.nom} ${client.prenoms}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(client.telephone ?? 'N/A'),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Champ message
          const Text(
            '2. Message',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MessageTemplate>(
            value: _selectedTemplate,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              hintText: 'Sélectionner un modèle (optionnel)...',
            ),
            items: _templates.map((t) {
              return DropdownMenuItem(value: t, child: Text(t.title));
            }).toList(),
            onChanged: (tmpl) {
              setState(() {
                _selectedTemplate = tmpl;
                if (tmpl != null) {
                  _messageController.text = tmpl.content;
                }
              });
            },
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

          // Bouton envoyer
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed:
                  _isSending || _messageController.text.isEmpty
                      ? null
                      : _sendBulkSms,
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
              label: Text(
                _isSending
                    ? 'ENVOI EN COURS...'
                    : 'ENVOYER À ${_bulkClients.length} DESTINATAIRES',
              ),
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
                      initialValue: _selectedClient != null
                          ? TextEditingValue(
                              text:
                                  '${_selectedClient!.nom} ${_selectedClient!.prenoms} (${_selectedClient!.telephone})',
                            )
                          : null,
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
