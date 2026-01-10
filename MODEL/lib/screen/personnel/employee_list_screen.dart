import 'package:afroforma/widgets/coming_soon_widget.dart';
import 'package:flutter/material.dart';

class EmployeeListScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const EmployeeListScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion des Employés',
      icon: Icons.work,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
