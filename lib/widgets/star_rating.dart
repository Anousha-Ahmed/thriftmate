import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A 1-5 star row. Read-only unless [onChanged] is provided, in which case the
/// stars become tappable.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 16,
    this.onChanged,
    this.color = AppColors.mustard,
  });

  final double rating;
  final double size;
  final ValueChanged<int>? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool interactive = onChanged != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: interactive ? () => onChanged!(i) : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: interactive ? 3 : 0.5),
              child: Icon(
                rating >= i
                    ? Icons.star_rounded
                    : rating >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_border_rounded,
                size: size,
                color: rating >= i - 0.5 ? color : AppColors.line,
              ),
            ),
          ),
      ],
    );
  }
}
