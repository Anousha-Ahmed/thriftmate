import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// What the buyer decided to offer.
class OfferDraft {
  const OfferDraft({required this.amount, required this.note});

  final int amount;
  final String note;
}

/// The offer negotiation sheet: quick discount chips plus a stepper.
/// Shared by the item detail page and the chat thread (counter offers).
class OfferSheet extends StatefulWidget {
  const OfferSheet({
    super.key,
    required this.price,
    required this.itemName,
    this.initialAmount,
    this.title = 'Make an offer',
    this.submitLabel = 'Send offer',
  });

  final int price;
  final String itemName;
  final int? initialAmount;
  final String title;
  final String submitLabel;

  static Future<OfferDraft?> show(
    BuildContext context, {
    required int price,
    required String itemName,
    int? initialAmount,
    String title = 'Make an offer',
    String submitLabel = 'Send offer',
  }) {
    return showModalBottomSheet<OfferDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferSheet(
        price: price,
        itemName: itemName,
        initialAmount: initialAmount,
        title: title,
        submitLabel: submitLabel,
      ),
    );
  }

  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  late int _amount;
  late final TextEditingController _note;

  static const List<int> _percents = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount ??
        (widget.price * 0.9).round().clamp(50, widget.price).toInt();
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int _amountForPercent(int percent) =>
      (widget.price * (100 - percent) / 100).round().clamp(50, widget.price).toInt();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                Text(widget.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  '${widget.itemName} · listed at ${formatPrice(widget.price)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    for (final percent in _percents) ...[
                      Expanded(
                        child: _percentChip(percent),
                      ),
                      if (percent != _percents.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      _stepButton(Icons.remove_rounded, () {
                        setState(() => _amount =
                            (_amount - 100).clamp(50, widget.price).toInt());
                      }),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'YOUR OFFER',
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatPrice(_amount),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: AppColors.forest),
                            ),
                          ],
                        ),
                      ),
                      _stepButton(Icons.add_rounded, () {
                        setState(() => _amount =
                            (_amount + 100).clamp(50, widget.price).toInt());
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _note,
                  maxLines: 2,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    hintText: 'Add a note (optional) — e.g. "Can pick up today"',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _amount <= 0
                      ? null
                      : () => Navigator.of(context).pop(
                            OfferDraft(
                              amount: _amount,
                              note: _note.text.trim(),
                            ),
                          ),
                  child: Text(widget.submitLabel),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'The seller can accept, decline or counter your offer.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _percentChip(int percent) {
    final int value = _amountForPercent(percent);
    final bool selected = _amount == value;
    return GestureDetector(
      onTap: () => setState(() => _amount = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.line,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$percent% off',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatPrice(value),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: selected ? Colors.white70 : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: AppColors.forest),
      ),
    );
  }
}
