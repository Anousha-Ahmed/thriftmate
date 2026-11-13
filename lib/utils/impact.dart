import '../models/item.dart';
import 'format.dart';

/// Rough environmental saving from giving garments a second life.
///
/// These are planning estimates, not measurements. They are based on commonly
/// quoted figures for producing one new garment of each kind (for example
/// about 2,700 litres of water for one cotton T-shirt, and about 7,500 litres
/// for one pair of jeans). Real values vary a lot by fabric and factory, so
/// the UI always labels them as estimates.
class ImpactEstimate {
  const ImpactEstimate({
    required this.pieces,
    required this.waterLitres,
    required this.co2Kg,
  });

  static const ImpactEstimate empty =
      ImpactEstimate(pieces: 0, waterLitres: 0, co2Kg: 0);

  final int pieces;
  final int waterLitres;
  final double co2Kg;

  ImpactEstimate operator +(ImpactEstimate other) => ImpactEstimate(
        pieces: pieces + other.pieces,
        waterLitres: waterLitres + other.waterLitres,
        co2Kg: co2Kg + other.co2Kg,
      );

  /// "8,100 L"
  String get waterLabel => '${formatNumber(waterLitres)} L';

  /// "15 kg"
  String get co2Label => '${co2Kg.round()} kg';
}

class _Factor {
  const _Factor(this.waterLitres, this.co2Kg);
  final int waterLitres;
  final double co2Kg;
}

/// Saving per piece, by listing category (see [kCategories]).
const Map<String, _Factor> _factors = {
  'Tops': _Factor(2700, 5),
  'Bottoms': _Factor(7500, 10),
  'Dresses': _Factor(4000, 8),
  'Bridal & Event': _Factor(5000, 12),
  'Outerwear': _Factor(6000, 15),
  'Shoes': _Factor(8000, 14),
  'Bags': _Factor(4000, 10),
};

/// Used when the category is unknown, and for delivered orders (order lines
/// do not store a category).
const _Factor _average = _Factor(3000, 6);

/// Saving for one piece in [category].
ImpactEstimate impactForCategory(String category) {
  final f = _factors[category] ?? _average;
  return ImpactEstimate(pieces: 1, waterLitres: f.waterLitres, co2Kg: f.co2Kg);
}

/// Saving for a list of items, each counted by its own category.
ImpactEstimate impactForItems(Iterable<Item> items) {
  var total = ImpactEstimate.empty;
  for (final item in items) {
    total = total + impactForCategory(item.category);
  }
  return total;
}

/// Saving for [count] pieces whose category is not known.
ImpactEstimate impactForPieces(int count) {
  if (count <= 0) return ImpactEstimate.empty;
  return ImpactEstimate(
    pieces: count,
    waterLitres: _average.waterLitres * count,
    co2Kg: _average.co2Kg * count,
  );
}
