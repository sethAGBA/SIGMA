import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class BusinessDashboardsScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const BusinessDashboardsScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Tableaux de Bord Métiers',
      icon: Icons.dashboard,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
