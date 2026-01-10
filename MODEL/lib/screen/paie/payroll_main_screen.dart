import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class PayrollMainScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const PayrollMainScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion de la Paie',
      icon: Icons.payments_rounded,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
