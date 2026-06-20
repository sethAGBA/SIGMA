import 'package:flutter/services.dart' show rootBundle;

import '../../models/plan_comptable_type.dart';

/// Charge le contenu CSV d'un plan comptable depuis les assets Flutter.
class PlanComptableLoader {
  static Future<String> load(PlanComptableType type) async {
    return rootBundle.loadString(type.assetPath);
  }
}
