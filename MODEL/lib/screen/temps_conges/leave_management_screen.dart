import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class LeaveManagementScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const LeaveManagementScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Gestion des Congés',
      icon: Icons.beach_access,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
