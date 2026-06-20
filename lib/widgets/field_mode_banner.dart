// lib/widgets/field_mode_banner.dart

import 'package:flutter/material.dart';
import '../core/services/field_mode_service.dart';

class FieldModeBanner extends StatefulWidget {
  const FieldModeBanner({super.key});

  @override
  State<FieldModeBanner> createState() => _FieldModeBannerState();
}

class _FieldModeBannerState extends State<FieldModeBanner> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    FieldModeService().activeNotifier.addListener(_onActiveChange);
    FieldModeService().refreshActiveState();
  }

  @override
  void dispose() {
    FieldModeService().activeNotifier.removeListener(_onActiveChange);
    super.dispose();
  }

  void _onActiveChange() {
    if (mounted) setState(() => _active = FieldModeService().activeNotifier.value);
  }

  Future<void> _refresh() async {
    await FieldModeService().refreshActiveState();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hiking_rounded, size: 14, color: Colors.orange),
          SizedBox(width: 6),
          Text(
            'Mode terrain',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
