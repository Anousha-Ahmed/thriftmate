import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'chat_thread_screen.dart';

/// All offer conversations for the signed-in user.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Negotiations', style: Theme.of(context).textTheme.bodyMedium),
                Text('Chats', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatThread>>(
              stream: ChatService.instance.myThreads(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _state(
                    context,
                    icon: Icons.forum_outlined,
                    title: 'Could not load chats',
                    message:
                        'If this keeps happening, check the Firestore rules for the chats collection.',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final threads = snap.data!;
                if (threads.isEmpty) {
                  return _state(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No offers yet',
                    message:
                        'Open any piece and tap "Chat" or "Offer" to start a conversation. Your threads will live here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: threads.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _tile(context, threads[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, ChatThread thread) {
    final String myUid = AuthService.instance.currentUser?.uid ?? '';
    final bool seller = thread.isSeller(myUid);
    final String name = thread.otherName(myUid);
    final String initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final DateTime? at = thread.lastAt ?? thread.createdAt;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              threadId: thread.id,
              initial: thread,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.sand,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (at != null)
                        Text(
                          formatDateTime(at),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${seller ? 'Buyer' : 'Seller'} · ${thread.itemName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: AppColors.clay,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage.isEmpty
                              ? 'Say hi or send an offer'
                              : thread.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      if (thread.hasDeal)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Deal',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _state(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: AppColors.sand,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
