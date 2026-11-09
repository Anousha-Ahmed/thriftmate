import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Five-tab bar with the "Sell" action lifted into a clay circle in the
/// middle. Index 2 is an action, not a page, so it is never highlighted.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    this.role = 'buyer',
  });

  final int index;
  final ValueChanged<int> onTap;
  final String role;

  bool get _selling => role == 'seller';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: _selling
                ? [
                    _tab(context, 0, Icons.storefront_outlined,
                        Icons.storefront, 'Shop'),
                    _tab(context, 1, Icons.inventory_2_outlined,
                        Icons.inventory_2, 'Listings'),
                    _sellTab(context),
                    _tab(context, 3, Icons.forum_outlined, Icons.forum,
                        'Chats'),
                    _tab(context, 4, Icons.person_outline_rounded,
                        Icons.person_rounded, 'Profile'),
                  ]
                : [
                    _tab(context, 0, Icons.auto_awesome_outlined,
                        Icons.auto_awesome, 'Discover'),
                    _tab(context, 1, Icons.grid_view_outlined,
                        Icons.grid_view, 'Browse'),
                    _tab(context, 2, Icons.forum_outlined, Icons.forum,
                        'Chats'),
                    _tab(context, 3, Icons.person_outline_rounded,
                        Icons.person_rounded, 'Profile'),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    int i,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final bool selected = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 23,
              color: selected ? AppColors.forest : AppColors.muted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.forest : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sellTab(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.clay,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.clay.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 1),
            Text(
              'Sell',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.clay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
