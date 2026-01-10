
import 'package:flutter/material.dart';
import 'dart:async';

class NotificationItem {
  final String id;
  final String message;
  final String? details;
  final VoidCallback? onUndo;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Duration duration;
  final Color backgroundColor;
  final Color progressColor;

  NotificationItem({
    required this.id,
    required this.message,
    this.details,
    this.onUndo,
    this.onAction,
    this.actionLabel,
    this.duration = const Duration(seconds: 5),
    this.backgroundColor = Colors.blueGrey,
    this.progressColor = Colors.white,
  });
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  void showNotification(NotificationItem item) {
    _notifications.add(item);
    notifyListeners();
    _startTimer(item);
  }

  void removeNotification(String id) {
    _notifications.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void _startTimer(NotificationItem item) {
    Timer(item.duration, () {
      if (_notifications.contains(item)) {
        removeNotification(item.id);
      }
    });
  }
}

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({Key? key, required this.child}) : super(key: key);

  @override
  _NotificationOverlayState createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
  return widget.child;
  }
}

