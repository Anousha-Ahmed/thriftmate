import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/item.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'thrift_photo.dart';

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

/// Editorial product card: tall photo, small-caps brand, price in forest.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onWishlistTap,
    this.onTap,
    this.onAddToCart,
    this.inCart = false,
    this.isOwn = false,
    this.width,
  });

  final Product product;
  final VoidCallback onWishlistTap;
  final VoidCallback? onTap;

  /// Shows an "Add to cart" button when provided.
  final VoidCallback? onAddToCart;
  final bool inCart;

  /// Your own piece: buyers cannot add it to the cart, so it shows a label.
  final bool isOwn;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ThriftPhoto(
                      bytes: product.imageBytes,
                      radius: 19,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        product.condition.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: AppColors.ink,
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
                          color: AppColors.surface.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product.isWishlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: product.isWishlisted
                              ? AppColors.clay
                              : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand.isEmpty
                        ? product.condition.toUpperCase()
                        : product.brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.25,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      if (product.size.isNotEmpty)
                        Text(
                          'Size ${product.size}',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (onAddToCart != null)
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: onAddToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              inCart ? AppColors.forest : AppColors.surface,
                          foregroundColor:
                              inCart ? Colors.white : AppColors.forest,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: inCart ? AppColors.forest : AppColors.line,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              inCart
                                  ? Icons.shopping_bag_rounded
                                  : Icons.add_shopping_cart_rounded,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(inCart ? 'In cart' : 'Add to cart'),
                          ],
                        ),
                      ),
                    )
                  else if (isOwn)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.sand,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Your listing',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
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
}
