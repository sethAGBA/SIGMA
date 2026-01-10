import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'helpers.dart';
import 'models.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dialogs.dart'; // For PlanComptableDialog
class EntrepriseTab extends StatefulWidget {
  @override
  _EntrepriseTabState createState() => _EntrepriseTabState();
}

class _EntrepriseTabState extends State<EntrepriseTab> {
  final _formKey = GlobalKey<FormState>();
  final _raisonSocialeController = TextEditingController();
  final _rccmController = TextEditingController();
  final _nifController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _siteWebController = TextEditingController();
  final _exerciceController = TextEditingController();
  final _academicYearController = TextEditingController();
  final _targetRevenueController = TextEditingController(); // New controller for target revenue
  final _directorNameController = TextEditingController(); // New controller for director name
  final _locationController = TextEditingController();     // New controller for location
  
  String? _logoPath;
  String _monnaie = 'FCFA';
  String _planComptable = 'SYSCOHADA';

  int _selectedExerciceStartMonth = DateTime.now().month;
  int _selectedExerciceStartYear = DateTime.now().year;
  int _selectedExerciceEndMonth = DateTime.now().month;
  int _selectedExerciceEndYear = DateTime.now().year;

  int _selectedAcademicStartMonth = DateTime.now().month;
  int _selectedAcademicStartYear = DateTime.now().year;
  int _selectedAcademicEndMonth = DateTime.now().month;
  int _selectedAcademicEndYear = DateTime.now().year;

  late Future<void> _loadingFuture; // New Future to track loading

  @override
  void initState() {
    super.initState();
    _loadingFuture = _loadCompanyInfo(); // Assign the future
  }

  Future<void> _loadCompanyInfo() async {
    final loadedInfo = await DatabaseService().getCompanyInfo();
    if (loadedInfo != null) {
      _raisonSocialeController.text = loadedInfo.name;
      _rccmController.text = loadedInfo.rccm;
      _nifController.text = loadedInfo.nif;
      _adresseController.text = loadedInfo.address;
      _telephoneController.text = loadedInfo.phone;
      _emailController.text = loadedInfo.email;
      _siteWebController.text = loadedInfo.website;
      _logoPath = loadedInfo.logoPath;
      _directorNameController.text = loadedInfo.directorName; // Initialize new controller
      _locationController.text = loadedInfo.location;     // Initialize new controller

      // Parse exercice and academic year
      final exerciceParts = loadedInfo.exercice.split(' - ');
      if (exerciceParts.length == 2) {
        final startParts = exerciceParts[0].split('/');
        final endParts = exerciceParts[1].split('/');
        if (startParts.length == 2 && endParts.length == 2) {
          _selectedExerciceStartMonth = int.tryParse(startParts[0]) ?? DateTime.now().month;
          _selectedExerciceStartYear = int.tryParse(startParts[1]) ?? DateTime.now().year;
          _selectedExerciceEndMonth = int.tryParse(endParts[0]) ?? DateTime.now().month;
          _selectedExerciceEndYear = int.tryParse(endParts[1]) ?? DateTime.now().year;
        }
      }

      final academicYearParts = loadedInfo.academic_year.split(' - ');
      if (academicYearParts.length == 2) {
        final startParts = academicYearParts[0].split('/');
        final endParts = academicYearParts[1].split('/');
        if (startParts.length == 2 && endParts.length == 2) {
          _selectedAcademicStartMonth = int.tryParse(startParts[0]) ?? DateTime.now().month;
          _selectedAcademicStartYear = int.tryParse(startParts[1]) ?? DateTime.now().year;
          _selectedAcademicEndMonth = int.tryParse(endParts[0]) ?? DateTime.now().month;
          _selectedAcademicEndYear = int.tryParse(endParts[1]) ?? DateTime.now().year;
        }
      }

      _targetRevenueController.text = loadedInfo.targetRevenue.toStringAsFixed(0); // Initialize controller
      setState(() {
        _monnaie = loadedInfo.monnaie;
        _planComptable = loadedInfo.planComptable;
      });
    }
  }

  @override
  void dispose() {
    _raisonSocialeController.dispose();
    _rccmController.dispose();
    _nifController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _siteWebController.dispose();
    _directorNameController.dispose(); // Dispose new controller
    _locationController.dispose();     // Dispose new controller
    super.dispose();
  }

