import 'dart:async';

import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/item_service.dart';
import '../services/saved_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'add_edit_item_screen.dart';
import 'browse_screen.dart';
import 'cart_screen.dart';
import 'chats_screen.dart';
import 'discover_screen.dart';
import 'my_listings_screen.dart';
import 'profile_screen.dart';
import 'seller_dashboard_screen.dart';

/// The signed-in shell. Buying and selling get different tabs:
/// buyer = Discover / Browse / Sell / Chats / Profile
/// seller = Shop / Listings / Sell / Chats / Profile
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.role = 'buyer'});

  final String role;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  UserProfile? _profile;
  late final Stream<List<Item>> _itemsStream;
  final Set<String> _savedIds = <String>{};
  StreamSubscription<Set<String>>? _savedSubscription;

  String? get _uid => AuthService.instance.currentUser?.uid;
  bool get _isSeller => widget.role == 'seller';

  @override
  void initState() {
    super.initState();
    _itemsStream = ItemService.instance.activeItems();
    _loadProfile();
    _watchSaved();
  }

  @override
  void dispose() {
    _savedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final profile = await AuthService.instance.getProfile(uid);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  void _watchSaved() {
    final uid = _uid;
    if (uid == null) return;
    _savedSubscription = SavedService.instance.watch(uid).listen(
      (ids) {
        if (!mounted) return;
        setState(() {
          _savedIds
            ..clear()
            ..addAll(ids);
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _toggleSaved(Item item) async {
    final uid = _uid;
    if (uid == null) return;
    final bool save = !_savedIds.contains(item.id);
    setState(() {
      if (save) {
        _savedIds.add(item.id);
      } else {
        _savedIds.remove(item.id);
      }
    });
    try {
      await SavedService.instance.setSaved(
        uid: uid,
        itemId: item.id,
        saved: save,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (save) {
          _savedIds.remove(item.id);
        } else {
          _savedIds.add(item.id);
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Could not update your closet. Please try again.'),
        ));
    }
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  void _openAddItem() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
  }

  void _onNavTap(int navIndex) {
    if (_isSeller) {
      if (navIndex == 2) {
        _openAddItem();
        return;
      }
      // Sell (2) is an action, so the tabs after it shift down by one.
      setState(() => _index = navIndex >= 3 ? navIndex - 1 : navIndex);
      return;
    }
    setState(() => _index = navIndex);
  }

  List<Widget> _tabs(String uid, List<Item> items, bool loading, bool error) {
    if (_isSeller) {
      return [
        const SellerDashboardScreen(embedded: true),
        const MyListingsScreen(embedded: true),
        ChatsScreen(uid: uid),
        ProfileScreen(
          embedded: true,
          role: widget.role,
          userName: _profile?.name,
          username: _profile?.username,
          email: _profile?.email,
        ),
      ];
    }

    final int cartCount = CartService.instance.count;
    return [
      DiscoverScreen(
        items: items,
        savedIds: _savedIds,
        onToggleSaved: _toggleSaved,
        ownerUid: uid,
        cartCount: cartCount,
        onOpenCart: _openCart,
        onOpenBrowse: () => setState(() => _index = 1),
        loading: loading,
        error: error,
      ),
      BrowseScreen(
        items: items,
        savedIds: _savedIds,
        onToggleSaved: _toggleSaved,
        cartCount: cartCount,
        onOpenCart: _openCart,
        loading: loading,
        error: error,
      ),
      ChatsScreen(uid: uid),
      ProfileScreen(
        embedded: true,
        role: widget.role,
        userName: _profile?.name,
        username: _profile?.username,
        email: _profile?.email,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          return StreamBuilder<List<Item>>(
            stream: _itemsStream,
            builder: (context, snap) {
              final items = snap.data ?? const <Item>[];
              final bool loading = !snap.hasData && !snap.hasError;
              final bool error = snap.hasError;

              return IndexedStack(
                index: _index,
                children: _tabs(uid, items, loading, error),
              );
            },
          );
        },
      ),
      bottomNavigationBar: AppBottomNav(
        index: _isSeller && _index >= 2 ? _index + 1 : _index,
        onTap: _onNavTap,
        role: widget.role,
      ),
    );
  }
}
