import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class JobPositionManagementScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const JobPositionManagementScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion des Postes de Travail',
      icon: Icons.work,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
