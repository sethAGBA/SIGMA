import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class InventoryResourcesScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const InventoryResourcesScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Inventaire et Ressources',
      icon: Icons.inventory,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
