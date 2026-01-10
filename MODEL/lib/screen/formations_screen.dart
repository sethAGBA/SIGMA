import 'dart:io';
import 'package:afroforma/screen/edit_formation_dialog.dart';
import 'package:afroforma/services/notification_service.dart';
import '../services/database_service.dart';
import 'package:flutter/material.dart';
import '../models/formation.dart';
import '../models/formateur.dart';
import '../models/session.dart';
import 'formation_details_dialog.dart';
import 'new_formation_dialog.dart';

class FormationsScreen extends StatefulWidget {
  @override
  _FormationsScreenState createState() => _FormationsScreenState();
}

class _FormationsScreenState extends State<FormationsScreen> {
  final List<Formation> formations = [];
  List<Formation> filteredFormations = [];
  bool _loading = true;
  String selectedCategory = 'Toutes';
  String selectedLevel = 'Tous';
  String selectedStatus = 'Tous';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    filteredFormations = formations;
    _loadFormations();
  }

  Future<void> _loadFormations() async {
    final loaded = await DatabaseService().getFormations();
    setState(() {
      if (loaded.isNotEmpty) {
        formations.clear();
        formations.addAll(loaded);
      } else {
        // if DB empty, keep sample data as initial seed
        formations.addAll(_generateSampleData());
      }
      _filterFormations();
  _loading = false;
    });
  }

  void _filterFormations() {
    setState(() {
      filteredFormations = formations.where((formation) {
        bool matchesCategory = selectedCategory == 'Toutes' || formation.category == selectedCategory;
        bool matchesLevel = selectedLevel == 'Tous' || formation.level == selectedLevel;
        bool matchesStatus = selectedStatus == 'Tous' || 
            (selectedStatus == 'Active' && formation.isActive) ||
            (selectedStatus == 'Inactive' && !formation.isActive);
        bool matchesSearch = searchQuery.isEmpty || 
            formation.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            formation.id.toLowerCase().contains(searchQuery.toLowerCase());
        
        return matchesCategory && matchesLevel && matchesStatus && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de filtres et recherche
        _buildFilterBar(),
        const SizedBox(height: 24),
        
        // Grille des formations
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (filteredFormations.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: filteredFormations.length,
                      itemBuilder: (context, index) {
                        return _buildFormationCard(filteredFormations[index]);
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Barre de recherche
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                searchQuery = value;
                _filterFormations();
              },
              decoration: const InputDecoration(
                hintText: 'Rechercher une formation...',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Filtres
          Row(
            children: [
              Expanded(child: _buildFilterDropdown('Catégorie', selectedCategory, 
                ['Toutes', 'IT', 'Management', 'Marketing', 'Finance'], 
                (value) {
                  setState(() {
                    selectedCategory = value!;
                    _filterFormations();
                  });
                })),
              const SizedBox(width: 16),
              Expanded(child: _buildFilterDropdown('Niveau', selectedLevel,
                ['Tous', 'Débutant', 'Intermédiaire', 'Avancé'],
                (value) {
                  setState(() {
                    selectedLevel = value!;
                    _filterFormations();
                  });
                })),
              const SizedBox(width: 16),
              Expanded(child: _buildFilterDropdown('Statut', selectedStatus,
                ['Tous', 'Active', 'Inactive'],
                (value) {
                  setState(() {
                    selectedStatus = value!;
                    _filterFormations();
                  });
                })),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showNewFormationDialog(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nouvelle Formation', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF1E293B),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(color: Colors.white)),
          )).toList(),
          hint: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ),
      ),
    );
  }

  Widget _buildFormationCard(Formation formation) {
    return GestureDetector(
      onTap: () => _showFormationDetails(formation),
      child: Container(
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
            // Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.8),
                    const Color(0xFF059669).withOpacity(0.8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  formation.imageUrl.isNotEmpty
                      ? Image.file(
                          File(formation.imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Center(
                          child: Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: formation.isActive ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        formation.isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formation.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${formation.id}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formation.category,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          formation.duration,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${formation.price.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${formation.enrolledStudents} inscrits',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            Icons.edit,
                            'Modifier',
                            () => _editFormation(formation),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            Icons.copy,
                            'Dupliquer',
                            () => _duplicateFormation(formation),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            Icons.archive,
                            'Archiver',
                            () {
                              setState(() {
                                final idx = formations.indexWhere((f) => f.id == formation.id);
                                if (idx != -1) {
                                  formations[idx] = formations[idx].copyWith(isActive: false);
                                  _filterFormations();
                                }
                              });
                                // persist change
                                DatabaseService().updateFormation(formations.firstWhere((f) => f.id == formation.id));
                                NotificationService().showNotification(
                                  NotificationItem(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    message: 'Formation archivée',
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.school_outlined, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune formation trouvée',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajustez vos filtres ou créez une nouvelle formation',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showFormationDetails(Formation formation) {
    showDialog<Formation>(
      context: context,
      builder: (context) => FormationDetailsDialog(formation: formation),
    ).then((updated) {
      if (updated != null) {
        setState(() {
          final index = formations.indexWhere((f) => f.id == updated.id);
          if (index != -1) {
            formations[index] = updated;
            _filterFormations();
          }
        });
        NotificationService().showNotification(
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Formation mise à jour',
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    });
  }

  void _showNewFormationDialog() {
    showDialog(
      context: context,
      builder: (context) => NewFormationDialog(
        onFormationCreated: (formation) {
          setState(() {
            formations.add(formation);
            _filterFormations();
          });
          // persist to DB
          DatabaseService().insertFormation(formation);
          _showUndoSnackBar(
            'Formation ajoutée avec succès',
            () {
              setState(() {
                formations.remove(formation);
                _filterFormations();
              });
            },
          );
        },
      ),
    );
  }

  void _editFormation(Formation formation) {
    final originalFormation = formation; // Store the original formation
    showDialog(
      context: context,
      builder: (context) => EditFormationDialog(
        formation: formation,
        onFormationUpdated: (updatedFormation) {
          setState(() {
            final index = formations.indexWhere((f) => f.id == updatedFormation.id);
            if (index != -1) {
              formations[index] = updatedFormation;
              _filterFormations();
            }
          });
          DatabaseService().updateFormation(updatedFormation);
          _showUndoSnackBar(
            'Formation modifiée avec succès',
            () {
              setState(() {
                final index = formations.indexWhere((f) => f.id == originalFormation.id);
                if (index != -1) {
                  formations[index] = originalFormation;
                  _filterFormations();
                }
              });
            },
          );
        },
      ),
    );
  }

  void _duplicateFormation(Formation formation) {
    final duplicated = Formation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${formation.title} (Copie)',
      description: formation.description,
      duration: formation.duration,
      price: formation.price,
      imageUrl: formation.imageUrl,
      category: formation.category,
      level: formation.level,
    );
    
    setState(() {
      formations.add(duplicated);
      _filterFormations();
    });
  DatabaseService().insertFormation(duplicated);
    
    _showUndoSnackBar(
      'Formation dupliquée avec succès',
      () {
        setState(() {
          formations.remove(duplicated);
          _filterFormations();
        });
      },
      backgroundColor: Colors.green,
    );
  }

  void _showUndoSnackBar(String message, VoidCallback onUndo, {Color backgroundColor = Colors.blueGrey}) {
    NotificationService().showNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: message,
        onUndo: onUndo,
        backgroundColor: backgroundColor,
      ),
    );
  }

  static List<Formation> _generateSampleData() {
    return [
      Formation(
        id: '1',
        title: 'Développement Flutter',
        description: 'Apprenez à créer des applications mobiles avec Flutter',
        duration: '3 mois',
        price: 150000,
        imageUrl: '',
        category: 'IT',
        level: 'Intermédiaire',
        enrolledStudents: 25,
        revenue: 3750000,
        directCosts: 500000,
        indirectCosts: 200000,
        formateurs: [
          Formateur(id: 'f1', name: 'John Doe', speciality: 'Flutter', hourlyRate: 5000, email: 'john@example.com', phone: '+237600000000')
        ],
        sessions: [
          Session(id: 's1', name: 'Session 1', startDate: DateTime.now(), endDate: DateTime.now().add(Duration(days: 90)), room: 'Salle 101', maxCapacity: 30, currentEnrollments: 25)
        ]
      ),
      Formation(
        id: '2',
        title: 'Management d\'équipe',
        description: 'Les bases du management et du leadership',
        duration: '2 mois',
        price: 100000,
        imageUrl: '',
        category: 'Management',
        level: 'Débutant',
        enrolledStudents: 30,
        revenue: 3000000,
        directCosts: 400000,
        indirectCosts: 150000,
        isActive: false,
      ),
      // Ajoutez plus de données...
    ];
  }
}