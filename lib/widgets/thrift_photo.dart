import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Listing photo stored as base64 bytes inside Firestore.
/// Shows a warm placeholder while missing and a soft fallback on bad data.
class ThriftPhoto extends StatelessWidget {
  const ThriftPhoto({
    super.key,
    required this.bytes,
    this.radius = 18,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.checkroom_rounded,
  });

  final Uint8List? bytes;
  final double radius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: bytes == null
          ? _placeholder(context)
          : Image.memory(
              bytes!,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _placeholder(context),
            ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sand, Color(0xFFE9DFCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        placeholderIcon,
        size: 34,
        color: AppColors.muted.withValues(alpha: 0.7),
      ),
    );
  }
}
