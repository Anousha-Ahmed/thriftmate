import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../models/shop_order.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/order_service.dart';
import '../services/saved_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/role_router.dart';
import '../widgets/thrift_photo.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'my_orders_screen.dart';
import 'product_detail_screen.dart';
import 'seller_dashboard_screen.dart';
import 'seller_orders_screen.dart';

/// Profile + closet + thrift impact. Can be used as a tab ([embedded]) or as
/// its own page (from the seller dashboard).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.embedded = false,
    this.role,
    this.userName,
    this.username,
    this.email,
  });

  final bool embedded;
  final String? role;
  final String? userName;
  final String? username;
  final String? email;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _sendingReset = false;

  String? get _uid => AuthService.instance.currentUser?.uid;

  late final Stream<List<Item>> _myItems;
  late final Stream<List<ShopOrder>> _myOrders;
  late final Stream<Set<String>> _saved;
  late final Stream<List<Item>> _activeItems;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    _myItems = uid == null
        ? Stream<List<Item>>.value(const <Item>[])
        : ItemService.instance.sellerItems(uid);
    _myOrders = uid == null
        ? Stream<List<ShopOrder>>.value(const <ShopOrder>[])
        : OrderService.instance.buyerOrders(uid);
    _saved = uid == null
        ? Stream<Set<String>>.value(<String>{})
        : SavedService.instance.watch(uid);
    _activeItems = ItemService.instance.activeItems();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService.instance.currentUser;
    try {
      if (user != null) {
        final profile = await AuthService.instance.getProfile(user.uid);
        if (mounted) setState(() => _profile = profile);
      }
    } catch (_) {
      // Falls back to the basic auth account info.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resetPassword() async {
    final email = AuthService.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showMessage('No email found for this account.');
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await AuthService.instance.sendPasswordReset(email);
      _showMessage('Password reset link sent to $email');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not send the reset email. Try again.');
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to continue.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  bool get _isSeller =>
      widget.role == 'seller' || _profile?.role == 'seller';

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final name = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!
        : (_profile?.name.isNotEmpty == true
            ? _profile!.name
            : (user?.displayName ?? 'ThriftMate user'));
    final email = widget.email?.isNotEmpty == true
        ? widget.email!
        : (_profile?.email.isNotEmpty == true
            ? _profile!.email
            : (user?.email ?? ''));
    final username = widget.username?.isNotEmpty == true
        ? widget.username!
        : (_profile?.username ?? '');

    final body = _loading && user == null
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<Item>>(
            stream: _myItems,
            builder: (context, itemSnap) {
              final myItems = itemSnap.data ?? const <Item>[];
              final active = myItems.where((i) => !i.isSold).toList();
              final sold = myItems.where((i) => i.isSold).toList();

              return StreamBuilder<List<ShopOrder>>(
                stream: _myOrders,
                builder: (context, orderSnap) {
                  final orders = orderSnap.data ?? const <ShopOrder>[];
                  final delivered =
                      orders.where((o) => o.status == 'delivered').length;
                  final rehomed = sold.length + delivered;

                  return StreamBuilder<Set<String>>(
                    stream: _saved,
                    builder: (context, savedSnap) {
                      final savedIds = savedSnap.data ?? <String>{};

                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          widget.embedded ? 16 : 4,
                          20,
                          widget.embedded ? 100 : 28,
                        ),
                        children: [
                          _identity(name, username, email),
                          const SizedBox(height: 20),
                          _stats(
                            first: _isSeller
                                ? '${active.length}'
                                : '${orders.length}',
                            firstLabel: _isSeller ? 'Listings' : 'Orders',
                            second:
                                _isSeller ? '${sold.length}' : '$delivered',
                            secondLabel: _isSeller ? 'Sold' : 'Delivered',
                            saved: savedIds.length,
                          ),
                          if (_isSeller) ...[
                            const SizedBox(height: 16),
                            _impact(rehomed: rehomed),
                          ],
                          const SizedBox(height: 24),
                          _sectionTitle('Your closet'),
                          const SizedBox(height: 10),
                          _closet(savedIds),
                          const SizedBox(height: 24),
                          _sectionTitle('Account'),
                          const SizedBox(height: 10),
                          _menu(),
                          const SizedBox(height: 20),
                          _logoutButton(),
                        ],
                      );
                    },
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
      appBar: AppBar(title: const Text('Profile')),
      body: body,
    );
  }

  Widget _identity(String name, String username, String email) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.sand,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: GoogleFonts.fraunces(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (username.isNotEmpty)
                Text(
                  '@$username',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.clay,
                  ),
                ),
              if (email.isNotEmpty)
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (_profile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _profile!.roleLabel,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.forest,
              ),
            ),
          ),
      ],
    );
  }

  Widget _stats({
    required String first,
    required String firstLabel,
    required String second,
    required String secondLabel,
    required int saved,
  }) {
    return Row(
      children: [
        Expanded(child: _statCard(first, firstLabel)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(second, secondLabel)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('$saved', 'Saved')),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.fraunces(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _impact({required int rehomed}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, size: 18, color: AppColors.mustard),
              const SizedBox(width: 6),
              Text(
                'GREEN IMPACT',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rehomed > 0
                ? '$rehomed ${rehomed == 1 ? 'piece' : 'pieces'} rehomed'
                : 'Your thrift story starts here',
            style: GoogleFonts.fraunces(
              fontSize: rehomed > 0 ? 27 : 23,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rehomed > 0
                ? 'Good for your wardrobe and the planet.'
                : 'Sell or receive your first pre-loved piece and this count starts growing.',
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

  Widget _sectionTitle(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _closet(Set<String> savedIds) {
    if (savedIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite_border_rounded,
                size: 22, color: AppColors.clay),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSeller
                    ? 'Pieces you save while browsing will land here.'
                    : 'Swipe right (or tap the heart) on anything you love — it lands here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 196,
      child: StreamBuilder<List<Item>>(
        stream: _activeItems,
        builder: (context, snap) {
          final items = (snap.data ?? const <Item>[])
              .where((i) => savedIds.contains(i.id))
              .toList();
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Your saved pieces are no longer listed.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _closetCard(items[i]),
          );
        },
      ),
    );
  }

  Widget _closetCard(Item item) {
    return GestureDetector(
      onTap: () => _push(ProductDetailScreen(item: item)),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: ThriftPhoto(bytes: item.coverBytes, radius: 12),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            Text(
              formatPrice(item.price),
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu() {
    final hasPassword = AuthService.instance.hasPasswordLogin;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _tile(
            icon: Icons.receipt_long_outlined,
            title: 'My orders',
            subtitle: 'Track the things you bought',
            onTap: () => _push(const MyOrdersScreen()),
          ),
          const Divider(height: 1),
          if (_isSeller) ...[
            _tile(
              icon: Icons.inventory_2_outlined,
              title: 'My listings',
              subtitle: 'Edit, delete or mark items as sold',
              onTap: () => _push(const MyListingsScreen()),
            ),
            const Divider(height: 1),
            _tile(
              icon: Icons.local_shipping_outlined,
              title: 'Orders received',
              subtitle: 'Update shipping status for your buyers',
              onTap: () => _push(const SellerOrdersScreen()),
            ),
            const Divider(height: 1),
            _tile(
              icon: Icons.storefront_outlined,
              title: 'Seller dashboard',
              subtitle: 'Your shop at a glance',
              onTap: () => _push(const SellerDashboardScreen()),
            ),
            const Divider(height: 1),
          ],
          _tile(
            icon: _isSeller
                ? Icons.shopping_bag_outlined
                : Icons.storefront_outlined,
            title: _isSeller ? 'Switch to buying' : 'Start selling',
            subtitle: _isSeller
                ? 'Shop as a buyer with this same account'
                : 'Post your own items. Same account, no new signup.',
            onTap: () => switchMode(context, _isSeller ? 'buyer' : 'seller'),
          ),
          if (hasPassword) ...[
            const Divider(height: 1),
            _tile(
              icon: Icons.lock_reset_rounded,
              title: 'Reset password',
              subtitle: _sendingReset
                  ? 'Sending the reset link...'
                  : 'We will email a reset link',
              onTap: _sendingReset ? null : _resetPassword,
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 20, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      onPressed: _confirmLogout,
      icon: const Icon(Icons.logout_rounded, size: 19),
      label: const Text('Log out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.clay,
        side: const BorderSide(color: AppColors.clay, width: 1.2),
      ),
    );
  }
}
