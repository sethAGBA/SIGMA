import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class IsoQualityModuleScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const IsoQualityModuleScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Module Qualité ISO',
      icon: Icons.verified,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