    Widget _buildMonthYearPicker(
    String label,
    int currentMonth,
    int currentYear,
    Function(int month, int year) onDateTimeChanged,
    IconData icon,
  ) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime(currentYear, currentMonth),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDatePickerMode: DatePickerMode.year,
        );
        if (picked != null) {
          onDateTimeChanged(picked.month, picked.year);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1)),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
        ),
        child: Text(
          '${_getMonthName(currentMonth)} $currentYear',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Janvier';
      case 2: return 'Février';
      case 3: return 'Mars';
      case 4: return 'Avril';
      case 5: return 'Mai';
      case 6: return 'Juin';
      case 7: return 'Juillet';
      case 8: return 'Août';
      case 9: return 'Septembre';
      case 10: return 'Octobre';
      case 11: return 'Novembre';
      case 12: return 'Décembre';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        } else {
          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations société
                Expanded(
                  flex: 2,
                  child: buildSection(
                    'Informations Société',
                    Icons.business,
                    Column(
                      children: [
                        _buildLogoUpload(),
                        const SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              buildTextField(_raisonSocialeController, 'Raison Sociale', Icons.business_center),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: buildTextField(_rccmController, 'RCCM', Icons.assignment)),
                                  const SizedBox(width: 16),
                                  Expanded(child: buildTextField(_nifController, 'NIF', Icons.receipt_long)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              buildTextField(_adresseController, 'Adresse', Icons.location_on, maxLines: 2),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: buildTextField(_telephoneController, 'Téléphone', Icons.phone)),
                                  const SizedBox(width: 16),
                                  Expanded(child: buildTextField(_emailController, 'Email', Icons.email)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              buildTextField(_siteWebController, 'Site Web', Icons.web),
                              const SizedBox(height: 16),
                              buildTextField(_directorNameController, 'Nom du Directeur', Icons.person),
                              const SizedBox(height: 16),
                              buildTextField(_locationController, 'Lieu (Ville, Pays)', Icons.location_city),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Paramètres comptables
                Expanded(
                  child: Column(
                    children: [
                      buildSection(
                        'Paramètres Comptables',
                        Icons.calculate,
                        Column(
                          children: [
                            buildDropdownField(
                              'Plan Comptable',
                              _planComptable,
                              ['SYSCOHADA', 'PCG', 'Personnalisé'],
                              (value) => setState(() => _planComptable = value!),
                              Icons.account_balance,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMonthYearPicker(
                                    'Début Exercice',
                                    _selectedExerciceStartMonth,
                                    _selectedExerciceStartYear,
                                    (month, year) {
                                      setState(() {
                                        _selectedExerciceStartMonth = month;
                                        _selectedExerciceStartYear = year;
                                      });
                                    },
                                    Icons.calendar_today,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildMonthYearPicker(
                                    'Fin Exercice',
                                    _selectedExerciceEndMonth,
                                    _selectedExerciceEndYear,
                                    (month, year) {
                                      setState(() {
                                        _selectedExerciceEndMonth = month;
                                        _selectedExerciceEndYear = year;
                                      });
                                    },
                                    Icons.calendar_today,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMonthYearPicker(
                                    'Début Année Académique',
                                    _selectedAcademicStartMonth,
                                    _selectedAcademicStartYear,
                                    (month, year) {
                                      setState(() {
                                        _selectedAcademicStartMonth = month;
                                        _selectedAcademicStartYear = year;
                                      });
                                    },
                                    Icons.school,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildMonthYearPicker(
                                    'Fin Année Académique',
                                    _selectedAcademicEndMonth,
                                    _selectedAcademicEndYear,
                                    (month, year) {
                                      setState(() {
                                        _selectedAcademicEndMonth = month;
                                        _selectedAcademicEndYear = year;
                                      });
                                    },
                                    Icons.school,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            buildDropdownField(
                              'Monnaie',
                              _monnaie,
                              ['FCFA', 'EUR', 'USD'],
                              (value) => setState(() => _monnaie = value!),
                              Icons.monetization_on,
                            ),
                            const SizedBox(height: 16), // Added SizedBox for spacing
                            buildTextField(
                              _targetRevenueController,
                              'Objectif de Chiffre d\'Affaires (FCFA)',
                              Icons.trending_up,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 20),
                            buildActionButton(
                              'Configurer Plan Comptable',
                              Icons.settings,
                              const Color(0xFF8B5CF6),
                              () => _configurePlanComptable(),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Actions
                      buildSection(
                        'Actions',
                        Icons.save,
                        Column(
                          children: [
                            buildActionButton(
                              'Enregistrer les Modifications',
                              Icons.save,
                              const Color(0xFF10B981),
                              () => _saveConfiguration(),
                            ),
                            const SizedBox(height: 12),
                            buildActionButton(
                              'Réinitialiser',
                              Icons.refresh,
                              const Color(0xFFEF4444),
                              () => _resetConfiguration(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildLogoUpload() {
    return GestureDetector(
      onTap: () => _pickLogo(),
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
        ),
        child: Builder( // Use Builder to get a new context for debug print
          builder: (context) {
            final bool fileExists = _logoPath != null && File(_logoPath!).existsSync();
            print('Logo path in build: $_logoPath, exists: $fileExists'); // Debug print
            return fileExists
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(File(_logoPath!), fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, color: Colors.white.withOpacity(0.5), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Logo Entreprise',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      Text(
                        'Cliquer pour changer',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final companyLogoDir = Directory(p.join(appDocDir.path, 'company_logo'));
      if (!await companyLogoDir.exists()) {
        await companyLogoDir.create(recursive: true);
      }
      final logoFileName = p.basename(image.path);
      final newLogoPath = p.join(companyLogoDir.path, logoFileName);
      final newLogoFile = await File(image.path).copy(newLogoPath);
      setState(() {
        _logoPath = newLogoFile.path;
      });
    }
  }

  void _configurePlanComptable() {
    showDialog(
      context: context,
      builder: (context) => PlanComptableDialog(),
    );
  }

  Future<void> _saveConfiguration() async {
    if (_formKey.currentState!.validate()) {
      final companyInfo = CompanyInfo(
        name: _raisonSocialeController.text,
        address: _adresseController.text,
        phone: _telephoneController.text,
        email: _emailController.text,
        rccm: _rccmController.text,
        nif: _nifController.text,
        website: _siteWebController.text,
        logoPath: _logoPath ?? '',
        exercice: '${_selectedExerciceStartMonth.toString().padLeft(2, '0')}/${_selectedExerciceStartYear} - ${_selectedExerciceEndMonth.toString().padLeft(2, '0')}/${_selectedExerciceEndYear}',
        monnaie: _monnaie,
        planComptable: _planComptable,
        academic_year: '${_selectedAcademicStartMonth.toString().padLeft(2, '0')}/${_selectedAcademicStartYear} - ${_selectedAcademicEndMonth.toString().padLeft(2, '0')}/${_selectedAcademicEndYear}',
        targetRevenue: double.tryParse(_targetRevenueController.text) ?? 0.0, // Save new field
        directorName: _directorNameController.text, // Save new field
        location: _locationController.text,       // Save new field
      );
      await DatabaseService().saveCompanyInfo(companyInfo);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration sauvegardée avec succès'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _resetConfiguration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir réinitialiser la configuration ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Reset to default values
              _raisonSocialeController.text = '';
              _rccmController.text = '';
              _nifController.text = '';
              _adresseController.text = '';
              _telephoneController.text = '';
              _emailController.text = '';
              _siteWebController.text = '';
              _directorNameController.text = ''; // Clear new field
              _locationController.text = '';     // Clear new field
              setState(() {
                _logoPath = null;
                _monnaie = 'FCFA';
                _planComptable = 'SYSCOHADA';
                _selectedExerciceStartMonth = DateTime.now().month;
                _selectedExerciceStartYear = DateTime.now().year;
                _selectedExerciceEndMonth = DateTime.now().month;
                _selectedExerciceEndYear = DateTime.now().year;
                _selectedAcademicStartMonth = DateTime.now().month;
                _selectedAcademicStartYear = DateTime.now().year;
                _selectedAcademicEndMonth = DateTime.now().month;
                _selectedAcademicEndYear = DateTime.now().year;
              });
              // Also delete from DB
              await DatabaseService().saveCompanyInfo(CompanyInfo(
                name: '', address: '', phone: '', email: '', rccm: '', nif: '', website: '', logoPath: '', 
                exercice: '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year} - ${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                monnaie: 'FCFA', planComptable: 'SYSCOHADA', 
                academic_year: '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year} - ${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                targetRevenue: 0.0, // Reset target revenue
                directorName: '', // Reset director name
                location: '',    // Reset location
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuration réinitialisée avec succès'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
