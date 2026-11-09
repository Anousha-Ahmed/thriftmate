import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat.dart';
import '../models/item.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/item_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/offer_sheet.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

/// One offer conversation: chat, offers, accept/decline and checkout at the
/// agreed price.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.threadId,
    required this.initial,
  });

  final String threadId;
  final ChatThread initial;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _text = TextEditingController();
  UserProfile? _profile;
  String? _busyOfferId;
  bool _sending = false;
  bool _makingOffer = false;
  bool _buying = false;

  String get _uid => AuthService.instance.currentUser?.uid ?? '';
  String get _myName {
    final fromProfile = _profile?.name;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return AuthService.instance.currentUser?.displayName ?? 'ThriftMate user';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await AuthService.instance.getProfile(user.uid);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendText(ChatThread thread) async {
    final value = _text.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendText(
        chatId: thread.id,
        senderId: _uid,
        senderName: _myName,
        text: value,
      );
      _text.clear();
    } catch (_) {
      _showMessage('Message could not be sent. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _makeOffer(ChatThread thread) async {
    if (_makingOffer) return;
    final draft = await OfferSheet.show(
      context,
      price: thread.itemPrice,
      itemName: thread.itemName,
      initialAmount: thread.itemPrice == 0
          ? null
          : (thread.itemPrice * 0.9).round(),
      title: thread.isSeller(_uid) ? 'Send a counter' : 'New offer',
      submitLabel: 'Send offer',
    );
    if (draft == null || !mounted) return;

    setState(() => _makingOffer = true);
    try {
      await ChatService.instance.sendOffer(
        chatId: thread.id,
        senderId: _uid,
        senderName: _myName,
        amount: draft.amount,
        note: draft.note,
      );
    } catch (_) {
      _showMessage('Offer could not be sent. Try again.');
    } finally {
      if (mounted) setState(() => _makingOffer = false);
    }
  }

  Future<void> _respond(
    ChatThread thread,
    ChatMessage message,
    bool accept,
  ) async {
    if (_busyOfferId != null) return;
    setState(() => _busyOfferId = message.id);
    try {
      await ChatService.instance.respondToOffer(
        chatId: thread.id,
        messageId: message.id,
        amount: message.amount ?? 0,
        accept: accept,
        responderId: _uid,
      );
    } catch (_) {
      _showMessage('Could not update the offer. Try again.');
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _buyAtDeal(ChatThread thread) async {
    final amount = thread.acceptedAmount;
    if (amount == null || _buying) return;
    setState(() => _buying = true);
    try {
      final Item? item = await ItemService.instance.getItem(thread.itemId);
      if (!mounted) return;
      if (item == null || item.isSold) {
        _showMessage('This piece is no longer available.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            items: [item],
            priceOverrides: {item.id: amount},
          ),
        ),
      );
    } catch (_) {
      _showMessage('Could not open checkout. Try again.');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _openItem(ChatThread thread) async {
    try {
      final item = await ItemService.instance.getItem(thread.itemId);
      if (!mounted) return;
      if (item == null) {
        _showMessage('This listing was removed.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(item: item)),
      );
    } catch (_) {
      _showMessage('Could not open the listing.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatThread?>(
      stream: ChatService.instance.watchThread(widget.threadId),
      builder: (context, threadSnap) {
        final thread = threadSnap.data ?? widget.initial;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.otherName(_uid).isEmpty
                      ? 'Chat'
                      : thread.otherName(_uid),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  thread.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _itemStrip(thread),
              if (thread.hasDeal) _dealBanner(thread),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: ChatService.instance.messages(thread.id),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load this chat. Check the Firestore rules for chats/messages.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snap.data!;
                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'No messages yet. Say hi or send an offer to get things started.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        return _bubble(thread, message);
                      },
                    );
                  },
                ),
              ),
              _composer(thread),
            ],
          ),
        );
      },
    );
  }

  Widget _itemStrip(ChatThread thread) {
    return GestureDetector(
      onTap: () => _openItem(thread),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.sand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checkroom_rounded,
                  size: 19, color: AppColors.forest),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    '${thread.itemBrand} · size ${thread.itemSize} · ${formatPrice(thread.itemPrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _dealBanner(ChatThread thread) {
    final int amount = thread.acceptedAmount ?? 0;
    final bool isBuyer = thread.isBuyer(_uid);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake_outlined,
              size: 20, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Deal at ${formatPrice(amount)}',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
          if (isBuyer)
            ElevatedButton(
              onPressed: _buying ? null : () => _buyAtDeal(thread),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _buying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Buy at ${formatPrice(amount)}'),
            )
          else
            Text(
              'Waiting for the buyer',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer(ChatThread thread) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _makingOffer ? null : () => _makeOffer(thread),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mustard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_offer_outlined,
                  size: 20,
                  color: AppColors.ink.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : () => _sendText(thread),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded,
                        size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatThread thread, ChatMessage message) {
    final bool mine = message.senderId == _uid;
    final bool isSeller = thread.isSeller(_uid);

    if (message.isOffer) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: AppColors.sand,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.mustard, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine
                    ? 'YOUR OFFER'
                    : '${message.senderName.toUpperCase()} OFFERED',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    formatPrice(message.amount ?? 0),
                    style: GoogleFonts.fraunces(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  _offerStatus(message),
                ],
              ),
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: AppColors.ink.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ],
              if (isSeller && message.isPending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _smallButton(
                        label: 'Decline',
                        onTap: _busyOfferId == null
                            ? () => _respond(thread, message, false)
                            : null,
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallButton(
                        label: 'Accept',
                        onTap: _busyOfferId == null
                            ? () => _respond(thread, message, true)
                            : null,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ],
              if (mine) ...[
                const SizedBox(height: 4),
                Text(
                  formatDateTime(message.createdAt ?? DateTime.now()),
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: mine ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.clay,
                  ),
                ),
              ),
            Text(
              message.text,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                height: 1.45,
                color: mine ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerStatus(ChatMessage message) {
    late final String label;
    late final Color color;
    switch (message.status) {
      case 'accepted':
        label = 'Accepted';
        color = AppColors.success;
        break;
      case 'declined':
        label = 'Declined';
        color = AppColors.error;
        break;
      default:
        label = 'Pending';
        color = AppColors.clay;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _smallButton({
    required String label,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}
