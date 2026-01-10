import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class RegulatoryComplianceScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const RegulatoryComplianceScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Conformité Réglementaire',
      icon: Icons.gavel,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
