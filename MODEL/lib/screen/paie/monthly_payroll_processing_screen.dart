import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class MonthlyPayrollProcessingScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const MonthlyPayrollProcessingScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Traitement Paie Mensuelle',
      icon: Icons.calendar_month,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
