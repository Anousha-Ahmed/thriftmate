import 'package:flutter/material.dart';
import '../models/review.dart';
import '../models/shop_order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/star_rating.dart';

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
                    : o.paidByCard
                        ? 'Payment received by card'
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
              _line('Total (${o.paidByCard ? 'paid by card' : 'cash on delivery'})',
                  formatPrice(o.total), bold: true),
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
        _ReviewSection(order: o),
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

/// Shown to the buyer once the order is delivered: leave a 1-5 star review.
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.order});

  final ShopOrder order;

  Future<void> _rate(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _ReviewSheet(order: order),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Thanks for rating the seller.')));
    }
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

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid != order.buyerId || order.status != 'delivered') {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Review?>(
      stream: ReviewService.instance.watchOrderReview(order.id),
      builder: (context, snap) {
        final review = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Text('Seller rating',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _box(
              child: review == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How was your order?',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 4),
                        Text(
                          'Rate ${order.sellerName} from 1 to 5 stars. Your review helps other buyers.',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _rate(context),
                          icon: const Icon(Icons.star_outline_rounded, size: 19),
                          label: const Text('Rate seller'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StarRating(
                                rating: review.rating.toDouble(), size: 19),
                            const SizedBox(width: 8),
                            Text('${review.rating}/5',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        if (review.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(review.text),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          review.createdAt == null
                              ? 'You rated this order'
                              : 'You rated this order · ${formatDateTime(review.createdAt!)}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.order});

  final ShopOrder order;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _text = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  static const _words = {
    1: 'Not great',
    2: 'Could be better',
    3: 'Okay',
    4: 'Good',
    5: 'Excellent',
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ReviewService.instance.addReview(
        order: widget.order,
        buyerId: uid,
        buyerName: widget.order.buyerName,
        rating: _rating,
        text: _text.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Could not save your rating. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Rate ${widget.order.sellerName}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.order.itemsSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Center(
                child: StarRating(
                  rating: _rating.toDouble(),
                  size: 42,
                  onChanged: (value) => setState(() => _rating = value),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _words[_rating] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.clay),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Condition, packaging, delivery — anything other buyers should know (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Submit rating'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
