import 'package:flutter/material.dart';
import 'package:afroforma/services/notification_service.dart';

class NotificationCard extends StatefulWidget {
  final NotificationItem item;
  final VoidCallback? onDismissed;

  const NotificationCard({Key? key, required this.item, this.onDismissed}) : super(key: key);

  @override
  _NotificationCardState createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressBarAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.item.duration,
    );
    _progressBarAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
    // start the progress animation
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        if (_dismissed) return;
        _dismissed = true;
        try {
          widget.onDismissed?.call();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Static card with a single progress bar animation
    return Dismissible(
      key: Key(widget.item.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        widget.onDismissed?.call();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360, minWidth: 140),
        height: (widget.item.details != null && widget.item.details!.isNotEmpty) ? 72 : 56,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.item.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item.details != null && widget.item.details!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            widget.item.details!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Action buttons
                if (widget.item.onAction != null && widget.item.actionLabel != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      try {
                        widget.item.onAction?.call();
                      } catch (_) {}
                      if (!_dismissed) {
                        _dismissed = true;
                        _controller.stop();
                        widget.onDismissed?.call();
                      }
                    },
                    child: Text(
                      widget.item.actionLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                if (widget.item.onUndo != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        try {
                          widget.item.onUndo?.call();
                        } catch (_) {}
                        if (!_dismissed) {
                          _dismissed = true;
                          _controller.stop();
                          widget.onDismissed?.call();
                        }
                      },
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                // Close icon
                GestureDetector(
                  onTap: () {
                    if (!_dismissed) {
                      _dismissed = true;
                      _controller.stop();
                      widget.onDismissed?.call();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close, color: Colors.white.withOpacity(0.8), size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 4,
              child: AnimatedBuilder(
                animation: _progressBarAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressBarAnimation.value,
                    backgroundColor: widget.item.progressColor.withOpacity(0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.item.progressColor),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
