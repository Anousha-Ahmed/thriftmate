import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../models/review.dart';
import '../models/shop_order.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/order_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/format.dart';
import '../utils/role_router.dart';
import '../widgets/notification_bell.dart';
import '../widgets/sales_chart.dart';
import '../widgets/star_rating.dart';
import 'add_edit_item_screen.dart';
import 'home_screen.dart';
import 'my_listings_screen.dart';
import 'payouts_screen.dart';
import 'profile_screen.dart';
import 'seller_orders_screen.dart';

/// Seller mode home: shop stats, pending orders and quick actions.
/// Used as a tab in the seller shell ([embedded]) or as its own page.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late final Stream<List<Item>> _items;
  late final Stream<List<ShopOrder>> _orders;
  UserProfile? _profile;
  String? _uid;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _uid = uid;
    _items = uid == null
        ? Stream<List<Item>>.value(const <Item>[])
        : ItemService.instance.sellerItems(uid);
    _orders = uid == null
        ? Stream<List<ShopOrder>>.value(const <ShopOrder>[])
        : OrderService.instance.sellerOrders(uid);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await AuthService.instance.getProfile(user.uid);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  void _go(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<Item>>(
      stream: _items,
      builder: (context, itemSnap) {
        return StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, orderSnap) {
            if (itemSnap.hasError || orderSnap.hasError) {
              return _error();
            }
            if (!itemSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = itemSnap.data!;
            final orders = orderSnap.data ?? const <ShopOrder>[];
            final active = items.where((i) => !i.isSold).toList();
            final sold = items.where((i) => i.isSold).toList();
            final pending = orders.where((o) => o.status == 'pending').length;
            final earned = sold.fold<int>(0, (s, i) => s + i.sellerEarnings);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                widget.embedded ? 14 : 4,
                20,
                widget.embedded ? 100 : 28,
              ),
              children: [
                _header(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Active listings',
                        value: '${active.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: Icons.check_circle_outline,
                        label: 'Items sold',
                        value: '${sold.length}',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Earned',
                        value: formatPrice(earned),
                        note: 'after ${(kPlatformFeeRate * 100).round()}% fee',
                        color: AppColors.clay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: Icons.local_shipping_outlined,
                        label: 'Pending orders',
                        value: '$pending',
                        note: pending == 0 ? 'nothing to ship' : 'to ship',
                        color: AppColors.mustard,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_uid == null)
                  _analyticsCard(orders, const <Review>[])
                else
                  StreamBuilder<List<Review>>(
                    stream: ReviewService.instance.sellerReviews(_uid!),
                    builder: (context, reviewSnap) => _analyticsCard(
                      orders,
                      reviewSnap.data ?? const <Review>[],
                    ),
                  ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => _go(const AddEditItemScreen()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Post a new find'),
                ),
                const SizedBox(height: 24),
                Text('Quick actions',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.local_shipping_outlined,
                        title: 'Orders received',
                        subtitle: pending == 0
                            ? 'No pending orders'
                            : '$pending ${pending == 1 ? 'order' : 'orders'} to ship',
                        badge: pending,
                        onTap: () => _go(const SellerOrdersScreen()),
                      ),
                      const Divider(height: 1),
                      _tile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Earnings & payouts',
                        subtitle: 'What you earn after the platform fee',
                        onTap: () => _go(const PayoutsScreen()),
                      ),
                      const Divider(height: 1),
                      _tile(
                        icon: Icons.list_alt_outlined,
                        title: 'My listings',
                        subtitle: 'Edit, delete or mark items as sold',
                        onTap: () => _go(const MyListingsScreen()),
                      ),
                      const Divider(height: 1),
                      _tile(
                        icon: Icons.explore_outlined,
                        title: 'Browse marketplace',
                        subtitle: 'See what other sellers are listing',
                        onTap: () => _go(const HomeScreen()),
                      ),
                      const Divider(height: 1),
                      _tile(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Switch to buying',
                        subtitle: 'Shop as a buyer with this same account',
                        onTap: () => switchMode(context, 'buyer'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Recent listings',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () => _go(const MyListingsScreen()),
                        child: const Text('See all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _recent(items),
              ],
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return SafeArea(bottom: false, child: body);
    }
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Seller dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => _go(const ProfileScreen(role: 'seller')),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Seller mode',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'YOUR SHOP',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.forest,
                ),
              ),
            ),
            const SizedBox(width: 4),
            NotificationBell(uid: _uid ?? ''),
          ],
        ),
        Text('Your shop', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          _profile == null || _profile!.firstName.isEmpty
              ? 'Manage your rack, orders and buyers.'
              : 'Hi ${_profile!.firstName}, manage your rack, orders and buyers.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    String? note,
    Color color = AppColors.forest,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
          if (note != null)
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.sand,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: AppColors.forest),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$badge',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _analyticsCard(List<ShopOrder> orders, List<Review> reviews) {
    final days = last7DaysSales(orders);
    final weekOrders = days.fold<int>(0, (sum, d) => sum + d.orders);
    final weekRevenue = days.fold<int>(0, (sum, d) => sum + d.revenue);
    final double average = averageRating(reviews);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Last 7 days',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$weekOrders ${weekOrders == 1 ? 'order' : 'orders'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${formatPrice(weekRevenue)} in sales',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          SalesChart(days: days),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              if (reviews.isEmpty) ...[
                const Icon(Icons.star_border_rounded,
                    size: 17, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No ratings yet — delivered buyers can rate you.',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ] else ...[
                StarRating(rating: average, size: 15),
                const SizedBox(width: 7),
                Text(
                  '${ratingLabel(average)} · ${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _recent(List<Item> items) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            const Icon(Icons.storefront_outlined,
                size: 34, color: AppColors.muted),
            const SizedBox(height: 8),
            Text('No listings yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Post your first thrift find to start selling.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [for (final i in items.take(3)) _recentRow(i)],
      ),
    );
  }

  Widget _recentRow(Item item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      onTap: () => _go(const MyListingsScreen()),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: item.coverBytes == null
            ? Container(
                width: 46,
                height: 46,
                color: AppColors.sand,
                child: const Icon(Icons.checkroom_rounded,
                    color: AppColors.muted, size: 20),
              )
            : Image.memory(item.coverBytes!,
                width: 46, height: 46, fit: BoxFit.cover),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      subtitle: Text(
        '${item.views} views · ${formatPrice(item.price)}',
        style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: item.isSold
              ? AppColors.sand
              : AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.isSold ? 'Sold' : 'Active',
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: item.isSold ? AppColors.muted : AppColors.success,
          ),
        ),
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'Could not load your shop',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Check your internet connection and pull again.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
