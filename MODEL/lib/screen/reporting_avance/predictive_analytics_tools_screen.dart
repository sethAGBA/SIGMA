import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class PredictiveAnalyticsToolsScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const PredictiveAnalyticsToolsScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Outils d\'Analyse Prédictive',
      icon: Icons.insights,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
