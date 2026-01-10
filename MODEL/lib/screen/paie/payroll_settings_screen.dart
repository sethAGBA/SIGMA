import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class PayrollSettingsScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const PayrollSettingsScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Paramétrage Paie',
      icon: Icons.settings,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
