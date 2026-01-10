import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class CrmModuleScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const CrmModuleScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Module CRM Avancé',
      icon: Icons.people_alt,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
