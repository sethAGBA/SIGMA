import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class MultiEntityConfigurationScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const MultiEntityConfigurationScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Configuration Multi-Entités',
      icon: Icons.corporate_fare,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
