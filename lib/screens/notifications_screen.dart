import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_notification.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'chat_thread_screen.dart';
import 'order_tracking_screen.dart';

/// The signed-in user's in-app notifications, newest first.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.uid});

  final String uid;

  IconData _iconFor(String type) {
    switch (type) {
      case 'order':
        return Icons.local_shipping_outlined;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'offer':
        return Icons.local_offer_outlined;
      case 'review':
        return Icons.star_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Future<void> _open(BuildContext context, AppNotification n) async {
    await NotificationService.instance.markRead(n.id);
    if (!context.mounted) return;

    final orderId = n.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId),
      ));
      return;
    }

    final chatId = n.chatId;
    if (chatId != null && chatId.isNotEmpty) {
      try {
        final thread = await ChatService.instance.getThread(chatId);
        if (thread == null || !context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatThreadScreen(threadId: thread.id, initial: thread),
        ));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this chat.')),
        );
      }
    }
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: AppColors.sand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 32, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Text('Nothing yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Order updates, offers, messages and reviews will show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppNotification n) {
    return GestureDetector(
      onTap: () => _open(context, n),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: n.read ? AppColors.surface : AppColors.sand.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.read ? AppColors.line : AppColors.clay.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: n.read
                    ? AppColors.sand
                    : AppColors.clay.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(n.type), size: 19, color: AppColors.clay),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight:
                                n.read ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.clay,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    n.createdAt == null ? 'Just now' : formatDateTime(n.createdAt!),
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService.instance.myNotifications(uid),
      builder: (context, snap) {
        final list = snap.data ?? const <AppNotification>[];
        final unread = list.where((n) => !n.read).toList();

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unread.isNotEmpty)
                TextButton(
                  onPressed: () => NotificationService.instance
                      .markAllRead(unread.map((n) => n.id)),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: snap.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Could not load notifications. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : (!snap.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? _empty(context)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (context, i) => _tile(context, list[i]),
                        )),
        );
      },
    );
  }
}
