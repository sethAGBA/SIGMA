// lib/models/menu_item.dart
import 'package:flutter/material.dart';

class MenuItem {
  final IconData icon;
  final String title;
  final LinearGradient gradient;
  final List<MenuItem>? children; // New property for sub-menu items

  MenuItem({
    required this.icon,
    required this.title,
    required this.gradient,
    this.children, // Make it optional
  });
}