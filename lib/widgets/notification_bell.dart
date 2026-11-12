import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/notifications_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Bell icon with a live unread badge. Opens the notifications list.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.uid,
    this.color = AppColors.ink,
  });

  final String uid;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCount(uid),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(uid: uid),
                ),
              ),
              icon: Icon(Icons.notifications_none_rounded, color: color, size: 25),
            ),
            if (unread > 0)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surface, width: 1.4),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
