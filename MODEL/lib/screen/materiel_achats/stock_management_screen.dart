import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class StockManagementScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const StockManagementScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion des Stocks',
      icon: Icons.warehouse,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
