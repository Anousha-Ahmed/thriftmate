import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Widget _row(BuildContext context, Item item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.coverBytes == null
                ? Container(
                    width: 72,
                    height: 72,
                    color: AppColors.background,
                    child: const Icon(Icons.checkroom_rounded,
                        color: AppColors.secondary),
                  )
                : Image.memory(item.coverBytes!,
                    width: 72, height: 72, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text('${item.brand} · Size ${item.size}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(formatPrice(item.price),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkAccent)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => CartService.instance.remove(item.id),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Cart')),
      body: ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final items = CartService.instance.items;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 48, color: AppColors.secondary),
                    const SizedBox(height: 12),
                    Text('Your cart is empty',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Found something you like? Add it here.',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Browse items'),
                    ),
                  ],
                ),
              ),
            );
          }

          final subtotal = CartService.instance.subtotal;
          final delivery = deliveryFeeFor(items);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [for (final i in items) _row(context, i)],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
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
                      const Divider(color: AppColors.border),
                      _summaryLine('Total', formatPrice(subtotal + delivery),
                          bold: true),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CheckoutScreen(items: items),
                          ));
                        },
                        child: const Text('Checkout'),
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
