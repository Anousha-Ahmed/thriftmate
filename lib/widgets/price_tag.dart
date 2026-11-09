import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// The signature "thrift store price sticker": a slightly rotated, dashed
/// ticket that carries the price. Used on cards and the item detail page.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.price,
    this.caption = 'PRICE',
    this.angle = -0.06,
    this.small = false,
  });

  final String price;
  final String? caption;
  final double angle;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final double fontSize = small ? 14 : 20;
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        painter: _DashedTicketPainter(
          color: AppColors.ink.withValues(alpha: 0.55),
          radius: 10,
          dash: 4,
          gap: 3,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 15,
            vertical: small ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.mustard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null)
                Text(
                  caption!.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: small ? 7.5 : 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: AppColors.ink.withValues(alpha: 0.65),
                  ),
                ),
              Text(
                price,
                style: GoogleFonts.fraunces(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedTicketPainter extends CustomPainter {
  _DashedTicketPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedTicketPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      dash != oldDelegate.dash ||
      gap != oldDelegate.gap;
}
