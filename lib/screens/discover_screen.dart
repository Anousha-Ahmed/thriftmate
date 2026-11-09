import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../theme/app_theme.dart';
import '../widgets/price_tag.dart';
import '../widgets/thrift_photo.dart';
import '../utils/format.dart';
import 'product_detail_screen.dart';

/// Items that can land on the swipe deck: live pieces from other sellers,
/// optionally narrowed by category and condition.
List<Item> visibleDiscoverItems(
  List<Item> items, {
  String? ownerUid,
  String? category,
  String? condition,
}) {
  return items.where((i) {
    if (i.isSold) return false;
    if (ownerUid != null && i.sellerId == ownerUid) return false;
    if (category != null && i.category != category) return false;
    if (condition != null && i.condition != condition) return false;
    return true;
  }).toList();
}

/// Swipe-to-match discovery: the hero screen of ThriftMate.
/// Right = save to closet, left = pass. Undo puts the card back.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.items,
    required this.savedIds,
    required this.onToggleSaved,
    required this.ownerUid,
    required this.cartCount,
    required this.onOpenCart,
    required this.onOpenBrowse,
    this.onPostItem,
    this.loading = false,
    this.error = false,
  });

  final List<Item> items;
  final Set<String> savedIds;
  final ValueChanged<Item> onToggleSaved;
  final String? ownerUid;
  final int cartCount;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBrowse;
  final VoidCallback? onPostItem;
  final bool loading;
  final bool error;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _SwipeRecord {
  const _SwipeRecord({
    required this.index,
    required this.itemId,
    required this.liked,
  });

  final int index;
  final String itemId;
  final bool liked;
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  final List<_SwipeRecord> _history = [];
  Offset _drag = Offset.zero;
  double _flyDirection = 1;
  bool _swipedLike = false;
  int _index = 0;
  String? _category;
  String? _condition;

  @override
  void initState() {
    super.initState();
    _fly.addListener(_onFlyTick);
    _fly.addStatusListener(_onFlyStatus);
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  List<Item> get _visible => visibleDiscoverItems(
        widget.items,
        ownerUid: widget.ownerUid,
        category: _category,
        condition: _condition,
      );

  void _onFlyTick() {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _drag = Offset(
        _fly.value * width * 1.25 * _flyDirection,
        -70 * _fly.value,
      );
    });
  }

  void _onFlyStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final items = _visible;
    final Item? item = _index < items.length ? items[_index] : null;

    if (item != null) {
      _history.add(_SwipeRecord(
        index: _index,
        itemId: item.id,
        liked: _swipedLike,
      ));
      if (_swipedLike && !widget.savedIds.contains(item.id)) {
        widget.onToggleSaved(item);
      }
    }

    setState(() {
      _index += 1;
      _drag = Offset.zero;
    });
    _fly.reset();
  }

  void _flyOut(bool liked) {
    if (_fly.isAnimating) return;
    final items = _visible;
    if (_index >= items.length) return;
    setState(() {
      _swipedLike = liked;
      _flyDirection = liked ? 1 : -1;
    });
    _fly.forward(from: 0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    if (last.liked && widget.savedIds.contains(last.itemId)) {
      Item? item;
      for (final candidate in widget.items) {
        if (candidate.id == last.itemId) {
          item = candidate;
          break;
        }
      }
      if (item != null) widget.onToggleSaved(item);
    }
    setState(() => _index = last.index);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        category: _category,
        condition: _condition,
      ),
    );
    if (result == null) return;
    setState(() {
      _category = result.category;
      _condition = result.condition;
      _index = 0;
      _history.clear();
    });
  }

  void _openItem(Item item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final bool deckFinished = _index >= items.length;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, items.length),
          if (widget.loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.error)
            Expanded(
              child: _state(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load the drop',
                message: 'Check your internet connection and pull again.',
              ),
            )
          else if (items.isEmpty)
            Expanded(child: _emptyDeck())
          else if (deckFinished)
            Expanded(
              child: _state(
                icon: Icons.done_all_rounded,
                title: "You're all caught up",
                message:
                    'You looked at every piece in this drop. Browse the racks or check back for new finds.',
                action: TextButton(
                  onPressed: widget.onOpenBrowse,
                  child: const Text('Browse the racks'),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              for (int depth = 2; depth >= 0; depth--)
                                if (_index + depth < items.length)
                                  Positioned(
                                    top: depth * 11.0,
                                    left: depth * 9.0,
                                    right: depth * 9.0,
                                    bottom: depth * 9.0,
                                    child: IgnorePointer(
                                      ignoring: depth != 0,
                                      child: Transform.rotate(
                                        angle: depth == 0
                                            ? (_drag.dx / 420)
                                                .clamp(-0.18, 0.18)
                                                .toDouble()
                                            : 0,
                                        child: Transform.translate(
                                          offset: depth == 0
                                              ? _drag
                                              : Offset.zero,
                                          child: _SwipeCard(
                                            item: items[_index + depth],
                                            saved: widget.savedIds.contains(
                                                items[_index + depth].id),
                                            showDetails: depth == 0,
                                            dragX: depth == 0 ? _drag.dx : 0,
                                            onTap: depth == 0
                                                ? () => _openItem(
                                                    items[_index])
                                                : null,
                                            onPanUpdate: depth == 0
                                                ? (details) {
                                                    if (_fly.isAnimating) {
                                                      return;
                                                    }
                                                    setState(() => _drag +=
                                                        details.delta);
                                                  }
                                                : null,
                                            onPanEnd: depth == 0
                                                ? (_) {
                                                    if (_fly.isAnimating) {
                                                      return;
                                                    }
                                                    if (_drag.dx.abs() > 96) {
                                                      _flyOut(_drag.dx > 0);
                                                    } else {
                                                      setState(() =>
                                                          _drag = Offset.zero);
                                                    }
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  _controls(context, items[_index]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, int count) {
    final bool filtered = _category != null || _condition != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's drop",
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text('Discover',
                        style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
              _iconButton(
                icon: filtered ? Icons.tune_rounded : Icons.tune_outlined,
                onTap: _openFilters,
                badge: filtered,
              ),
              _cartButton(),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            count == 0
                ? 'Swipe right to save, left to pass.'
                : '$count ${count == 1 ? 'piece' : 'pieces'} · swipe right to save',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.ink, size: 24),
        ),
        if (badge)
          Positioned(
            right: 9,
            top: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.clay,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
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

  Widget _controls(BuildContext context, Item item) {
    final bool saved = widget.savedIds.contains(item.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _roundButton(
            icon: Icons.undo_rounded,
            size: 46,
            color: AppColors.ink,
            background: AppColors.surface,
            border: AppColors.line,
            onTap: _history.isEmpty ? null : _undo,
            tooltip: 'Undo',
          ),
          _roundButton(
            icon: Icons.close_rounded,
            size: 58,
            color: AppColors.ink,
            background: AppColors.surface,
            border: AppColors.line,
            onTap: () => _flyOut(false),
            tooltip: 'Pass',
          ),
          _roundButton(
            icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 58,
            color: Colors.white,
            background: AppColors.clay,
            border: AppColors.clay,
            onTap: () => _flyOut(true),
            tooltip: 'Save',
          ),
          _roundButton(
            icon: Icons.open_in_full_rounded,
            size: 46,
            color: AppColors.ink,
            background: AppColors.surface,
            border: AppColors.line,
            onTap: () => _openItem(item),
            tooltip: 'Details',
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required double size,
    required Color color,
    required Color background,
    required Color border,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final button = Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: border),
          boxShadow: background == AppColors.clay
              ? [
                  BoxShadow(
                    color: AppColors.clay.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(onTap: onTap, child: button),
    );
  }

  Widget _emptyDeck() {
    final bool filtered = _category != null || _condition != null;
    final bool hasOtherSellers =
        widget.items.any((i) => !i.isSold && i.sellerId != widget.ownerUid);
    final bool onlyMine = widget.items.isNotEmpty && !hasOtherSellers;

    if (filtered && !onlyMine) {
      return _state(
        icon: Icons.local_florist_outlined,
        title: 'No matches for those filters',
        message: 'Loosen the filters and the deck refills.',
        action: TextButton(
          onPressed: () => setState(() {
            _category = null;
            _condition = null;
            _index = 0;
          }),
          child: const Text('Clear filters'),
        ),
      );
    }

    return _state(
      icon: widget.items.isEmpty
          ? Icons.local_florist_outlined
          : Icons.storefront_outlined,
      title: widget.items.isEmpty
          ? 'No pieces on the rack yet'
          : 'Only your listings are live',
      message: widget.items.isEmpty
          ? 'When sellers post, their finds land right here. Post the first find yourself.'
          : 'Your own pieces stay off the swipe deck so buyers get first pick. Browse the racks or post another find.',
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          TextButton(
            onPressed: widget.onOpenBrowse,
            child: const Text('Browse the racks'),
          ),
          if (widget.onPostItem != null)
            TextButton(
              onPressed: widget.onPostItem,
              child: const Text('Post a find'),
            ),
        ],
      ),
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: AppColors.sand,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
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
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.item,
    required this.saved,
    required this.showDetails,
    required this.dragX,
    this.onTap,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final Item item;
  final bool saved;
  final bool showDetails;
  final double dragX;
  final VoidCallback? onTap;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  @override
  Widget build(BuildContext context) {
    final double stampOpacity = (dragX.abs() / 110).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ThriftPhoto(bytes: item.coverBytes, radius: 0),
              if (showDetails)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xCC000000),
                      ],
                      stops: [0, 0.25, 0.5, 1],
                    ),
                  ),
                ),
              if (showDetails) ...[
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.category.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: saved ? AppColors.clay : AppColors.ink,
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.brand.isEmpty
                            ? item.condition.toUpperCase()
                            : item.brand.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fraunces(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Size ${item.size}  ·  ${item.condition}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const Spacer(),
                          PriceTag(
                            price: formatPrice(item.price),
                            small: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (stampOpacity > 0)
                  Positioned(
                    top: 90,
                    right: 22,
                    child: Opacity(
                      opacity: dragX > 0 ? stampOpacity : 0,
                      child: _stamp('COP', AppColors.mustard),
                    ),
                  ),
                if (stampOpacity > 0)
                  Positioned(
                    top: 90,
                    left: 22,
                    child: Opacity(
                      opacity: dragX < 0 ? stampOpacity : 0,
                      child: _stamp('PASS', Colors.white),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stamp(String text, Color color) {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _Filters {
  const _Filters({this.category, this.condition});
  final String? category;
  final String? condition;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({this.category, this.condition});

  final String? category;
  final String? condition;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _category;
  String? _condition;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _condition = widget.condition;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Fine-tune the drop',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Both filters apply to the swipe deck.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            Text('Category',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('All', _category == null,
                    () => setState(() => _category = null)),
                for (final c in kCategories)
                  _chip(c, _category == c,
                      () => setState(() => _category = c)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Condition',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Any', _condition == null,
                    () => setState(() => _condition = null)),
                for (final c in kConditions)
                  _chip(c, _condition == c,
                      () => setState(() => _condition = c)),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(
                _Filters(category: _category, condition: _condition),
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.circular(40),
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
