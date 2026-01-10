import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class DepartmentManagementScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const DepartmentManagementScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion des Départements',
      icon: Icons.business,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
