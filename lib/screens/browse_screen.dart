import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/notification_bell.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

enum BrowseSort { newest, priceLow, priceHigh }

extension BrowseSortLabel on BrowseSort {
  String get label => switch (this) {
        BrowseSort.newest => 'Newest first',
        BrowseSort.priceLow => 'Price: low to high',
        BrowseSort.priceHigh => 'Price: high to low',
      };
}

/// Narrowing options applied on top of category + search.
/// Size, condition and brand are OR within a group, AND across groups.
class BrowseFilters {
  const BrowseFilters({
    this.sizes = const <String>{},
    this.conditions = const <String>{},
    this.brands = const <String>{},
    this.minPrice,
    this.maxPrice,
    this.sort = BrowseSort.newest,
  });

  final Set<String> sizes;
  final Set<String> conditions;
  final Set<String> brands;
  final int? minPrice;
  final int? maxPrice;
  final BrowseSort sort;

  bool get hasPriceRange => minPrice != null || maxPrice != null;
  bool get isActive =>
      sizes.isNotEmpty ||
      conditions.isNotEmpty ||
      brands.isNotEmpty ||
      hasPriceRange;

  int get activeCount =>
      sizes.length +
      conditions.length +
      brands.length +
      (hasPriceRange ? 1 : 0);

  static const BrowseFilters none = BrowseFilters();
}

