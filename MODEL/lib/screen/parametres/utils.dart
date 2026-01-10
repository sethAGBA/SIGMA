import '../../models/user.dart';
import 'package:flutter/material.dart';



String getUserRoleString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.comptable:
      return 'Comptable';
    case UserRole.commercial:
      return 'Commercial';
    case UserRole.secretaire:
      return 'Secrétaire';
  }
}

Color getRoleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const Color(0xFF6366F1);
    case UserRole.comptable:
      return const Color(0xFF10B981);
    case UserRole.commercial:
      return const Color(0xFFF59E0B);
    case UserRole.secretaire:
      return const Color(0xFF06B6D4);
  }
}

String formatDate(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
