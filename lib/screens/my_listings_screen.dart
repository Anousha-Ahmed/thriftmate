import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'add_edit_item_screen.dart';

/// A seller's own listings, split into Active and Sold tabs.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  late final Stream<List<Item>> _stream;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _stream = uid == null
        ? Stream<List<Item>>.value(const <Item>[])
        : ItemService.instance.sellerItems(uid);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _markSold(Item item) async {
    final ok = await _confirm(
      'Mark as sold?',
      '"${item.name}" will move to Sold and disappear from the marketplace.',
      'Mark as sold',
    );
    if (!ok) return;
    try {
      await ItemService.instance.markSold(item.id);
      _showMessage('Marked as sold');
    } catch (_) {
      _showMessage('Could not update the item');
    }
  }

  Future<void> _delete(Item item) async {
    final ok = await _confirm(
      'Delete listing?',
      '"${item.name}" will be removed permanently.',
      'Delete',
    );
    if (!ok) return;
    try {
      await ItemService.instance.deleteItem(item.id);
      _showMessage('Listing deleted');
    } catch (_) {
      _showMessage('Could not delete the item');
    }
  }

  void _edit(Item item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
    );
  }

  void _addNew() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 44, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _card(Item item) {
    final percent = (kPlatformFeeRate * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.coverBytes == null
                    ? Container(
                        width: 78,
                        height: 78,
                        color: AppColors.background,
                        child: const Icon(Icons.checkroom_rounded,
                            color: AppColors.secondary),
                      )
                    : Image.memory(item.coverBytes!,
                        width: 78, height: 78, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text('${item.brand} · Size ${item.size} · ${item.condition}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatPrice(item.price),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.darkAccent)),
                    Text(
                      'You earn ${formatPrice(item.sellerEarnings)} after $percent% fee',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${item.views} views',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!item.isSold) ...[
                TextButton.icon(
                  onPressed: () => _edit(item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _markSold(item),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Sold'),
                ),
              ],
              TextButton.icon(
                onPressed: () => _delete(item),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list(List<Item> items, {required bool sold}) {
    if (items.isEmpty) {
      return sold
          ? _empty('Nothing sold yet', 'Items you mark as sold will show here.')
          : _empty('No active listings',
              'Tap "Add item" to post your first thrift find.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: items.length,
      itemBuilder: (context, index) => _card(items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: _stream,
      builder: (context, snap) {
        final items = snap.data ?? const <Item>[];
        final active = items.where((i) => !i.isSold).toList();
        final sold = items.where((i) => i.isSold).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('My Listings'),
              bottom: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Active (${active.length})'),
                  Tab(text: 'Sold (${sold.length})'),
                ],
              ),
            ),
            body: snap.hasError
                ? _empty('Could not load listings',
                    'Check your internet connection and try again.')
                : !snap.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          _list(active, sold: false),
                          _list(sold, sold: true),
                        ],
                      ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _addNew,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ),
        );
      },
    );
  }
}