/// Filters browse results by sold state, category, search text and [filters].
/// Kept public so the marketplace filter can be unit tested without Firebase.
List<Item> filterBrowseItems(
  List<Item> items, {
  String? category,
  String query = '',
  BrowseFilters filters = BrowseFilters.none,
}) {
  final q = query.trim().toLowerCase();
  final result = items.where((i) {
    if (i.isSold) return false;
    if (category != null && i.category != category) return false;
    if (filters.sizes.isNotEmpty && !filters.sizes.contains(i.size)) {
      return false;
    }
    if (filters.conditions.isNotEmpty &&
        !filters.conditions.contains(i.condition)) {
      return false;
    }
    if (filters.brands.isNotEmpty && !filters.brands.contains(i.brand)) {
      return false;
    }
    if (filters.minPrice != null && i.price < filters.minPrice!) return false;
    if (filters.maxPrice != null && i.price > filters.maxPrice!) return false;
    if (q.isEmpty) return true;
    return i.name.toLowerCase().contains(q) ||
        i.brand.toLowerCase().contains(q) ||
        i.category.toLowerCase().contains(q);
  }).toList();

  switch (filters.sort) {
    case BrowseSort.newest:
      result.sort((a, b) {
        final DateTime? ad = a.createdAt;
        final DateTime? bd = b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    case BrowseSort.priceLow:
      result.sort((a, b) => a.price.compareTo(b.price));
    case BrowseSort.priceHigh:
      result.sort((a, b) => b.price.compareTo(a.price));
  }
  return result;
}

/// Brands that actually have an active listing, alphabetically.
List<String> availableBrands(List<Item> items) {
  final brands = items
      .where((i) => !i.isSold && i.brand.trim().isNotEmpty)
      .map((i) => i.brand.trim())
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return brands;
}

/// Upper end of the price slider, rounded up to the next 500 PKR.
int priceCeiling(List<Item> items) {
  int highest = 0;
  for (final i in items) {
    if (!i.isSold && i.price > highest) highest = i.price;
  }
  if (highest <= 0) return 5000;
  return ((highest + 499) ~/ 500) * 500;
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
    this.ownerUid,
    this.loading = false,
    this.error = false,
  });

  final List<Item> items;
  final Set<String> savedIds;
  final ValueChanged<Item> onToggleSaved;
  final int cartCount;
  final VoidCallback onOpenCart;

  /// Signed-in user; own listings get no quick add-to-cart button.
  final String? ownerUid;
  final bool loading;
  final bool error;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _category;
  BrowseFilters _filters = BrowseFilters.none;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Item> get _filtered => filterBrowseItems(
        widget.items,
        category: _category,
        query: _query,
        filters: _filters,
      );

  bool get _hasFilters =>
      _category != null || _query.isNotEmpty || _filters.isActive;

  void _clearAll() {
    _search.clear();
    setState(() {
      _query = '';
      _category = null;
      _filters = BrowseFilters.none;
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<BrowseFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(items: widget.items, initial: _filters),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  void _addToCart(Item item) {
    CartService.instance.add(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Added to cart'),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: widget.onOpenCart,
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) => CustomScrollView(
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
                    if (_hasFilters)
                      TextButton(
                        onPressed: _clearAll,
                        child: const Text('Clear'),
                      ),
                    TextButton.icon(
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: _filters.activeCount > 0,
                        backgroundColor: AppColors.clay,
                        label: Text('${_filters.activeCount}'),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _filters.isActive
                              ? AppColors.clay
                              : AppColors.forest,
                        ),
                      ),
                      label: Text(
                        'Filter',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _filters.isActive
                              ? AppColors.clay
                              : AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._body(context, items),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
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
                Text('Marketplace',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text('Browse',
                    style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          NotificationBell(uid: widget.ownerUid ?? ''),
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
      final bool filtered = _hasFilters;

      return [
        SliverToBoxAdapter(
          child: _state(
            icon: filtered ? Icons.search_off_rounded : Icons.checkroom_rounded,
            title: filtered ? 'Nothing matches that' : 'No finds yet',
            message: filtered
                ? 'Try a wider price range, another size or a different keyword.'
                : 'New pieces show up here as sellers list them. Check back soon.',
            action: filtered
                ? TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear filters'),
                  )
                : null,
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
            childAspectRatio: 0.56,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              final bool isOwn =
                  widget.ownerUid != null && item.sellerId == widget.ownerUid;
              final bool inCart = CartService.instance.contains(item.id);
              return ProductCard(
                product: Product.fromItem(
                  item,
                  wishlisted: widget.savedIds.contains(item.id),
                ),
                inCart: inCart,
                isOwn: isOwn,
                onAddToCart: isOwn
                    ? null
                    : () {
                        if (inCart) {
                          widget.onOpenCart();
                        } else {
                          _addToCart(item);
                        }
                      },
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
    Widget? action,
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
          if (action != null) ...[
            const SizedBox(height: 10),
            action,
          ],
        ],
      ),
    );
  }
}

/// Sort + size + condition + brand + price range, applied from a bottom sheet.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.items, required this.initial});

  final List<Item> items;
  final BrowseFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final int _ceiling = priceCeiling(widget.items);
  late final List<String> _brands = availableBrands(widget.items);

  late Set<String> _sizes = {...widget.initial.sizes};
  late Set<String> _conditions = {...widget.initial.conditions};
  late Set<String> _selectedBrands = {...widget.initial.brands};
  late BrowseSort _sort = widget.initial.sort;
  late RangeValues _price = _initialRange();

  RangeValues _initialRange() {
    final top = _ceiling.toDouble();
    final start = (widget.initial.minPrice ?? 0).toDouble().clamp(0.0, top).toDouble();
    final end =
        (widget.initial.maxPrice ?? _ceiling).toDouble().clamp(start, top).toDouble();
    return RangeValues(start, end);
  }

  BrowseFilters get _draft => BrowseFilters(
        sizes: _sizes,
        conditions: _conditions,
        brands: _selectedBrands,
        minPrice: _price.start <= 0 ? null : _price.start.round(),
        maxPrice: _price.end >= _ceiling ? null : _price.end.round(),
        sort: _sort,
      );

  void _toggle(Set<String> set, String value) {
    setState(() {
      if (!set.remove(value)) set.add(value);
    });
  }

  void _reset() {
    setState(() {
      _sizes = <String>{};
      _conditions = <String>{};
      _selectedBrands = <String>{};
      _sort = BrowseSort.newest;
      _price = RangeValues(0, _ceiling.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    final int matches =
        filterBrowseItems(widget.items, filters: _draft).length;
    final bool fullRange = _price.start <= 0 && _price.end >= _ceiling;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Text('Filter & sort',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Sort by'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in BrowseSort.values)
                          ChoiceChip(
                            label: Text(s.label),
                            selected: _sort == s,
                            onSelected: (_) => setState(() => _sort = s),
                            showCheckmark: false,
                            labelStyle: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _sort == s ? Colors.white : AppColors.ink,
                            ),
                            selectedColor: AppColors.forest,
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: _sort == s ? AppColors.forest : AppColors.line,
                            ),
                          ),
                      ],
                    ),
                    _section('Size'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in kSizes)
                          _chip(
                            label: size,
                            selected: _sizes.contains(size),
                            onTap: () => _toggle(_sizes, size),
                          ),
                      ],
                    ),
                    _section('Condition'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in kConditions)
                          _chip(
                            label: c,
                            selected: _conditions.contains(c),
                            onTap: () => _toggle(_conditions, c),
                          ),
                      ],
                    ),
                    if (_brands.isNotEmpty) ...[
                      _section('Brand'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final brand in _brands)
                            _chip(
                              label: brand,
                              selected: _selectedBrands.contains(brand),
                              onTap: () => _toggle(_selectedBrands, brand),
                            ),
                        ],
                      ),
                    ],
                    _section('Price'),
                    Row(
                      children: [
                        Text(
                          fullRange
                              ? 'Any price'
                              : '${formatPrice(_price.start)} – ${formatPrice(_price.end)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'up to ${formatPrice(_ceiling)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _price,
                      min: 0,
                      max: _ceiling.toDouble(),
                      divisions: _ceiling >= 500 ? _ceiling ~/ 500 : 1,
                      activeColor: AppColors.forest,
                      inactiveColor: AppColors.sand,
                      onChanged: (v) => setState(() => _price = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: Text(
                        'Show $matches ${matches == 1 ? 'result' : 'results'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
