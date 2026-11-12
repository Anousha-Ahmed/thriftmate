import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/analytics.dart';

/// Simple bar chart of daily sales, drawn without an extra package.
class SalesChart extends StatelessWidget {
  const SalesChart({super.key, required this.days, this.height = 132});

  final List<DailySales> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    var maxRevenue = 1;
    for (final d in days) {
      if (d.revenue > maxRevenue) maxRevenue = d.revenue;
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarsPainter(days: days, maxRevenue: maxRevenue),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Text(
                  d.weekdayShort,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.days, required this.maxRevenue});

  final List<DailySales> days;
  final int maxRevenue;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 9.0;
    final barWidth = (size.width - gap * (days.length - 1)) / days.length;
    final baseline = size.height;
    final usable = baseline - 8;

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = usable / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(
        Offset(0, baseline - 1), Offset(size.width, baseline - 1), grid);

    var best = 0;
    for (final d in days) {
      if (d.revenue > best) best = d.revenue;
    }

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final ratio = d.revenue / maxRevenue;
      final h = d.revenue == 0 ? 5.0 : 10 + ratio * (usable - 10);
      final left = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - h, barWidth, h),
        const Radius.circular(6),
      );
      final paint = Paint()
        ..color = d.revenue == 0
            ? AppColors.line
            : (d.revenue == best ? AppColors.clay : AppColors.forest);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.maxRevenue != maxRevenue;
}
