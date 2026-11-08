import 'package:flutter/material.dart';
import '../models/shop_order.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/order_status_chip.dart';

/// Live order tracking: Order placed -> Shipped -> Delivered.
/// It listens to the order document, so when the seller updates the
/// status the buyer sees the timeline move without refreshing.
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  Widget _step({
    required String title,
    required String subtitle,
    required bool done,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.primary : AppColors.fill,
                  border: Border.all(
                      color: done ? AppColors.primary : AppColors.border,
                      width: 1.6),
                ),
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: done ? AppColors.textDark : AppColors.textMuted,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 15.5 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textDark : AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ShopOrder o) {
    final shipped = o.status == 'shipped' || o.status == 'delivered';
    final delivered = o.status == 'delivered';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Order #${o.shortId}',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            OrderStatusChip(status: o.status),
          ],
        ),
        const SizedBox(height: 18),

        _box(
          child: Column(
            children: [
              _step(
                title: 'Order placed',
                subtitle: o.createdAt == null
                    ? 'Just now'
                    : formatDateTime(o.createdAt!),
                done: true,
                isLast: false,
              ),
              _step(
                title: 'Shipped',
                subtitle: shipped && o.shippedAt != null
                    ? formatDateTime(o.shippedAt!)
                    : 'Waiting for the seller to ship',
                done: shipped,
                isLast: false,
              ),
              _step(
                title: 'Delivered',
                subtitle: delivered && o.deliveredAt != null
                    ? formatDateTime(o.deliveredAt!)
                    : 'Pay cash when it arrives',
                done: delivered,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text('Items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _box(
          child: Column(
            children: [
              for (final l in o.lines)
                _line('${l.name} (Size ${l.size})', formatPrice(l.price)),
              const Divider(color: AppColors.border),
              _line('Subtotal', formatPrice(o.subtotal)),
              _line('Delivery', formatPrice(o.deliveryFee)),
              const Divider(color: AppColors.border),
              _line('Total (cash on delivery)', formatPrice(o.total),
                  bold: true),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text('Delivery details',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _box(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.shipping.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(o.shipping.phone,
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Text('${o.shipping.address}, ${o.shipping.city}'),
              const Divider(height: 22, color: AppColors.border),
              Text(
                'Sold by ${o.sellerName}${o.sellerUsername.isEmpty ? '' : ' (@${o.sellerUsername})'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Track order')),
      body: StreamBuilder<ShopOrder?>(
        stream: OrderService.instance.watchOrder(orderId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load this order.'));
          }
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snap.data;
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }
          return _body(context, order);
        },
      ),
    );
  }
}
