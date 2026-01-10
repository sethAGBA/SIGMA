import 'package:flutter/material.dart';
import 'package:afroforma/screen/parametres_etendus/multi_entity_configuration_screen.dart';

class ParametresEtendusTab extends StatelessWidget {
  const ParametresEtendusTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provide a stopped animation so the reused screen can accept a fadeAnimation
    final animation = AlwaysStoppedAnimation<double>(1.0);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: MultiEntityConfigurationScreen(fadeAnimation: animation, gradient: const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF0D9488)])),
    );
  }
}
