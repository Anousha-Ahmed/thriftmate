import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thriftmate/models/item.dart';
import 'package:thriftmate/screens/browse_screen.dart';
import 'package:thriftmate/services/cart_service.dart';
import 'package:thriftmate/theme/app_theme.dart';
import 'package:thriftmate/widgets/product_card.dart';

Item _item(String id, {String size = 'M', int price = 1000}) => Item(
      id: id,
      sellerId: 'seller-1',
      sellerName: 'Ayesha',
      sellerUsername: 'ayesha',
      name: 'Jacket $id',
      category: 'Outerwear',
      brand: 'Levi\'s',
      size: size,
      condition: 'Good',
      price: price,
      description: '',
      images: const [],
      status: 'active',
      views: 0,
    );

Widget _app(List<Item> items) => MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: BrowseScreen(
          items: items,
          savedIds: const <String>{},
          onToggleSaved: (_) {},
          cartCount: 0,
          onOpenCart: () {},
        ),
      ),
    );

Future<void> _pumpTall(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => CartService.instance.clear());

  testWidgets('filter sheet narrows the grid by size', (tester) async {
    await _pumpTall(
      tester,
      _app([
        _item('a', size: 'S'),
        _item('b', size: 'L'),
      ]),
    );

    expect(find.text('Jacket a'), findsOneWidget);
    expect(find.text('Jacket b'), findsOneWidget);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Filter & sort'), findsOneWidget);

    await tester.tap(find.text('L').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Show 1 result'));
    await tester.pumpAndSettle();

    expect(find.text('Jacket a'), findsNothing);
    expect(find.text('Jacket b'), findsOneWidget);
  });

  testWidgets('every buyer card shows Add to cart and it fills the cart',
      (tester) async {
    await _pumpTall(tester, _app([_item('a'), _item('b')]));

    expect(find.text('Add to cart'), findsNWidgets(2));
    expect(find.text('Your listing'), findsNothing);

    await tester.tap(find.text('Add to cart').first);
    await tester.pumpAndSettle();

    expect(CartService.instance.count, 1);
    expect(find.text('In cart'), findsOneWidget);
  });

  testWidgets('a card with no add action shows Your listing', (tester) async {
    await _pumpTall(
      tester,
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 320,
            child: ProductCard(
              product: Product.fromItem(_item('mine')),
              onWishlistTap: () {},
              isOwn: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Your listing'), findsOneWidget);
    expect(find.text('Add to cart'), findsNothing);
  });

  testWidgets('sorting by price puts the cheapest first', (tester) async {
    await _pumpTall(
      tester,
      _app([
        _item('pricy', price: 5000),
        _item('cheap', price: 300),
      ]),
    );

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: low to high'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Show 2 results'));
    await tester.pumpAndSettle();

    // The 2-column grid fills left-to-right, so the cheapest is left-most.
    final cheapX = tester.getTopLeft(find.text('Jacket cheap')).dx;
    final pricyX = tester.getTopLeft(find.text('Jacket pricy')).dx;
    expect(cheapX, lessThan(pricyX));
  });
}
