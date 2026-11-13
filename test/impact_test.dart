import 'package:flutter_test/flutter_test.dart';
import 'package:thriftmate/utils/impact.dart';

void main() {
  group('impact estimates', () {
    test('known categories use their own factors', () {
      final tops = impactForCategory('Tops');
      expect(tops.pieces, 1);
      expect(tops.waterLitres, 2700);
      expect(tops.co2Kg, 5);

      final bottoms = impactForCategory('Bottoms');
      expect(bottoms.waterLitres, 7500);
    });

    test('unknown category falls back to the average', () {
      final unknown = impactForCategory('Something else');
      expect(unknown.pieces, 1);
      expect(unknown.waterLitres, 3000);
      expect(unknown.co2Kg, 6);
    });

    test('pieces with no category scale the average', () {
      final three = impactForPieces(3);
      expect(three.pieces, 3);
      expect(three.waterLitres, 9000);
      expect(three.co2Kg, 18);
      expect(impactForPieces(0).pieces, 0);
      expect(impactForPieces(-2).waterLitres, 0);
    });

    test('estimates add up and format for display', () {
      final total = impactForCategory('Tops') + impactForPieces(2);
      expect(total.pieces, 3);
      expect(total.waterLitres, 8700);
      expect(total.waterLabel, '8,700 L');
      expect(total.co2Label, '17 kg');
    });
  });
}
