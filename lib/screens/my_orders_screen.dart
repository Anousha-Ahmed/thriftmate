import 'package:flutter/material.dart';
import '../models/shop_order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/order_status_chip.dart';
import 'order_tracking_screen.dart';

/// The buyer's orders, split into Pending / Shipped / Delivered.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late final Stream<List<ShopOrder>> _stream;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _stream = uid == null
        ? Stream<List<ShopOrder>>.value(const <ShopOrder>[])
        : OrderService.instance.buyerOrders(uid);
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 44, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _card(ShopOrder order) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.shortId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  if (order.createdAt != null)
                    Text(formatDateTime(order.createdAt!),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Text(order.itemsSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Text(formatPrice(order.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkAccent)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                OrderStatusChip(status: order.status),
                const SizedBox(height: 22),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<ShopOrder> orders, String emptyTitle) {
    if (orders.isEmpty) {
      return _empty(emptyTitle, 'Your orders will show up here.');
    }
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
              title: const Text('My Orders'),
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
                ? _empty('Could not load orders',
                    'Check your internet connection and try again.')
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
