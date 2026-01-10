import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class PayrollReportsDeclarationsScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const PayrollReportsDeclarationsScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'États & Déclarations Paie',
      icon: Icons.description,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
