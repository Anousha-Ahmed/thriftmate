import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../utils/role_router.dart';
import 'my_listings_screen.dart';
import 'my_orders_screen.dart';
import 'seller_orders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
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
      // Fall back to the basic info from the auth account below.
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to continue.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
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

  bool get _isSeller => _profile?.role == 'seller';

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final name = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : (user?.displayName ?? 'ThriftMate user');
    final email = _profile?.email.isNotEmpty == true
        ? _profile!.email
        : (user?.email ?? '');
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final hasPassword = AuthService.instance.hasPasswordLogin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                // Profile card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.14),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium),
                      if (_profile != null && _profile!.username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${_profile!.username}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(email,
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (_profile != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _profile!.roleLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Account',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    leading: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.primary),
                    title: const Text('Reset password'),
                    subtitle: Text(
                      hasPassword
                          ? 'We will email a reset link to $email'
                          : 'You signed in with Google, so there is no password to reset.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    trailing: !hasPassword
                        ? null
                        : _sendingReset
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2),
                              )
                            : const Icon(Icons.chevron_right,
                                color: AppColors.textMuted),
                    enabled: hasPassword && !_sendingReset,
                    onTap: hasPassword ? _resetPassword : null,
                  ),
                ),
                if (_profile != null) ...[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Buying & selling',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        if (_isSeller) ...[
                          ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            leading: const Icon(Icons.storefront_outlined,
                                color: AppColors.primary),
                            title: const Text('My Listings'),
                            subtitle: Text(
                              'Add, edit, delete items and mark them as sold',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.textMuted),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const MyListingsScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                        ],
                        ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          leading: const Icon(Icons.receipt_long_outlined,
                              color: AppColors.primary),
                          title: const Text('My Orders'),
                          subtitle: Text(
                            'Track the things you have bought',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const MyOrdersScreen()));
                          },
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        if (_isSeller) ...[
                          ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            leading: const Icon(Icons.local_shipping_outlined,
                                color: AppColors.primary),
                            title: const Text('Orders received'),
                            subtitle: Text(
                              'Update shipping status for your buyers',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.textMuted),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const SellerOrdersScreen()));
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                        ],
                        ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          leading: Icon(
                            _isSeller
                                ? Icons.shopping_bag_outlined
                                : Icons.storefront_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                              _isSeller ? 'Switch to buying' : 'Start selling'),
                          subtitle: Text(
                            _isSeller
                                ? 'Shop as a buyer with this same account'
                                : 'Post your own items. Same account, no new signup.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                          onTap: () =>
                              switchMode(context, _isSeller ? 'buyer' : 'seller'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 26),

                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkAccent,
                    minimumSize: const Size.fromHeight(54),
                    side: const BorderSide(color: AppColors.darkAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    );
  }
}
