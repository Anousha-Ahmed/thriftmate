import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/order_status_chip.dart';

/// Orders received by a seller. The seller moves each order forward:
/// Pending -> Shipped -> Delivered.
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  late final Stream<List<ShopOrder>> _stream;
  final Set<String> _updating = <String>{};

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _stream = uid == null
        ? Stream<List<ShopOrder>>.value(const <ShopOrder>[])
        : OrderService.instance.sellerOrders(uid);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _advance(ShopOrder order) async {
    final next = order.status == 'pending' ? 'shipped' : 'delivered';
    setState(() => _updating.add(order.id));
    try {
      await OrderService.instance.updateStatus(order.id, next);
      _showMessage(next == 'shipped'
          ? 'Order marked as shipped'
          : 'Order marked as delivered');
    } catch (_) {
      _showMessage('Could not update the order. Try again.');
    } finally {
      if (mounted) setState(() => _updating.remove(order.id));
    }
  }

  Widget _empty(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 44, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Orders from buyers will appear here.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _card(ShopOrder o) {
    final busy = _updating.contains(o.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Order #${o.shortId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              OrderStatusChip(status: o.status),
            ],
          ),
          if (o.createdAt != null)
            Text(formatDateTime(o.createdAt!),
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          for (final l in o.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${l.name} (Size ${l.size})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                  Text(formatPrice(l.price),
                      style: const TextStyle(fontSize: 13.5)),
                ],
              ),
            ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${o.shipping.name} · ${o.shipping.phone}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${o.shipping.address}, ${o.shipping.city}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You receive ${formatPrice(o.sellerEarnings)} after ${(kPlatformFeeRate * 100).round()}% fee · Cash on delivery',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (o.status != 'delivered') ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: busy ? null : () => _advance(o),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(o.status == 'pending'
                      ? 'Mark as shipped'
                      : 'Mark as delivered'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(List<ShopOrder> orders, String emptyTitle) {
    if (orders.isEmpty) return _empty(emptyTitle);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: orders.length,
      itemBuilder: (context, i) => _card(orders[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShopOrder>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <ShopOrder>[];
        final pending = all.where((o) => o.status == 'pending').toList();
        final shipped = all.where((o) => o.status == 'shipped').toList();
        final delivered = all.where((o) => o.status == 'delivered').toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Orders received'),
              bottom: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Pending (${pending.length})'),
                  Tab(text: 'Shipped (${shipped.length})'),
                  Tab(text: 'Delivered (${delivered.length})'),
                ],
              ),
            ),
            body: snap.hasError
                ? _empty('Could not load orders')
                : !snap.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          _list(pending, 'No pending orders'),
                          _list(shipped, 'No shipped orders'),
                          _list(delivered, 'No delivered orders'),
                        ],
                      ),
          ),
        );
      },
    );
  }
}
