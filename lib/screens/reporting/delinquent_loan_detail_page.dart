import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/database_service.dart';
import '../../models/delinquent_loan_details_model.dart';
import '../../widgets/dialogs/register_recovery_action_dialog.dart';

class DelinquentLoanDetailPage extends StatefulWidget {
  final int loanId;

  const DelinquentLoanDetailPage({Key? key, required this.loanId})
    : super(key: key);

  @override
  _DelinquentLoanDetailPageState createState() =>
      _DelinquentLoanDetailPageState();
}

class _DelinquentLoanDetailPageState extends State<DelinquentLoanDetailPage> {
  final DatabaseService _dbService = DatabaseService();
  final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA');
  final dateFormat = DateFormat('dd/MM/yyyy');

  DelinquentLoanDetails? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final details = await _dbService.getDelinquentLoanDetails(widget.loanId);
    setState(() {
      _details = details;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: 1000,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Détail Créance en Souffrance',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_details == null)
                const Expanded(
                  child: Center(child: Text('Données introuvables')),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 32),
                        _buildTreeContent(isDark),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: _details != null
            ? FloatingActionButton.extended(
        heroTag: 'fab-delinquent',
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => RegisterRecoveryActionDialog(
                      loanId: _details!.loan.id!,
                      clientName: _details!.client.nomComplet,
                      numeroPret: _details!.loan.numeroPret,
                      onActionSaved: _loadDetails,
                    ),
                  );
                },
                label: const Text('ENREGISTRER UNE ACTION'),
                icon: const Icon(Icons.add_task_rounded),
                backgroundColor: Colors.red,
              )
            : null,
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 32,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _details!.client.nomComplet,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Prêt N° ${_details!.loan.numeroPret}',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_details!.joursRetard} JOURS DE RETARD',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(_details!.loan.soldeRestant),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -1,
                  color: Colors.red,
                ),
              ),
              Text(
                'SOLDE RESTANT DÛ',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeContent(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Situation de la créance:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 32),

          _buildTreeSection(
            'Identification',
            subItems: [
              _buildTreeSubItem(
                'Client et contact',
                _details!.client.telephone ?? 'Non renseigné',
              ),
              _buildTreeSubItem('N° prêt', _details!.loan.numeroPret),
              _buildTreeSubItem(
                'Agent gestionnaire',
                _details!.loan.agentGestionnaire ?? 'Inconnu',
              ),
              _buildTreeSubItem(
                'Agence',
                _details!.loan.agenceGestion ?? 'Inconnue',
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 32),
          _buildTreeSection(
            'Situation financière',
            subItems: [
              _buildTreeSubItem(
                'Solde dû',
                currencyFormat.format(_details!.loan.soldeRestant),
              ),
              _buildTreeSubItem(
                'Échéances impayées',
                '${_details!.unpaidSchedules.length} échéances',
              ),
              _buildTreeSubItem(
                'Jours de retard',
                '${_details!.joursRetard} jours',
              ),
              _buildTreeSubItem(
                'Pénalités accumulées',
                currencyFormat.format(_details!.penalitesAccumulees),
              ),
              _buildTreeSubItem(
                'Provision constituée',
                currencyFormat.format(_details!.provisionConstituee),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 32),
          _buildTreeSection(
            'Historique retards',
            subItems: [
              _buildTreeSubItem(
                'Premier retard',
                _details!.unpaidSchedules.isNotEmpty
                    ? dateFormat.format(
                        _details!.unpaidSchedules.first.datePrevue,
                      )
                    : 'Aucun',
              ),
              _buildTreeSubItem('Évolution', 'Tendance stable'),
              _buildTreeSubItem('Paiements partiels', '2 signalés'),
              _buildTreeSubItem(
                'Promesses non tenues',
                '1 enregistrée',
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 32),
          _buildTreeSection(
            'Actions recouvrement',
            subItems: [
              ..._details!.recoveryActions.map(
                (a) =>
                    _buildTreeSubItem(a.type.label, dateFormat.format(a.date)),
              ),
              _buildTreeSubItem('Mises en demeure', '1 envoyée'),
              _buildTreeSubItem(
                'Prochaine action',
                'Visite terrain prévue',
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 32),
          _buildTreeSection(
            'Garanties disponibles',
            subItems: [
              ..._details!.guarantees.map(
                (g) => _buildTreeSubItem(
                  g.type,
                  currencyFormat.format(g.estimatedValue),
                ),
              ),
              _buildTreeSubItem('Réalisabilité', 'Forte'),
              _buildTreeSubItem(
                'Estimation récupération',
                currencyFormat.format(_details!.loan.soldeRestant * 0.9),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 48),
          _buildTreeSection(
            'Décision recommandée',
            color: Colors.red,
            subItems: [
              _buildTreeSubItem(
                'Action',
                'Transfert Contentieux',
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSection(
    String title, {
    List<Widget>? subItems,
    Color color = Colors.grey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(0.5), width: 2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
        if (subItems != null)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Column(children: subItems),
          ),
      ],
    );
  }

  Widget _buildTreeSubItem(String label, String value, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Container(
            width: 1,
            color: isLast ? Colors.transparent : Colors.grey.withOpacity(0.3),
          ),
          Stack(
            children: [
              if (!isLast)
                Container(width: 1, color: Colors.grey.withOpacity(0.3)),
              Container(
                width: 16,
                height: 1,
                color: Colors.grey.withOpacity(0.3),
                margin: const EdgeInsets.only(top: 15),
              ),
              if (isLast)
                Container(
                  width: 1,
                  height: 15,
                  color: Colors.grey.withOpacity(0.3),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
