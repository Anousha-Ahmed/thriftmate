import 'package:flutter/material.dart';
import '../config/stripe_config.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/thrift_photo.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Widget _row(BuildContext context, Item item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            height: 88,
            child: ThriftPhoto(bytes: item.coverBytes, radius: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (item.brand.isNotEmpty) item.brand,
                    'Size ${item.size}',
                    item.condition,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatPrice(item.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Remove from cart',
                visualDensity: VisualDensity.compact,
                onPressed: () => CartService.instance.remove(item.id),
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textDark : AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.sand,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text('Your cart is empty',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Swipe through Discover or browse the closet —\nadd the pieces you love here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep browsing'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My cart')),
      body: ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final items = CartService.instance.items;
          if (items.isEmpty) return _empty(context);

          final subtotal = CartService.instance.subtotal;
          final delivery = deliveryFeeFor(items);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? 'piece' : 'pieces'} · one of a kind',
                      style: const TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final i in items) _row(context, i),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _summaryLine('Subtotal', formatPrice(subtotal)),
                      _summaryLine('Delivery', formatPrice(delivery)),
                      const Divider(height: 20, color: AppColors.border),
                      _summaryLine('Total', formatPrice(subtotal + delivery),
                          bold: true),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CheckoutScreen(items: items),
                          ));
                        },
                        child: const Text('Checkout'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stripeConfigured
                            ? 'Cash on delivery or card at checkout'
                            : 'Cash on delivery at checkout',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
