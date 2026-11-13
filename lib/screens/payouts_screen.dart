import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../models/shop_order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Seller view of earnings: what ThriftMate keeps (the platform fee), what the
/// seller receives, and which orders are ready for payout (delivered) versus
/// still in progress.
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  late final Stream<List<ShopOrder>> _orders;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _orders = uid == null
        ? Stream<List<ShopOrder>>.value(const <ShopOrder>[])
        : OrderService.instance.sellerOrders(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Earnings & payouts')),
      body: SafeArea(
        child: StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load your earnings. Try again later.'),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snap.data!;
            final delivered =
                orders.where((o) => o.status == 'delivered').toList();
            final inProgress =
                orders.where((o) => o.status != 'delivered').toList();

            final ready =
                delivered.fold<int>(0, (s, o) => s + o.sellerEarnings);
            final pending =
                inProgress.fold<int>(0, (s, o) => s + o.sellerEarnings);
            final feesPaid =
                delivered.fold<int>(0, (s, o) => s + o.platformFee);
            final feePercent = (kPlatformFeeRate * 100).round();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _summaryCard(ready: ready, pending: pending),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'Delivered orders',
                        '${delivered.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniStat(
                        'Platform fee ($feePercent%)',
                        formatPrice(feesPaid),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _howItWorks(feePercent),
                const SizedBox(height: 22),
                if (orders.isEmpty)
                  _empty()
                else ...[
                  if (delivered.isNotEmpty) ...[
                    _sectionTitle('Ready for payout'),
                    for (final o in delivered) _orderCard(o),
                  ],
                  if (inProgress.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sectionTitle('In progress'),
                    for (final o in inProgress) _orderCard(o),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard({required int ready, required int pending}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'READY FOR PAYOUT',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatPrice(ready),
            style: GoogleFonts.fraunces(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pending > 0
                ? '${formatPrice(pending)} more will be released once your open orders are delivered.'
                : 'Earnings from delivered orders, after the platform fee.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _howItWorks(int feePercent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How payouts work',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ThriftMate keeps a $feePercent% fee on each item sale. '
            'The delivery fee is not part of your earnings. '
            'Once an order is marked delivered, the rest is ready to be '
            'paid out to you.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No orders yet. When someone buys from you, your earnings will show up here.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    switch (status) {
      case 'delivered':
        color = AppColors.success;
        break;
      case 'shipped':
        color = AppColors.mustard;
        break;
      default:
        color = AppColors.muted;
    }
    final label = status.isEmpty
        ? status
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textDark : AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  Widget _orderCard(ShopOrder o) {
    final feePercent = (kPlatformFeeRate * 100).round();
    final when = o.deliveredAt ?? o.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                child: Text(
                  'Order #${o.shortId}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _statusChip(o.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            o.itemsSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          if (when != null)
            Text(
              formatDateTime(when),
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          const Divider(height: 18, color: AppColors.border),
          _line('Item sale', formatPrice(o.subtotal)),
          _line('Platform fee ($feePercent%)', '- ${formatPrice(o.platformFee)}'),
          _line('You receive', formatPrice(o.sellerEarnings), bold: true),
          const SizedBox(height: 4),
          Text(
            o.paymentLabel,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
