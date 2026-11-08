import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'add_edit_item_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  UserProfile? _profile;
  late final Stream<List<Item>> _itemsStream;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _category; // null means "All"
  final Set<String> _wishlist = <String>{};

  static const Map<String, IconData> _categoryIcons = {
    'Tops': Icons.checkroom_outlined,
    'Bottoms': Icons.dry_cleaning_outlined,
    'Dresses': Icons.woman_outlined,
    'Outerwear': Icons.ac_unit_outlined,
    'Shoes': Icons.sports_handball_outlined,
    'Bags': Icons.shopping_bag_outlined,
  };

  @override
  void initState() {
    super.initState();
    _itemsStream = ItemService.instance.activeItems();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await AuthService.instance.getProfile(user.uid);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Greeting falls back to a generic "Hello".
    }
  }

  void _toggleWishlist(String id) {
    setState(() {
      if (_wishlist.contains(id)) {
        _wishlist.remove(id);
      } else {
        _wishlist.add(id);
      }
    });
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _onNavTap(int index) {
    switch (index) {
      case 1:
        _push(const CartScreen());
        break;
      case 2:
        _push(const MyOrdersScreen());
        break;
      case 3:
        _openProfile();
        break;
      default:
        setState(() => _navIndex = 0);
    }
  }

  List<Item> _applyFilters(List<Item> items) {
    final q = _query.trim().toLowerCase();
    return items.where((i) {
      if (_category != null && i.category != _category) return false;
      if (q.isEmpty) return true;
      return i.name.toLowerCase().contains(q) ||
          i.brand.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile == null
                      ? 'Hello 👋'
                      : 'Hi, ${_profile!.firstName} 👋',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Find your next favorite 🛍️',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textDark),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.darkAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search kurtas, jackets, bags...',
          fillColor: AppColors.surface,
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _categoryTile(String? category) {
    final bool selected = _category == category;
    final IconData icon =
        category == null ? Icons.apps_rounded : _categoryIcons[category]!;
    return GestureDetector(
      onTap: () => setState(() => _category = category),
      child: Container(
        width: 74,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.darkAccent,
                size: 24),
            const SizedBox(height: 6),
            Text(category ?? 'All', style: const TextStyle(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final List<String?> options = [null, ...kCategories];
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _categoryTile(options[index]),
      ),
    );
  }

  Widget _emptyState({required bool hasAnyItems}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.checkroom_rounded,
                size: 40, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(
              hasAnyItems ? 'No items match your search' : 'No items listed yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyItems
                  ? 'Try another category or keyword.'
                  : 'Sellers are adding their thrift finds. Check back soon!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItemSlivers(AsyncSnapshot<List<Item>> snap) {
    if (snap.hasError) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load items. Check your connection.'),
          ),
        ),
      ];
    }
    if (!snap.hasData) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    final all = snap.data!;
    final items = _applyFilters(all);
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(child: _emptyState(hasAnyItems: all.isNotEmpty)),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return ProductCard(
                product: Product.fromItem(
                  item,
                  wishlisted: _wishlist.contains(item.id),
                ),
                onWishlistTap: () => _toggleWishlist(item.id),
                onTap: () => _push(ProductDetailScreen(item: item)),
              );
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isSeller = _profile?.role == 'seller';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Item>>(
          stream: _itemsStream,
          builder: (context, snap) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearch()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text('Categories',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverToBoxAdapter(child: _buildCategories()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                    child: Text(_category ?? 'Fresh Finds',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                ..._buildItemSlivers(snap),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: isSeller
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AddEditItemScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Sell'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
