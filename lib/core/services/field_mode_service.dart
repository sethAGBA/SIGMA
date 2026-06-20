// lib/core/services/field_mode_service.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../models/field_snapshot_meta_model.dart';
import '../../models/loan_request_model.dart';
import 'auth_service.dart';
import 'client_api_service.dart';
import 'database_service.dart';
import 'loan_api_service.dart';
import 'sync_service.dart';

class FieldSnapshotResult {
  final bool success;
  final bool usedCache;
  final int clientCount;
  final int scheduleCount;
  final int requestCount;
  final String? errorMessage;

  const FieldSnapshotResult({
    required this.success,
    this.usedCache = false,
    this.clientCount = 0,
    this.scheduleCount = 0,
    this.requestCount = 0,
    this.errorMessage,
  });
}

class FieldModeService {
  static final FieldModeService _instance = FieldModeService._internal();
  factory FieldModeService() => _instance;
  FieldModeService._internal();

  final ValueNotifier<bool> activeNotifier = ValueNotifier(false);

  Future<void> refreshActiveState() async {
    activeNotifier.value = await isFieldModeActive;
  }

  Future<bool> get isFieldModeActive async {
    final agentId = AuthService().currentUsername;
    if (agentId.isEmpty) return false;
    final today = await DatabaseService().getTodaySnapshotForAgent(agentId);
    return today != null;
  }

  Future<DateTime?> getLastSnapshotDate() async {
    final agentId = AuthService().currentUsername;
    if (agentId.isEmpty) return null;
    final last = await DatabaseService().getLastSnapshotForAgent(agentId);
    return last?.createdAt;
  }

  Future<FieldSnapshotResult> prepareMorningSnapshot() async {
    final agentId = AuthService().currentUsername;
    if (agentId.isEmpty) {
      return const FieldSnapshotResult(
        success: false,
        errorMessage: 'Utilisateur non connecté.',
      );
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final online = await SyncService().isOnline;

    if (!online) {
      final last = await DatabaseService().getLastSnapshotForAgent(agentId);
      if (last != null &&
          DateTime.now().difference(last.createdAt).inHours < 24) {
        await refreshActiveState();
        return FieldSnapshotResult(
          success: true,
          usedCache: true,
          clientCount: last.clientCount,
          scheduleCount: last.scheduleCount,
          requestCount: last.requestCount,
        );
      }
      return const FieldSnapshotResult(
        success: false,
        errorMessage:
            'Serveur indisponible — impossible de préparer la tournée. '
            'Reconnectez-vous au réseau ou utilisez un snapshot de moins de 24 h.',
      );
    }

    try {
      final clients = await ClientApiService().searchClients(limit: 500);
      final schedules = await LoanApiService().getPendingSchedules();
      final requests = await LoanApiService().getLoanRequests();
      final activeRequests = requests
          .where(
            (r) =>
                r.statut != LoanRequestStatus.debloquee &&
                r.statut != LoanRequestStatus.rejetee,
          )
          .toList();

      await DatabaseService().insertFieldSnapshotMeta(
        FieldSnapshotMeta(
          agentId: agentId,
          snapshotDate: today,
          createdAt: DateTime.now(),
          clientCount: clients.length,
          scheduleCount: schedules.length,
          requestCount: activeRequests.length,
        ),
      );

      return FieldSnapshotResult(
        success: true,
        clientCount: clients.length,
        scheduleCount: schedules.length,
        requestCount: activeRequests.length,
      );
    } catch (e) {
      return FieldSnapshotResult(
        success: false,
        errorMessage: 'Erreur lors de la préparation : $e',
      );
    } finally {
      await refreshActiveState();
    }
  }
}
