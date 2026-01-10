import 'package:flutter/material.dart';
import 'package:afroforma/widgets/coming_soon_widget.dart';

class TimeTrackingAttendanceScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Gradient gradient;

  const TimeTrackingAttendanceScreen({super.key, required this.fadeAnimation, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Pointage et Présences',
      icon: Icons.fingerprint,
      fadeAnimation: fadeAnimation,
      gradient: gradient,
    );
  }
}
