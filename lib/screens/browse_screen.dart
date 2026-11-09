import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

/// Filters browse results by sold state, category and free-text query.
/// Kept public so the marketplace filter can be unit tested without Firebase.
List<Item> filterBrowseItems(
  List<Item> items, {
  String? category,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return items.where((i) {
    if (i.isSold) return false;
    if (category != null && i.category != category) return false;
    if (q.isEmpty) return true;
    return i.name.toLowerCase().contains(q) ||
        i.brand.toLowerCase().contains(q) ||
        i.category.toLowerCase().contains(q);
  }).toList();
}

/// Full marketplace grid with search + category filters.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    required this.items,
    required this.savedIds,
    required this.onToggleSaved,
    required this.cartCount,
    required this.onOpenCart,
    this.loading = false,
    this.error = false,
  });

  final List<Item> items;
  final Set<String> savedIds;
  final ValueChanged<Item> onToggleSaved;
  final int cartCount;
  final VoidCallback onOpenCart;
  final bool loading;
  final bool error;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Item> get _filtered =>
      filterBrowseItems(widget.items, category: _category, query: _query);

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          SliverToBoxAdapter(child: _searchField()),
          SliverToBoxAdapter(child: _categories()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Text(
                    '${items.length} ${items.length == 1 ? 'find' : 'finds'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (_category != null || _query.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {
                          _query = '';
                          _category = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
          ),
          ..._body(context, items),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The racks', style: Theme.of(context).textTheme.bodyMedium),
                Text('Browse',
                    style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          _cartButton(),
        ],
      ),
    );
  }

  Widget _cartButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Cart',
          onPressed: widget.onOpenCart,
          icon: const Icon(Icons.shopping_bag_outlined,
              color: AppColors.ink, size: 25),
        ),
        if (widget.cartCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.clay,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.cartCount}',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search jackets, denim, bags...',
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _categories() {
    // Wedding wear is the highest-intent thrift category, so it sits right
    // after "All" in the rack chips instead of at the end of the scroll.
    const featured = 'Bridal & Event';
    final options = <String?>[
      null,
      featured,
      ...kCategories.where((c) => c != featured),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = _category == option;
          return GestureDetector(
            onTap: () => setState(() => _category = option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.forest : AppColors.surface,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: selected ? AppColors.forest : AppColors.line,
                ),
              ),
              child: Text(
                option ?? 'All',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _body(BuildContext context, List<Item> items) {
    if (widget.error) {
      return [
        SliverToBoxAdapter(
          child: _state(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load the racks',
            message: 'Check your internet connection and try again.',
          ),
        ),
      ];
    }
    if (widget.loading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _state(
            icon: Icons.checkroom_rounded,
            title: widget.items.isEmpty
                ? 'The racks are empty'
                : 'Nothing matches that',
            message: widget.items.isEmpty
                ? 'New thrift finds will appear here as sellers post them.'
                : 'Try another category or keyword.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.63,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return ProductCard(
                product: Product.fromItem(
                  item,
                  wishlisted: widget.savedIds.contains(item.id),
                ),
                onWishlistTap: () => widget.onToggleSaved(item),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(item: item),
                    ),
                  );
                },
              );
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: AppColors.sand,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
