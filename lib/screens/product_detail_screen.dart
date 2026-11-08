import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/item_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _registerView() async {
    try {
      await ItemService.instance.incrementViews(_item.id);
    } catch (_) {}
  }

  void _addToCart() {
    CartService.instance.add(_item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Added to cart')));
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _gallery() {
    if (_photos.isEmpty) {
      return Container(
        height: 340,
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.checkroom_rounded,
              size: 64, color: AppColors.secondary),
        ),
      );
    }
    return SizedBox(
      height: 360,
      child: Stack(
        children: [
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
          if (_photos.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
          ],
          Text(text, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _sellerCard() {
    final name = _item.sellerName.isEmpty ? 'Seller' : _item.sellerName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.14),
            child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
                if (_item.sellerUsername.isNotEmpty)
                  Text('@${_item.sellerUsername}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.primary)),
              ],
            ),
          ),
          const Text('Seller',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _actions() {
    if (_isOwn) {
      return Container(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('This is your listing',
            style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    if (_item.isSold) {
      return Container(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('This item has been sold',
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
              child: OutlinedButton(
                onPressed:
                    inCart ? () => _open(const CartScreen()) : _addToCart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: AppColors.primaryDark),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: Text(inCart ? 'Go to cart' : 'Add to cart'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _open(CheckoutScreen(items: [_item])),
                child: const Text('Buy now'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Item details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _gallery(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatPrice(_item.price),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkAccent,
                      )),
                  const SizedBox(height: 4),
                  Text(_item.name,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(_item.brand, icon: Icons.sell_outlined),
                      _chip('Size ${_item.size}', icon: Icons.straighten),
                      _chip(_item.condition, icon: Icons.verified_outlined),
                      _chip(_item.category, icon: Icons.checkroom_outlined),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Description',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(_item.description,
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: AppColors.textDark)),
                  const SizedBox(height: 22),
                  Text('Sold by',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _sellerCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: _actions(),
        ),
      ),
    );
  }
}
