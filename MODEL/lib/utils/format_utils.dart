import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Convert various DB value types (int/double/string) to double safely.
double toDoubleNum(Object? v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

/// Format epoch milliseconds (int or string) to a readable date string.
String formatDateFromEpoch(Object? v, {String locale = 'fr_FR'}) {
  if (v == null) return '—';
  try {
    final ms = (v is int) ? v : int.tryParse(v.toString());
    if (ms == null || ms <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat.yMd(locale).add_jm().format(dt);
  } catch (_) {
    return '—';
  }
}

/// Return a CircleAvatar widget: uses file image only if file exists.
Widget avatarFromPath(String path, String name, {double radius = 48}) {
  if (path.isNotEmpty) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(f));
      }
    } catch (_) {}
  }
  return CircleAvatar(radius: radius, child: Text(name.isNotEmpty ? name[0] : '?'));
}
