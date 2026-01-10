import 'package:flutter/material.dart';
import 'parametres/entreprise_tab.dart';
import 'parametres/utilisateurs_tab.dart';
import 'parametres/templates_tab.dart';
import 'parametres/ecriture_templates_tab.dart';
import 'parametres/security_tab.dart';
import 'parametres/parametres_etendus_tab.dart';

/// ParametresScreen
/// Lightweight wrapper that exposes the refactored tabs under lib/screen/parametres/
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({Key? key}) : super(key: key);

  @override
  _ParametresScreenState createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header avec onglets
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paramètres & Administration',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configuration système et gestion des utilisateurs',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Onglets
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.business), text: 'Entreprise'),
                    Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
                    Tab(icon: Icon(Icons.description), text: 'Templates'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Modèles écritures'),
                    Tab(icon: Icon(Icons.security), text: 'Sécurité'),
                    Tab(icon: Icon(Icons.settings_applications), text: 'Paramètres Étendus'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Contenu des onglets
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: EntrepriseTab()),
              Padding(padding: const EdgeInsets.all(16), child: UtilisateursTab()),
              Padding(padding: const EdgeInsets.all(16), child: TemplatesTab()),
              Padding(padding: const EdgeInsets.all(16), child: EcritureTemplatesTab()),
              Padding(padding: const EdgeInsets.all(16), child: SecurityTab()),
              Padding(padding: const EdgeInsets.all(16), child: ParametresEtendusTab()),
            ],
          ),
        ),
      ],
    );
  }
}
