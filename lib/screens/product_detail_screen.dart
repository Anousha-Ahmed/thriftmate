import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/chat_service.dart';
import '../services/item_service.dart';
import '../services/saved_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/offer_sheet.dart';
import '../widgets/price_tag.dart';
import '../widgets/thrift_photo.dart';
import 'cart_screen.dart';
import 'chat_thread_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.item});

  final Item item;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _pageController = PageController();
  final List<Uint8List> _photos = [];
  int _page = 0;

  UserProfile? _buyer;
  bool _saved = false;
  bool _sendingOffer = false;
  bool _openingChat = false;
  StreamSubscription<Set<String>>? _savedSub;

  Item get _item => widget.item;
  bool get _isOwn => AuthService.instance.currentUser?.uid == _item.sellerId;

  @override
  void initState() {
    super.initState();
    for (final encoded in _item.images) {
      try {
        _photos.add(base64Decode(encoded));
      } catch (_) {}
    }
    if (!_isOwn) _registerView();
    _loadBuyer();
    _watchSaved();
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _registerView() async {
    try {
      await ItemService.instance.incrementViews(_item.id);
    } catch (_) {}
  }

  Future<void> _loadBuyer() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await AuthService.instance.getProfile(user.uid);
      if (mounted) setState(() => _buyer = profile);
    } catch (_) {}
  }

  void _watchSaved() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    _savedSub = SavedService.instance.watch(uid).listen(
      (ids) {
        if (mounted) setState(() => _saved = ids.contains(_item.id));
      },
      onError: (_) {},
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleSaved() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final bool next = !_saved;
    setState(() => _saved = next);
    try {
      await SavedService.instance.setSaved(
        uid: uid,
        itemId: _item.id,
        saved: next,
      );
      _showMessage(next ? 'Saved to your closet' : 'Removed from your closet');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = !next);
      _showMessage('Could not update your closet. Try again.');
    }
  }

  void _addToCart() {
    CartService.instance.add(_item);
    _showMessage('Added to cart');
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _sendOffer() async {
    final buyer = _buyer;
    if (buyer == null) {
      _showMessage('Your profile is still loading. Try again in a moment.');
      return;
    }
    if (_sendingOffer) return;

    final draft = await OfferSheet.show(
      context,
      price: _item.price,
      itemName: _item.name,
      initialAmount: (_item.price * 0.9).round().clamp(50, _item.price).toInt(),
    );
    if (draft == null || !mounted) return;

    setState(() => _sendingOffer = true);
    try {
      final chatId = await ChatService.instance.openThread(
        item: _item,
        buyer: buyer,
        amount: draft.amount,
        note: draft.note,
      );
      final thread = await ChatService.instance.getThread(chatId);
      if (!mounted) return;
      if (thread == null) {
        _showMessage('Offer sent. Open Chats to continue.');
        return;
      }
      _open(ChatThreadScreen(threadId: chatId, initial: thread));
    } on ChatException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not send the offer. Please try again.');
    } finally {
      if (mounted) setState(() => _sendingOffer = false);
    }
  }

  Future<void> _openChat() async {
    final buyer = _buyer;
    if (buyer == null) {
      _showMessage('Your profile is still loading. Try again in a moment.');
      return;
    }
    if (_openingChat) return;

    setState(() => _openingChat = true);
    try {
      final chatId = await ChatService.instance.startChat(
        item: _item,
        buyer: buyer,
      );
      final thread = await ChatService.instance.getThread(chatId);
      if (!mounted) return;
      if (thread == null) {
        _showMessage('Could not open the chat. Try again.');
        return;
      }
      _open(ChatThreadScreen(threadId: chatId, initial: thread));
    } on ChatException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not open the chat. Please try again.');
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          _gallery(),
          SliverToBoxAdapter(child: _content(context)),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _gallery() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 420,
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 62,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
        child: _circleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        if (!_isOwn)
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
            child: _circleButton(
              icon: _saved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _saved ? AppColors.clay : AppColors.ink,
              onTap: _toggleSaved,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_photos.isEmpty)
              ThriftPhoto(bytes: null, radius: 0)
            else
              PageView.builder(
                controller: _pageController,
                itemCount: _photos.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Image.memory(
                  _photos[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x66000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            if (_photos.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _photos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 20 : 7,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
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

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.ink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _item.brand.isEmpty ? 'NO BRAND' : _item.brand.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.clay,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _item.condition.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_item.name, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PriceTag(price: formatPrice(_item.price), angle: -0.04),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _isOwn
                      ? 'This is your listing'
                      : 'Ask a question or send an offer below',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 18),
          Text('The story', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _item.description.isEmpty
                ? 'The seller has not added a description yet.'
                : _item.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          _detailsGrid(),
          const SizedBox(height: 22),
          Text('Sold by', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _sellerCard(),
          const SizedBox(height: 20),
          _sellerNote(),
        ],
      ),
    );
  }

  Widget _detailsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _detailRow('Size', _item.size, 'Category', _item.category),
          const Divider(height: 20),
          _detailRow('Condition', _item.condition, 'Views', '${_item.views}'),
        ],
      ),
    );
  }

  Widget _detailRow(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l1.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.muted,
                  )),
              const SizedBox(height: 2),
              Text(v1.isEmpty ? '—' : v1,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  )),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l2.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.muted,
                  )),
              const SizedBox(height: 2),
              Text(v2.isEmpty ? '—' : v2,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sellerCard() {
    final name = _item.sellerName.isEmpty ? 'Seller' : _item.sellerName;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.sand,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.fraunces(
                fontSize: 18,
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
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (_item.sellerUsername.isNotEmpty)
                  Text(
                    '@${_item.sellerUsername}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.clay,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Seller',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerNote() {
    return Text(
      'Sold as seen. Sizes and colours can differ slightly on screens. Ask the seller anything in the chat before you buy.',
      style: GoogleFonts.dmSans(
        fontSize: 11,
        height: 1.5,
        color: AppColors.muted,
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: _actions(),
      ),
    );
  }

  Widget _actions() {
    if (_isOwn) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.storefront_rounded, size: 20, color: AppColors.forest),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Preview of your listing. Buyers see this page with Chat, Offer and Add to cart.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (_item.isSold) {
      return Container(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('This piece has been sold',
            style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }

    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final inCart = CartService.instance.contains(_item.id);
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openingChat ? null : _openChat,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: _openingChat
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Chat'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendingOffer ? null : _sendOffer,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: _sendingOffer
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_offer_outlined, size: 18),
                label: const Text('Offer'),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: inCart ? 'Go to cart' : 'Add to cart',
              child: SizedBox(
                width: 58,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(58, 54),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      inCart ? () => _open(const CartScreen()) : _addToCart,
                  child: Icon(
                    inCart
                        ? Icons.shopping_bag_rounded
                        : Icons.add_shopping_cart_rounded,
                    size: 21,
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
