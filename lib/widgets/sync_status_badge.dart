// lib/widgets/sync_status_badge.dart
//
// Badge de statut de synchronisation affiché dans l'AppBar.
// Écoute ConnectivityMonitor().statusNotifier et affiche un badge visuel
// avec compteur des opérations en attente.

import 'package:flutter/material.dart';
import '../core/services/connectivity_monitor.dart';
import '../core/services/sync_service.dart';
import '../screens/sync/sync_supervisor_screen.dart';

class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  // Couleurs selon la spec
  static const Color _green = Color(0xFF4CAF50);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _red = Color(0xFFF44336);

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Démarrer / arrêter l'animation selon le statut courant
    ConnectivityMonitor().statusNotifier.addListener(_onStatusChanged);
    _syncAnimationWithStatus(ConnectivityMonitor().statusNotifier.value);
  }

  @override
  void dispose() {
    ConnectivityMonitor().statusNotifier.removeListener(_onStatusChanged);
    _rotationController.dispose();
    super.dispose();
  }

  void _onStatusChanged() {
    _syncAnimationWithStatus(ConnectivityMonitor().statusNotifier.value);
  }

  void _syncAnimationWithStatus(ConnectivityStatus status) {
    if (status == ConnectivityStatus.syncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  void _navigateToSupervisor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SyncSupervisorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectivityStatus>(
      valueListenable: ConnectivityMonitor().statusNotifier,
      builder: (context, status, _) {
        return FutureBuilder<int>(
          future: SyncService().getPendingCount(),
          builder: (context, snapshot) {
            final pendingCount = snapshot.data ?? 0;
            return GestureDetector(
              onTap: _navigateToSupervisor,
              child: _buildBadge(context, status, pendingCount),
            );
          },
        );
      },
    );
  }

  Widget _buildBadge(
    BuildContext context,
    ConnectivityStatus status,
    int pendingCount,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showLabel = screenWidth >= 800;

    final _BadgeConfig config = _resolveConfig(status, pendingCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(status, config.color),
              if (showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: config.color,
                  ),
                ),
              ],
            ],
          ),
          // Badge numérique superposé en haut à droite
          if (config.showBadge && pendingCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                decoration: BoxDecoration(
                  color: config.badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  pendingCount > 99 ? '99+' : '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon(ConnectivityStatus status, Color color) {
    if (status == ConnectivityStatus.syncing) {
      return RotationTransition(
        turns: _rotationController,
        child: Icon(Icons.sync, size: 18, color: color),
      );
    }
    final IconData icon = status == ConnectivityStatus.online
        ? Icons.wifi
        : Icons.wifi_off;
    return Icon(icon, size: 18, color: color);
  }

  _BadgeConfig _resolveConfig(ConnectivityStatus status, int pendingCount) {
    switch (status) {
      case ConnectivityStatus.online:
        if (pendingCount == 0) {
          return _BadgeConfig(
            color: _green,
            label: 'En ligne',
            showBadge: false,
            badgeColor: _orange,
          );
        } else {
          return _BadgeConfig(
            color: _orange,
            label: 'En ligne',
            showBadge: true,
            badgeColor: _orange,
          );
        }
      case ConnectivityStatus.offline:
        return _BadgeConfig(
          color: _red,
          label: 'Hors ligne',
          showBadge: pendingCount > 0,
          badgeColor: _red,
        );
      case ConnectivityStatus.syncing:
        return _BadgeConfig(
          color: _orange,
          label: 'Sync\u2026',
          showBadge: false,
          badgeColor: _orange,
        );
    }
  }
}

/// Données de configuration visuelle pour un état donné.
class _BadgeConfig {
  final Color color;
  final String label;
  final bool showBadge;
  final Color badgeColor;

  const _BadgeConfig({
    required this.color,
    required this.label,
    required this.showBadge,
    required this.badgeColor,
  });
}
