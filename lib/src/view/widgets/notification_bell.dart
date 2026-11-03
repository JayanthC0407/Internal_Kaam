import 'package:flutter/material.dart';

import 'package:demo_bank/src/core/theme/app_colors.dart';

/// The header bell with OBDX's red unread bubble (`oj-badge-danger` over
/// `icon-on-screen-alerts`): the count of unread mails, alerts and
/// notifications, hidden at zero, "99+" above 99. Shared by the web top
/// bar and the phone headers so they show the same thing.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.count,
    required this.color,
    this.onTap,
    this.size = 20,
    this.padding = const EdgeInsets.all(8),
    this.tooltip = 'Notifications',
  });

  final int count;
  final Color color;
  final VoidCallback? onTap;
  final double size;
  final EdgeInsetsGeometry padding;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final big = size >= 24;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: padding,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_rounded, size: size, color: color),
              if (count > 0)
                Positioned(
                  right: big ? -6 : -5,
                  top: big ? -5 : -4,
                  child: UnreadCountBadge(count: count, large: big),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The red count bubble itself.
class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({super.key, required this.count, this.large = false});

  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$count unread',
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: large ? 5 : 4, vertical: 1),
          constraints: BoxConstraints(minWidth: large ? 17 : 14),
          decoration: BoxDecoration(
            color: AppColors.of(context).error,
            borderRadius: BorderRadius.circular(9),
            // Keeps the bubble readable where it overlaps the bell.
            border: large ? Border.all(color: AppColors.of(context).cardBg, width: 1.5) : null,
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: large ? 10 : 9, height: 1.3, fontWeight: FontWeight.w700),
          ),
        ),
      );
}
