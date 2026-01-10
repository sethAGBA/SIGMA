import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class ProjectModuleScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const ProjectModuleScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Module Projet',
      icon: Icons.assignment,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
