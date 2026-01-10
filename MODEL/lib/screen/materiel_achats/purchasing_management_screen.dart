import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class PurchasingManagementScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const PurchasingManagementScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion des Achats',
      icon: Icons.shopping_cart,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
