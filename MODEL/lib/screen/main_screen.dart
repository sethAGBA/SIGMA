import 'package:afroforma/screen/formations_screen.dart';
import 'package:afroforma/screen/personnel/department_management_screen.dart';
import 'package:afroforma/screen/personnel/job_position_management_screen.dart';
import 'package:afroforma/widgets/menu_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:afroforma/models/user.dart';
import '../models/menu_item.dart';
import 'dashboard_screen.dart';
import 'analyses_screen.dart';
import 'students_screen.dart';
import 'documents_search_page.dart';
import 'comptabilite_screen.dart';
import 'package:afroforma/services/notification_service.dart';
import 'package:afroforma/widgets/notification_card.dart';
import 'parametres_screen.dart';
import 'facturation_screen.dart';
import 'package:afroforma/services/auth_service.dart'; // Added for logout
import 'package:afroforma/screen/login_screen.dart'; // Added for navigation after logout
import 'package:afroforma/screen/no_access_screen.dart';

// New screen imports
import 'package:afroforma/screen/personnel/employee_list_screen.dart';
import 'package:afroforma/screen/personnel/employee_detail_screen.dart';
import 'package:afroforma/screen/paie/payroll_main_screen.dart';
import 'package:afroforma/screen/temps_conges/time_tracking_attendance_screen.dart';
import 'package:afroforma/screen/materiel_achats/inventory_resources_screen.dart';
import 'package:afroforma/screen/reporting_avance/business_dashboards_screen.dart';
import 'package:afroforma/screen/parametres_etendus/multi_entity_configuration_screen.dart';


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  int selectedIndex = 0;
  String? _selectedTitle;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // This is the full list of all possible menu items.
  final List<MenuItem> _fullMenuItems = [
    MenuItem(
      icon: Icons.dashboard_rounded,
      title: 'Tableau de Bord',
      gradient: const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      ),
    ),
    MenuItem(
      icon: Icons.people_rounded,
      title: 'Étudiants',
      gradient: const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
      ),
    ),
    MenuItem(
      icon: Icons.school_rounded,
      title: 'Formations',
      gradient: const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
      ),
    ),
    MenuItem(
      icon: Icons.calculate_rounded,
      title: 'Comptabilité',
      gradient: const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
      ),
    ),
    MenuItem(
      icon: Icons.receipt_long_rounded,
      title: 'Facturation',
      gradient: const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
    ),
    MenuItem(
      icon: Icons.analytics_rounded,
      title: 'Analyses',
      gradient: const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      ),
      // Add Reporting Avancé and Analyse Étendue as submenus of Analyses
      children: [
        MenuItem(
          icon: Icons.analytics_outlined,
          title: 'Reporting Avancé',
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFDB2777)], // Pink
          ),
        ),
        MenuItem(
          icon: Icons.assessment,
          title: 'Analyse',
          gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        ),
        MenuItem(
          icon: Icons.analytics_outlined,
          title: 'Analyse Étendue',
          gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        ),
      ],
    ),
    MenuItem(
      icon: Icons.qr_code_scanner,
      title: 'Recherche certificats',
      gradient: const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
      ),
    ),
    // New Menu Items
    MenuItem(
      icon: Icons.people_alt_rounded,
      title: 'Personnel',
      gradient: const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF16A34A)], // Green
      ),
      children: [
        MenuItem(
          icon: Icons.person_add,
          title: 'Ajouter Employé',
          gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
        ),
        MenuItem(
          icon: Icons.people_rounded,
          title: 'Gestion des Employés',
          gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]), // Green
        ),
        MenuItem(
          icon: Icons.payments_rounded,
          title: 'Paie',
          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), // Blue
        ),
        MenuItem(
          icon: Icons.access_time_rounded,
          title: 'Temps & Congés',
          gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]), // Orange
        ),
        MenuItem(
          icon: Icons.business,
          title: 'Gestion des Départements',
          gradient: const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF4B5563)]), // Gray
        ),
        MenuItem(
          icon: Icons.work,
          title: 'Gestion des Postes',
          gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFDB2777)]), // Pink
        ),
      ],
    ),

    MenuItem(
      icon: Icons.inventory_2_rounded,
      title: 'Matériel & Achats',
      gradient: const LinearGradient(
        colors: [Color(0xFF6B7280), Color(0xFF4B5563)], // Gray
      ),
    ),
    MenuItem(
      icon: Icons.settings_rounded,
      title: 'Paramètres',
      gradient: const LinearGradient(
        colors: [Color(0xFF64748B), Color(0xFF475569)],
      ),
    ),
  // 'Admin. Étendue' removed from top-level menu per request
  // 'Reporting Avancé' and 'Admin. Étendue' were moved into parent menu items above
  ];

  // This list will hold the menu items that are visible to the current user.
  late List<MenuItem> _visibleMenuItems;

  @override
  void initState() {
    super.initState();
    _updateVisibleMenuItems();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _notificationService.addListener(_onNotificationsChanged);
  }

  void _updateVisibleMenuItems() {
    final user = AuthService.currentUser;
    final permissions = user?.permissions.map((p) => p.module).toSet() ?? {};

    if (user?.role == UserRole.admin) {
      _visibleMenuItems = List.from(_fullMenuItems);
    } else {
      _visibleMenuItems = _fullMenuItems.where((item) {
        return permissions.contains(item.title);
      }).toList();
    }

    // Check if there are any accessible modules other than logout
    final hasAccessibleModules = _visibleMenuItems.isNotEmpty;

    // The logout button is always added at the end.
    _visibleMenuItems.add(
      MenuItem(
        icon: Icons.logout_rounded,
        title: 'Déconnexion',
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
      ),
    );

    // If no accessible modules (excluding logout), navigate to NoAccessScreen
    if (!hasAccessibleModules && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const NoAccessScreen()),
          (Route<dynamic> route) => false,
        );
      });
    }
  }

  void _onNotificationsChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B),
                  const Color(0xFF334155),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Formation Manager',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Gestion Comptable',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu Items
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      itemCount: _visibleMenuItems.length,
                      itemBuilder: (context, index) {
                        return AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                (1 - _fadeAnimation.value) * 50 * (index + 1),
                              ),
                              child: Opacity(
                                opacity: _fadeAnimation.value,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                    child: MenuItemWidget(
                      item: _visibleMenuItems[index],
                      // Mark selected if top-level index matches and no specific child selected,
                      // or if this top-level title matches the selected title.
                      isSelected: (selectedIndex == index && _selectedTitle == null) || (_selectedTitle == _visibleMenuItems[index].title),
                      selectedTitle: _selectedTitle,
                      onMenuItemSelected: (item) {
                                        if (item.title == 'Déconnexion') {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                backgroundColor: const Color(0xFF1E293B),
                                                title: const Text('Confirmation de déconnexion', style: TextStyle(color: Colors.white)),
                                                content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: TextStyle(color: Colors.white70)),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('Annuler', style: TextStyle(color: Colors.white)),
                                                    onPressed: () {
                                                      Navigator.of(context).pop(); // Dismiss dialog
                                                    },
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                                    child: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
                                                    onPressed: () {
                                                      Navigator.of(context).pop(); // Dismiss dialog
                                                      AuthService.logout();
                                                      Navigator.of(context).pushAndRemoveUntil(
                                                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                                                        (Route<dynamic> route) => false, // Remove all previous routes
                                                      );
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        } else {
                                          setState(() {
                                            // Set selected title to render the corresponding content (works for children too)
                                            _selectedTitle = item.title;
                                            // Try to keep the selectedIndex aligned when a top-level item is chosen
                                            final topIndex = _visibleMenuItems.indexWhere((m) => m.title == item.title);
                                            if (topIndex != -1) selectedIndex = topIndex;
                                          });
                                          _animationController.reset();
                                          _animationController.forward();
                                        }
                                      },
                                    ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                // User Profile
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF6366F1),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AuthService.currentUser?.name ?? 'Utilisateur', // Display user name
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              AuthService.currentUser?.email ?? 'email@example.com', // Display user email
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // AppBar
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _visibleMenuItems[selectedIndex].title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            // Search Bar (wrapped in Stack so notification can overlay it)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 300,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: const TextField(
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Rechercher...',
                                      hintStyle: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_notificationService.notifications.isNotEmpty)
                                  (() {
                                    try {
                                      final notifItem = _notificationService.notifications.last;
                                      return Positioned(
                                        top: -8,
                                        right: -48,
                                        child: NotificationCard(
                                          item: notifItem,
                                          onDismissed: () {
                                            _notificationService.removeNotification(notifItem.id);
                                          },
                                        ),
                                      );
                                    } catch (_) {
                                      return const SizedBox.shrink();
                                    }
                                  }()),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Notifications
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  const Center(
                                    child: Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  if (_notificationService.notifications.isNotEmpty)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Content Area
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (selectedIndex >= _visibleMenuItems.length) {
      // Handle the case where the selectedIndex is out of bounds,
      // for example, after a user with fewer permissions logs in.
      selectedIndex = 0;
    }
  final titleToUse = _selectedTitle ?? _visibleMenuItems[selectedIndex].title;

  // Helper: find a MenuItem by title recursively in visible menu items
  MenuItem? _findMenuItemByTitle(String title) {
    for (final m in _visibleMenuItems) {
      if (m.title == title) return m;
      if (m.children != null) {
        for (final c in m.children!) {
          if (c.title == title) return c;
        }
      }
    }
    return null;
  }

  // Map the title to the appropriate widget
  // Find the MenuItem object matching the title (including children) to provide gradient/icon if needed
  final selectedMenuItem = _findMenuItemByTitle(titleToUse) ?? _visibleMenuItems[selectedIndex];

    switch (titleToUse) {
      case 'Tableau de Bord':
        return DashboardScreen(fadeAnimation: _fadeAnimation);
      case 'Étudiants':
        return StudentsScreen();
      case 'Formations':
        return FormationsScreen();
      case 'Comptabilité':
        return ComptabiliteScreen();
      case 'Facturation':
        return FacturationScreen(fadeAnimation: _fadeAnimation);
      case 'Analyses':
        return AnalysesScreen(fadeAnimation: _fadeAnimation);
      case 'Analyse':
        return AnalysesScreen(fadeAnimation: _fadeAnimation);
      case 'Paramètres':
        return ParametresScreen();
      case 'Recherche certificats':
        return DocumentsSearchPage();
      case 'Gestion des Employés':
        return EmployeeListScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Paie':
        return PayrollMainScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Temps & Congés':
        return TimeTrackingAttendanceScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Gestion des Départements':
        return DepartmentManagementScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Gestion des Postes':
        return JobPositionManagementScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Ajouter Employé':
        return EmployeeDetailScreen(employeeId: 'new', fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      
      case 'Matériel & Achats':
        return InventoryResourcesScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Reporting Avancé':
        return BusinessDashboardsScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Admin. Étendue':
        return MultiEntityConfigurationScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      case 'Analyse Étendue':
        // Reuse BusinessDashboardsScreen for extended analysis
        return BusinessDashboardsScreen(fadeAnimation: _fadeAnimation, gradient: selectedMenuItem.gradient);
      default:
        return DashboardScreen(fadeAnimation: _fadeAnimation);
    }
  }}