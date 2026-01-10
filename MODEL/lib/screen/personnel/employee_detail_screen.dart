import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    required this.fadeAnimation,
    required this.gradient,
  });

  @override
  _EmployeeDetailScreenState createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  String _appBarTitle = 'Infos Personnelles';

  // Controllers pour "Informations personnelles"
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _cniController = TextEditingController();
  final _passeportController = TextEditingController();
  final _permisController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _nomContactUrgenceController = TextEditingController();
  final _telephoneContactUrgenceController = TextEditingController();
  String? _situationFamiliale;
  final _enfantsController = TextEditingController();
  final _referencesController = TextEditingController();
  final _conjointController = TextEditingController();
  File? _photo;
  String? _sexe;
  final _religionController = TextEditingController();
  DateTime? _dateNaissance;
  final _autresInfosController = TextEditingController();
  final _lieuNaissanceController = TextEditingController();
  final _nationaliteController = TextEditingController();
  final _emailPersonnelController = TextEditingController();
  final _bpController = TextEditingController();
  final _villeController = TextEditingController();
  final _quartierController = TextEditingController();
  final _appartementRueController = TextEditingController();
  final _maisonController = TextEditingController();
  final _emailContactUrgenceController = TextEditingController();
  final _numeroPersonnelController = TextEditingController();
  final _numeroProfessionnelController = TextEditingController();
  final _posteController = TextEditingController();
  final _departementController = TextEditingController();
  final _salaireController = TextEditingController();
  final _managerController = TextEditingController();
  String? _typeContrat;
  DateTime? _dateEmbauche;
  DateTime? _finContrat;

  // Variables pour "Temps de travail"
  final _heuresHebdoController = TextEditingController();
  final _soldeCongesController = TextEditingController();
  final _soldeRttController = TextEditingController();

  // Variables pour "Données de paie"
  final _numeroSecu = TextEditingController();
  final _salaireBaseController = TextEditingController();
  final _primesController = TextEditingController();

  // Variables pour "Formation & Carrière"
  final _competencesController = TextEditingController();
  final _objectifsController = TextEditingController();

  // Variables pour "Administration"
  List<String> _equipements = [];
  List<String> _acces = [];
  final _observationsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_updateAppBarTitle);
    _loadEmployeeData();
  }

  void _updateAppBarTitle() {
    final tabTitles = [
      'Infos Personnelles',
      'Infos Professionnelles',
      'Temps de Travail',
      'Données de Paie',
      'Formation & Carrière',
      'Administration',
    ];
    if (mounted) {
      setState(() {
        _appBarTitle = tabTitles[_tabController.index];
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_updateAppBarTitle);
    _tabController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _cniController.dispose();
    _passeportController.dispose();
    _permisController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _nomContactUrgenceController.dispose();
    _telephoneContactUrgenceController.dispose();
    _enfantsController.dispose();
    _referencesController.dispose();
    _conjointController.dispose();
    _religionController.dispose();
    _posteController.dispose();
    _departementController.dispose();
    _salaireController.dispose();
    _managerController.dispose();
    _heuresHebdoController.dispose();
    _soldeCongesController.dispose();
    _soldeRttController.dispose();
    _numeroSecu.dispose();
    _salaireBaseController.dispose();
    _primesController.dispose();
    _competencesController.dispose();
    _objectifsController.dispose();
    _observationsController.dispose();
    _autresInfosController.dispose();
    super.dispose();
  }

  void _loadEmployeeData() {
    if (widget.employeeId != 'new') {
      // Charger les données de l\'employé depuis la base de données
      // Pour la démo, on utilise des données fictives
      _nomController.text = 'Dupont';
      _prenomController.text = 'Jean';
      _telephoneController.text = '+33 6 12 34 56 78';
      _posteController.text = 'Formateur Senior';
      _departementController.text = 'Pédagogie';
      _salaireController.text = '3500';
      _situationFamiliale = 'Marié(e)';
      _typeContrat = 'CDI';
      _dateEmbauche = DateTime(2020, 1, 15);
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _photo = File(result.files.single.path!);
      });
    }
  }

  Future<void> _selectDateNaissance(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateNaissance) {
      setState(() {
        _dateNaissance = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Infos Personnelles'),
                Tab(text: 'Infos Professionnelles'),
                Tab(text: 'Temps de Travail'),
                Tab(text: 'Données de Paie'),
                Tab(text: 'Formation & Carrière'),
                Tab(text: 'Administration'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.7],
          ),
        ),
        child: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInformationsPersonnellesTab(),
              _buildInformationsProfessionnellesTab(),
              _buildTempsDeTravailTab(),
              _buildDonneesPaieTab(),
              _buildFormationCarriereTab(),
              _buildAdministrationTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveEmployee,
        backgroundColor: const Color(0xFF22C55E),
        icon: const Icon(Icons.save),
        label: const Text('Enregistrer'),
      ),
    );
  }

  Widget _buildInformationsPersonnellesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'État Civil',
            [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _photo != null ? FileImage(_photo!) : null,
                    child: _photo == null
                        ? const Icon(Icons.camera_alt, size: 40)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nomController,
                      decoration: _inputDecoration('Nom *'),
                      validator: (value) => value?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _prenomController,
                      decoration: _inputDecoration('Prénom(s) *'),
                      validator: (value) => value?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cniController,
                      decoration: _inputDecoration('N° CNI'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _passeportController,
                      decoration: _inputDecoration('N° Passeport'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _permisController,
                decoration: _inputDecoration('N° Permis de Conduire'),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDateNaissance(context),
                child: InputDecorator(
                  decoration: _inputDecoration('Date de naissance'),
                  child: Text(_dateNaissance?.toString().split(' ')[0] ?? 'Sélectionner'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sexe,
                decoration: _inputDecoration('Sexe'),
                items: ['Masculin', 'Féminin']
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _sexe = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _religionController,
                decoration: _inputDecoration('Religion'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lieuNaissanceController,
                decoration: _inputDecoration('Lieu de naissance'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationaliteController,
                decoration: _inputDecoration('Nationalité'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lieuNaissanceController,
                decoration: _inputDecoration('Lieu de naissance'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationaliteController,
                decoration: _inputDecoration('Nationalité'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lieuNaissanceController,
                decoration: _inputDecoration('Lieu de naissance'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationaliteController,
                decoration: _inputDecoration('Nationalité'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Contacts',
            [
              TextFormField(
                controller: _emailPersonnelController,
                decoration: _inputDecoration('Email personnel'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bpController,
                decoration: _inputDecoration('BP'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villeController,
                decoration: _inputDecoration('Ville'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quartierController,
                decoration: _inputDecoration('Quartier de résidence'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _appartementRueController,
                decoration: _inputDecoration('Appartement/Rue'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maisonController,
                decoration: _inputDecoration('Maison'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _telephoneController,
                      decoration: _inputDecoration('Téléphone'),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _nomContactUrgenceController,
                      decoration: _inputDecoration('Nom du contact d\'urgence'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _telephoneContactUrgenceController,
                      decoration: _inputDecoration('Téléphone du contact d\'urgence'),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailContactUrgenceController,
                decoration: _inputDecoration('Email du contact d\'urgence'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroPersonnelController,
                decoration: _inputDecoration('Numéro personnel'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroProfessionnelController,
                decoration: _inputDecoration('Numéro professionnel'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referencesController,
                decoration: _inputDecoration('Références'),
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Situation Familiale',
            [
              DropdownButtonFormField<String>(
                value: _situationFamiliale,
                decoration: _inputDecoration('Situation familiale'),
                items: ['Célibataire', 'Marié(e)', 'Divorcé(e)', 'Veuf(ve)']
                    .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _situationFamiliale = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _enfantsController,
                decoration: _inputDecoration('Nombre d\'enfants à charge'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conjointController,
                decoration: _inputDecoration('Nom du conjoint'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Documents RH',
            [
              _buildDocumentUploadSection(),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Autres Informations',
            [
              TextFormField(
                controller: _autresInfosController,
                decoration: _inputDecoration('Informations supplémentaires'),
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformationsProfessionnellesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            'Poste Actuel',
            [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _posteController,
                      decoration: _inputDecoration('Intitulé du poste *'),
                      validator: (value) => value?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _departementController,
                      decoration: _inputDecoration('Département'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _managerController,
                decoration: _inputDecoration('Responsable hiérarchique'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Contrat de Travail',
            [
              DropdownButtonFormField<String>(
                value: _typeContrat,
                decoration: _inputDecoration('Type de contrat *'),
                items: ['CDI', 'CDD', 'Stage', 'Consultant', 'Apprentissage']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _typeContrat = value),
                validator: (value) => value == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: _inputDecoration('Date d\'embauche *'),
                        child: Text(_dateEmbauche?.toString().split(' ')[0] ?? 'Sélectionner'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: _inputDecoration('Fin de contrat'),
                        child: Text(_finContrat?.toString().split(' ')[0] ?? 'Non définie'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Rémunération',
            [
              TextFormField(
                controller: _salaireController,
                decoration: _inputDecoration('Salaire brut mensuel (FCFA)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Avantages en nature:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Véhicule de fonction'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                  FilterChip(
                    label: const Text('Tickets restaurant'),
                    selected: true,
                    onSelected: (selected) {},
                  ),
                  FilterChip(
                    label: const Text('Mutuelle'),
                    selected: true,
                    onSelected: (selected) {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTempsDeTravailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            'Planning Hebdomadaire',
            [
              TextFormField(
                controller: _heuresHebdoController,
                decoration: _inputDecoration('Heures hebdomadaires'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Horaires type:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildScheduleWeek(),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Soldes Congés',
            [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _soldeCongesController,
                      decoration: _inputDecoration('Congés payés (jours)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _soldeRttController,
                      decoration: _inputDecoration('RTT (jours)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Présences du Mois',
            [
              _buildPresenceCalendar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonneesPaieTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            'Informations Sociales',
            [
              TextFormField(
                controller: _numeroSecu,
                decoration: _inputDecoration('N° Sécurité Sociale'),
              ),
              const SizedBox(height: 16),
              const Text('Situation sociale:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Cadre'),
                    selected: true,
                    onSelected: (selected) {},
                  ),
                  FilterChip(
                    label: const Text('Non-cadre'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Éléments de Paie',
            [
              TextFormField(
                controller: _salaireBaseController,
                decoration: _inputDecoration('Salaire de base (FCFA)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _primesController,
                decoration: _inputDecoration('Primes variables (FCFA)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Générer bulletin de paie
                },
                icon: const Icon(Icons.description),
                label: const Text('Générer bulletin de paie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Historique des Bulletins',
            [
              _buildPayrollHistory(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormationCarriereTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            'Compétences',
            [
              TextFormField(
                controller: _competencesController,
                decoration: _inputDecoration('Compétences clés'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Certifications:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildCertificationsList(),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Plan de Formation',
            [
              ElevatedButton.icon(
                onPressed: () {
                  // Ajouter formation
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une formation'),
              ),
              const SizedBox(height: 16),
              _buildFormationPlan(),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Évaluations',
            [
              TextFormField(
                controller: _objectifsController,
                decoration: _inputDecoration('Objectifs annuels'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Nouvel entretien
                },
                icon: const Icon(Icons.rate_review),
                label: const Text('Programmer entretien'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdministrationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            'Équipements Assignés',
            [
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: const Text('Laptop Dell #12345'),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {},
                  ),
                  Chip(
                    label: const Text('Téléphone mobile'),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {},
                  ),
                  Chip(
                    label: const Text('Badge accès'),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Assigner équipement
                },
                icon: const Icon(Icons.add),
                label: const Text('Assigner équipement'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Accès & Permissions',
            [
              const Text('Accès autorisés:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Salle de formation A'),
                value: true,
                onChanged: (value) {},
              ),
              CheckboxListTile(
                title: const Text('Laboratoire informatique'),
                value: true,
                onChanged: (value) {},
              ),
              CheckboxListTile(
                title: const Text('Parking privé'),
                value: false,
                onChanged: (value) {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Notes Administratives',
            [
              TextFormField(
                controller: _observationsController,
                decoration: _inputDecoration('Observations'),
                maxLines: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).cardColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).cardColor),
      ),
    );
  }

  Widget _buildDocumentUploadSection() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.upload_file),
          label: const Text('Ajouter documents'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        // Liste des documents uploadés
        const ListTile(
          leading: Icon(Icons.description, color: Colors.red),
          title: Text('CV_Jean_Dupont.pdf'),
          subtitle: Text('Uploadé le 15/01/2024'),
          trailing: Icon(Icons.download),
        ),
        const ListTile(
          leading: Icon(Icons.school, color: Colors.green),
          title: Text('Diplome_Master.pdf'),
          subtitle: Text('Uploadé le 15/01/2024'),
          trailing: Icon(Icons.download),
        ),
      ],
    );
  }

  Widget _buildScheduleWeek() {
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];
    return Column(
      children: days.map((day) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(day)),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration('Horaires (ex: 09:00-17:00)'),
                ),
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildPresenceCalendar() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text('Calendrier des présences'),
      ),
    );
  }

  Widget _buildPayrollHistory() {
    return Column(
      children: [
        const ListTile(
          leading: Icon(Icons.description, color: Colors.blue),
          title: Text('Bulletin Janvier 2024'),
          subtitle: Text('Net: 2,850 FCFA'),
          trailing: Icon(Icons.download),
        ),
        const ListTile(
          leading: Icon(Icons.description, color: Colors.blue),
          title: Text('Bulletin Décembre 2023'),
          subtitle: Text('Net: 2,920 FCFA (13ème mois)'),
          trailing: Icon(Icons.download),
        ),
      ],
    );
  }

  Widget _buildCertificationsList() {
    return Column(
      children: [
        const ListTile(
          leading: Icon(Icons.verified, color: Colors.green),
          title: Text('Certification PMP'),
          subtitle: Text('Valide jusqu\'au 15/12/2025'),
        ),
        const ListTile(
          leading: Icon(Icons.warning, color: Colors.orange),
          title: Text('Habilitation électrique'),
          subtitle: Text('Expire le 30/06/2024'),
        ),
      ],
    );
  }

  Widget _buildFormationPlan() {
    return Column(
      children: [
        const ListTile(
          leading: Icon(Icons.schedule, color: Colors.blue),
          title: Text('Management d\'équipe'),
          subtitle: Text('Programmée: Mars 2024'),
          trailing: Text('3 jours'),
        ),
        const ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('Sécurité au travail'),
          subtitle: Text('Terminée: Janvier 2024'),
          trailing: Text('1 jour'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateEmbauche = picked;
        } else {
          _finContrat = picked;
        }
      });
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      // Traitement des fichiers sélectionnés
      for (var file in result.files) {
        print('Fichier sélectionné: ${file.name}');
      }
    }
  }

  void _saveEmployee() {
    if (_formKey.currentState!.validate()) {
      // Sauvegarder les données
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employé enregistré avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez corriger les erreurs'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}