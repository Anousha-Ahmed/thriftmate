import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// What a product card needs to display (built from an [Item]).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.size,
    required this.condition,
    required this.price,
    this.imageBytes,
    this.isWishlisted = false,
  });

  final String id;
  final String name;
  final String brand;
  final String size;
  final String condition;
  final String price; // already formatted, e.g. "Rs. 1,200"
  final Uint8List? imageBytes;
  final bool isWishlisted;

  factory Product.fromItem(Item item, {bool wishlisted = false}) {
    return Product(
      id: item.id,
      name: item.name,
      brand: item.brand,
      size: item.size,
      condition: item.condition,
      price: formatPrice(item.price),
      imageBytes: item.coverBytes,
      isWishlisted: wishlisted,
    );
  }
}

/// Reusable product card: photo, wishlist heart, condition badge, name,
/// brand, size and price. Used on Home, Explore, Wishlist, etc.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onWishlistTap,
    this.onTap,
    this.width,
  });

  final Product product;
  final VoidCallback onWishlistTap;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: product.imageBytes == null
                        ? const Center(
                            child: Icon(Icons.checkroom_rounded,
                                color: AppColors.secondary, size: 36),
                          )
                        : ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: Image.memory(
                              product.imageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              gaplessPlayback: true,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.condition,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onWishlistTap,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product.isWishlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: AppColors.darkAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.brand} · Size ${product.size}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.price,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.darkAccent,
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
}
