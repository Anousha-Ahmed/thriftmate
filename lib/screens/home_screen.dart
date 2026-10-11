import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/product_card.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await AuthService.instance.getProfile(user.uid);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Greeting just falls back to a generic "Hello".
    }
  }

  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Tops', 'icon': Icons.checkroom_outlined},
    {'label': 'Bottoms', 'icon': Icons.dry_cleaning_outlined},
    {'label': 'Dresses', 'icon': Icons.woman_outlined},
    {'label': 'Outerwear', 'icon': Icons.ac_unit_outlined},
    {'label': 'Shoes', 'icon': Icons.sports_handball_outlined},
    {'label': 'Bags', 'icon': Icons.shopping_bag_outlined},
  ];

  // Placeholder data — will be replaced with real Firestore listings.
  final List<Product> _featured = [
    Product(
        name: 'Embroidered Lawn Kurta',
        brand: 'Khaadi',
        size: 'M',
        condition: 'Like New',
        price: 'Rs. 1,200'),
    Product(
        name: 'Slim Fit Denim Jeans',
        brand: 'Levi\'s',
        size: '32',
        condition: 'Good',
        price: 'Rs. 1,800'),
    Product(
        name: 'Leather Biker Jacket',
        brand: 'Generic',
        size: 'L',
        condition: 'Good',
        price: 'Rs. 2,500'),
  ];

  final List<Product> _freshFinds = [
    Product(
        name: 'Printed Maxi Dress',
        brand: 'Sapphire',
        size: 'S',
        condition: 'Like New',
        price: 'Rs. 1,500'),
    Product(
        name: 'Casual Sneakers',
        brand: 'Nike',
        size: '42',
        condition: 'Fair',
        price: 'Rs. 2,200'),
    Product(
        name: 'Quilted Tote Bag',
        brand: 'Generic',
        size: 'One Size',
        condition: 'Good',
        price: 'Rs. 850'),
    Product(
        name: 'Cotton Formal Shirt',
        brand: 'Bonanza',
        size: 'L',
        condition: 'Like New',
        price: 'Rs. 950'),
  ];

  final List<Product> _recommended = [
    Product(
        name: 'Winter Wool Coat',
        brand: 'Generic',
        size: 'M',
        condition: 'Good',
        price: 'Rs. 2,800'),
    Product(
        name: 'Palazzo Pants',
        brand: 'Gul Ahmed',
        size: 'S',
        condition: 'Like New',
        price: 'Rs. 1,000'),
  ];

  void _toggleWishlist(Product p) {
    setState(() => p.isWishlisted = !p.isWishlisted);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _navIndex = index);
      return;
    }
    if (index == 4) {
      _openProfile();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text('See all',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkAccent)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Greeting + search + notification
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No new notifications')),
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: AppColors.textMuted),
                          SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Search kurtas, jackets, bags...',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Categories',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return Container(
                      width: 74,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cat['icon'] as IconData,
                              color: AppColors.darkAccent, size: 24),
                          const SizedBox(height: 6),
                          Text(cat['label'] as String,
                              style: const TextStyle(fontSize: 11.5)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Featured — horizontal scroll
            SliverToBoxAdapter(child: _sectionHeader('Featured Thrift Finds')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 236,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => ProductCard(
                    width: 150,
                    product: _featured[index],
                    onWishlistTap: () => _toggleWishlist(_featured[index]),
                  ),
                ),
              ),
            ),

            // Fresh Finds — grid
            SliverToBoxAdapter(child: _sectionHeader('Fresh Finds')),
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
                  (context, index) => ProductCard(
                    product: _freshFinds[index],
                    onWishlistTap: () => _toggleWishlist(_freshFinds[index]),
                  ),
                  childCount: _freshFinds.length,
                ),
              ),
            ),

            // Recommended — grid
            SliverToBoxAdapter(child: _sectionHeader('Recommended For You')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(
                    product: _recommended[index],
                    onWishlistTap: () => _toggleWishlist(_recommended[index]),
                  ),
                  childCount: _recommended.length,
                ),
              ),
            ),
          ],
        ),
      ),
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
              icon: Icon(Icons.explore_outlined), label: 'Explore'),
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
