import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/shop_order.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/role_router.dart';
import 'add_edit_item_screen.dart';
import 'home_screen.dart';
import 'my_listings_screen.dart';
import 'seller_orders_screen.dart';
import 'profile_screen.dart';

/// What a seller sees after login: shop stats and quick actions.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late final Stream<List<Item>> _stream;
  late final Stream<List<ShopOrder>> _ordersStream;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _stream = uid == null
        ? Stream<List<Item>>.value(const <Item>[])
        : ItemService.instance.sellerItems(uid);
    _ordersStream = uid == null
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

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    String? note,
    Color color = AppColors.primary,
  }) {
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
          Container(
            padding: const EdgeInsets.all(8),
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted)),
          if (note != null)
            Text(note,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _ordersTile() {
    return StreamBuilder<List<ShopOrder>>(
      stream: _ordersStream,
      builder: (context, snap) {
        final pending =
            (snap.data ?? const <ShopOrder>[]).where((o) => o.status == 'pending').length;
        return ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading:
              const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
          title: const Text('Orders received'),
          subtitle: Text(
            pending == 0
                ? 'No pending orders'
                : '$pending pending ${pending == 1 ? 'order' : 'orders'} to ship',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: pending == 0
              ? const Icon(Icons.chevron_right, color: AppColors.textMuted)
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.darkAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
          onTap: () => _go(const SellerOrdersScreen()),
        );
      },
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
                width: 48,
                height: 48,
                color: AppColors.background,
                child: const Icon(Icons.checkroom_rounded,
                    color: AppColors.secondary),
              )
            : Image.memory(item.coverBytes!,
                width: 48, height: 48, fit: BoxFit.cover),
      ),
      title: Text(item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(formatPrice(item.price),
          style: const TextStyle(
              color: AppColors.darkAccent, fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: item.isSold
              ? AppColors.accent.withValues(alpha: 0.5)
              : const Color(0xFF2E9E5B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.isSold ? 'Sold' : 'Active',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: item.isSold
                ? AppColors.textDark
                : const Color(0xFF2E9E5B),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (kPlatformFeeRate * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Seller dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => _go(const ProfileScreen()),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<Item>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
                child: Text('Could not load your shop. Check your internet.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          final active = items.where((i) => !i.isSold).toList();
          final sold = items.where((i) => i.isSold).toList();
          final earned = sold.fold<int>(0, (s, i) => s + i.sellerEarnings);
          final potential =
              active.fold<int>(0, (s, i) => s + i.sellerEarnings);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text(
                _profile == null
                    ? 'Welcome 👋'
                    : 'Hi, ${_profile!.firstName} 👋',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text('Your shop at a glance',
                  style: Theme.of(context).textTheme.headlineMedium),
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
                      color: const Color(0xFF2E9E5B),
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
                      note: 'after $percent% fee',
                      color: AppColors.darkAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Potential',
                      value: formatPrice(potential),
                      note: 'if active items sell',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () => _go(const AddEditItemScreen()),
                icon: const Icon(Icons.add),
                label: const Text('Add new item'),
              ),
              const SizedBox(height: 24),

              Text('Recent listings',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.storefront_outlined,
                                size: 36, color: AppColors.secondary),
                            const SizedBox(height: 8),
                            Text('No listings yet',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('Post your first thrift find to start selling.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      )
                    : Column(
                        children: [for (final i in items.take(3)) _recentRow(i)],
                      ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _ordersTile(),
                    const Divider(height: 1, color: AppColors.border),
                    _actionTile(
                      icon: Icons.list_alt_outlined,
                      title: 'My Listings',
                      subtitle: 'Edit, delete or mark items as sold',
                      onTap: () => _go(const MyListingsScreen()),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _actionTile(
                      icon: Icons.explore_outlined,
                      title: 'Browse marketplace',
                      subtitle: 'See what other sellers are listing',
                      onTap: () => _go(const HomeScreen()),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _actionTile(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Switch to buying',
                      subtitle: 'Shop as a buyer with this same account',
                      onTap: () => switchMode(context, 'buyer'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
