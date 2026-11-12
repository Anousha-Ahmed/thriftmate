import 'package:flutter_test/flutter_test.dart';

import 'package:thriftmate/models/chat.dart';
import 'package:thriftmate/models/item.dart';
import 'package:thriftmate/models/review.dart';
import 'package:thriftmate/models/shop_order.dart';
import 'package:thriftmate/screens/browse_screen.dart';
import 'package:thriftmate/screens/discover_screen.dart';
import 'package:thriftmate/config/stripe_config.dart';
import 'package:thriftmate/services/cart_service.dart';
import 'package:thriftmate/utils/analytics.dart';
import 'package:thriftmate/utils/format.dart';
import 'package:thriftmate/utils/validators.dart';

Item _item({
  String id = 'i1',
  String sellerId = 'seller-1',
  int price = 1200,
  String name = 'Denim jacket',
  String category = 'Outerwear',
  String condition = 'Good',
  String status = 'active',
  String brand = 'Levi\'s',
  String size = 'M',
  DateTime? createdAt,
}) {
  return Item(
    id: id,
    sellerId: sellerId,
    sellerName: 'Ayesha',
    sellerUsername: 'ayesha',
    name: name,
    category: category,
    brand: brand,
    size: size,
    condition: condition,
    price: price,
    description: 'Barely worn.',
    images: const [],
    status: status,
    views: 0,
    createdAt: createdAt,
  );
}

void main() {
  group('formatNumber', () {
    test('leaves small numbers alone', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(999), '999');
    });

    test('groups thousands', () {
      expect(formatNumber(1000), '1,000');
      expect(formatNumber(1200), '1,200');
      expect(formatNumber(1234567), '1,234,567');
    });

    test('rounds decimals', () {
      expect(formatNumber(1499.6), '1,500');
    });
  });

  group('formatPrice', () {
    test('adds the rupee prefix', () {
      expect(formatPrice(1200), 'Rs. 1,200');
      expect(formatPrice(0), 'Rs. 0');
    });
  });

  group('formatDateTime', () {
    test('formats afternoon times', () {
      expect(formatDateTime(DateTime(2026, 11, 5, 15, 45)),
          '5 Nov 2026, 3:45 PM');
    });

    test('uses 12 for midnight and noon', () {
      expect(formatDateTime(DateTime(2026, 1, 2, 0, 5)),
          '2 Jan 2026, 12:05 AM');
      expect(formatDateTime(DateTime(2026, 1, 2, 12, 0)),
          '2 Jan 2026, 12:00 PM');
    });
  });

  group('deliveryFeeFor', () {
    test('charges once per seller', () {
      expect(
        deliveryFeeFor([
          _item(id: 'a', sellerId: 's1'),
          _item(id: 'b', sellerId: 's1'),
        ]),
        kDeliveryFee,
      );
      expect(
        deliveryFeeFor([
          _item(id: 'a', sellerId: 's1'),
          _item(id: 'b', sellerId: 's2'),
        ]),
        2 * kDeliveryFee,
      );
    });

    test('empty cart has no delivery fee', () {
      expect(deliveryFeeFor(const <Item>[]), 0);
    });
  });

  group('CartService', () {
    setUp(() => CartService.instance.clear());

    test('adds items and sums the subtotal', () {
      final cart = CartService.instance;
      cart.add(_item(id: 'a', price: 1000));
      cart.add(_item(id: 'b', price: 500));

      expect(cart.count, 2);
      expect(cart.subtotal, 1500);
      expect(cart.contains('a'), isTrue);
    });

    test('ignores duplicate thrift items', () {
      final cart = CartService.instance;
      cart.add(_item(id: 'a'));
      cart.add(_item(id: 'a'));

      expect(cart.count, 1);
    });

    test('removes and clears', () {
      final cart = CartService.instance;
      cart.add(_item(id: 'a'));
      cart.add(_item(id: 'b'));

      cart.remove('a');
      expect(cart.count, 1);
      expect(cart.contains('a'), isFalse);

      cart.clear();
      expect(cart.items, isEmpty);
    });
  });

  group('Item money helpers', () {
    test('platform fee is 10 percent of price', () {
      final item = _item(price: 1500);
      expect(item.platformFee, 150);
      expect(item.sellerEarnings, 1350);
    });
  });

  group('ShopOrder helpers', () {
    ShopOrder order(List<OrderLine> lines) => ShopOrder(
          id: 'abcdef123456',
          buyerId: 'buyer',
          buyerName: 'Sara',
          sellerId: 'seller',
          sellerName: 'Ayesha',
          sellerUsername: 'ayesha',
          lines: lines,
          subtotal: 1500,
          deliveryFee: 200,
          status: 'pending',
          shipping: const ShippingAddress(
            name: 'Sara',
            phone: '03001234567',
            city: 'Lahore',
            address: 'Model Town',
          ),
        );

    test('total combines subtotal and delivery', () {
      expect(order(const []).total, 1700);
    });

    test('short id is the first six characters', () {
      expect(order(const []).shortId, 'ABCDEF');
    });

    test('summary counts extra items', () {
      final single = order(const [
        OrderLine(
            itemId: '1', name: 'Jacket', brand: 'Levi\'s', size: 'M', price: 900),
      ]);
      expect(single.itemsSummary, 'Jacket');

      final twoItems = order(const [
        OrderLine(
            itemId: '1', name: 'Jacket', brand: 'Levi\'s', size: 'M', price: 900),
        OrderLine(
            itemId: '2', name: 'Jeans', brand: 'Lee', size: '30', price: 600),
      ]);
      expect(twoItems.itemsSummary, 'Jacket +1 more');
    });

    test('cod orders default to cash on delivery', () {
      expect(order(const []).paidByCard, isFalse);
      expect(order(const []).paymentLabel, 'Cash on delivery');
    });

    test('card orders are labelled as paid', () {
      const cardOrder = ShopOrder(
        id: 'abcdef',
        buyerId: 'buyer',
        buyerName: 'Sara',
        sellerId: 'seller',
        sellerName: 'Ayesha',
        sellerUsername: 'ayesha',
        lines: [],
        subtotal: 1000,
        deliveryFee: 200,
        status: 'pending',
        shipping: ShippingAddress(
          name: 'Sara',
          phone: '03001234567',
          city: 'Lahore',
          address: 'Model Town',
        ),
        paymentMethod: 'card',
        paymentStatus: 'paid',
        paymentIntentId: 'pi_123',
      );
      expect(cardOrder.paidByCard, isTrue);
      expect(cardOrder.paymentLabel, 'Paid by card');
    });
  });

  group('Stripe amount conversion', () {
    test('converts rupees to USD cents at the demo rate', () {
      expect(usdCentsForPkr(280), 100);
      expect(usdCentsForPkr(1400), 500);
      expect(usdCentsForPkr(2800), 1000);
    });

    test('never charges below the 50 cent Stripe minimum', () {
      expect(usdCentsForPkr(10), 50);
      expect(usdCentsForPkr(0), 50);
    });

    test('formats the USD label shown at checkout', () {
      expect(usdLabelForPkr(2800), '\$10.00');
      expect(usdLabelForPkr(140), '\$0.50');
    });
  });

  group('ChatMessage flags', () {
    ChatMessage message({String kind = 'text', String status = 'sent'}) =>
        ChatMessage(
          id: 'm1',
          senderId: 'buyer',
          senderName: 'Sara',
          kind: kind,
          text: '',
          status: status,
        );

    test('offers are recognised', () {
      expect(message(kind: 'offer', status: 'pending').isOffer, isTrue);
      expect(message(kind: 'offer', status: 'pending').isPending, isTrue);
      expect(message().isOffer, isFalse);
      expect(message(status: 'pending').isPending, isTrue);
    });

    test('deal is present only when an amount was accepted', () {
      ChatThread thread(int? accepted) => ChatThread(
            id: 'i1_buyer',
            itemId: 'i1',
            itemName: 'Jacket',
            itemBrand: 'Levi\'s',
            itemSize: 'M',
            itemPrice: 1200,
            buyerId: 'buyer',
            buyerName: 'Sara',
            buyerUsername: 'sara',
            sellerId: 'seller',
            sellerName: 'Ayesha',
            sellerUsername: 'ayesha',
            participants: const ['buyer', 'seller'],
            lastMessage: 'Hi',
            lastSenderId: 'buyer',
            acceptedAmount: accepted,
          );

      expect(thread(null).hasDeal, isFalse);
      expect(thread(900).hasDeal, isTrue);
      expect(thread(900).isSeller('seller'), isTrue);
      expect(thread(900).otherName('buyer'), 'Ayesha');
      expect(thread(900).otherName('seller'), 'Sara');
    });
  });

  group('Validators', () {
    test('email needs a real shape', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('sara@example.com'), isNull);
    });

    test('username allows letters, numbers and underscore', () {
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('bad name'), isNotNull);
      expect(Validators.username('thrift_mate7'), isNull);
    });

    test('new password rules', () {
      expect(Validators.newPassword('short1!'), isNotNull);
      expect(Validators.newPassword('alllowercase1!'), isNull);

      final weak = PasswordCheck.of('alllowercase1!');
      expect(weak.strength, PasswordStrength.medium);

      final strong = PasswordCheck.of('ThriftMate1!');
      expect(strong.strength, PasswordStrength.high);
    });

    test('login password only rejects empty input', () {
      expect(Validators.loginPassword(''), isNotNull);
      expect(Validators.loginPassword('x'), isNull);
    });
  });

  group('Browse category filter', () {
    test('Bridal & Event keeps only wedding pieces', () {
      final items = [
        _item(id: 'bridal', category: 'Bridal & Event', name: 'Lehenga'),
        _item(id: 'tops', category: 'Tops', name: 'Lawn shirt'),
        _item(
          id: 'sold',
          category: 'Bridal & Event',
          name: 'Walima dress',
          status: 'sold',
        ),
      ];

      final result = filterBrowseItems(items, category: 'Bridal & Event');
      expect(result.map((i) => i.id), ['bridal']);
    });

    test('search also matches the category name', () {
      final items = [
        _item(id: 'bridal', category: 'Bridal & Event', name: 'Lehenga'),
        _item(id: 'tops', category: 'Tops', name: 'Lawn shirt'),
      ];

      final result = filterBrowseItems(items, query: 'bridal');
      expect(result.map((i) => i.id), ['bridal']);
    });

    test('other categories still filter exactly', () {
      final items = [
        _item(id: 'tops', category: 'Tops'),
        _item(id: 'bags', category: 'Bags'),
      ];

      final result = filterBrowseItems(items, category: 'Tops');
      expect(result.map((i) => i.id), ['tops']);
    });

    test('own listings stay in the buyer marketplace', () {
      final items = [
        _item(id: 'mine', sellerId: 'me'),
        _item(id: 'theirs', sellerId: 'seller-1'),
      ];

      final result = filterBrowseItems(items);
      expect(result.map((i) => i.id), ['mine', 'theirs']);
    });
  });

  group('Browse filters & sort', () {
    test('size filter matches exact sizes only', () {
      final items = [
        _item(id: 's', size: 'S'),
        _item(id: 'm', size: 'M'),
        _item(id: 'l', size: 'L'),
      ];

      final result = filterBrowseItems(
        items,
        filters: const BrowseFilters(sizes: {'L'}),
      );
      expect(result.map((i) => i.id), ['l']);
    });

    test('groups combine with AND, values inside a group with OR', () {
      final items = [
        _item(id: 'good', condition: 'Good', brand: 'Levi\'s'),
        _item(id: 'new', condition: 'Like New', brand: 'Levi\'s'),
        _item(id: 'fair-zara', condition: 'Fair', brand: 'Zara'),
        _item(id: 'good-zara', condition: 'Good', brand: 'Zara'),
      ];

      final result = filterBrowseItems(
        items,
        filters: const BrowseFilters(
          conditions: {'Good', 'Like New'},
          brands: {'Levi\'s'},
        ),
      );
      expect(result.map((i) => i.id), ['good', 'new']);
    });

    test('price range keeps prices inside the bounds', () {
      final items = [
        _item(id: 'cheap', price: 500),
        _item(id: 'mid', price: 1200),
        _item(id: 'pricey', price: 4000),
      ];

      final result = filterBrowseItems(
        items,
        filters: const BrowseFilters(minPrice: 800, maxPrice: 2000),
      );
      expect(result.map((i) => i.id), ['mid']);
    });

    test('sorts by price in both directions', () {
      final items = [
        _item(id: 'mid', price: 1200),
        _item(id: 'cheap', price: 400),
        _item(id: 'pricey', price: 5000),
      ];

      expect(
        filterBrowseItems(items, filters: const BrowseFilters(sort: BrowseSort.priceLow))
            .map((i) => i.id),
        ['cheap', 'mid', 'pricey'],
      );
      expect(
        filterBrowseItems(items,
                filters: const BrowseFilters(sort: BrowseSort.priceHigh))
            .map((i) => i.id),
        ['pricey', 'mid', 'cheap'],
      );
    });

    test('newest sort puts the latest listing first and undated last', () {
      final items = [
        _item(id: 'old', createdAt: DateTime(2026, 10, 1)),
        _item(id: 'undated'),
        _item(id: 'fresh', createdAt: DateTime(2026, 11, 3)),
      ];

      final result = filterBrowseItems(items);
      expect(result.map((i) => i.id), ['fresh', 'old', 'undated']);
    });

    test('sold pieces never show in browse', () {
      final items = [
        _item(id: 'live'),
        _item(id: 'sold', status: 'sold'),
      ];
      expect(
        filterBrowseItems(items, filters: const BrowseFilters(sizes: {'M'}))
            .map((i) => i.id),
        ['live'],
      );
    });

    test('available brands are unique and alphabetical', () {
      final items = [
        _item(id: '1', brand: 'Zara'),
        _item(id: '2', brand: 'Levi\'s'),
        _item(id: '3', brand: 'Zara'),
        _item(id: '4', brand: ''),
        _item(id: '5', brand: 'Khaadi', status: 'sold'),
      ];

      expect(availableBrands(items), ['Levi\'s', 'Zara']);
    });

    test('price ceiling rounds up to the next 500', () {
      expect(priceCeiling([_item(price: 1200)]), 1500);
      expect(priceCeiling([_item(price: 4200)]), 4500);
      expect(priceCeiling(const []), 5000);
    });

    test('active count reflects how many filters are set', () {
      expect(BrowseFilters.none.isActive, isFalse);
      expect(BrowseFilters.none.activeCount, 0);

      const filters = BrowseFilters(
        sizes: {'M', 'L'},
        conditions: {'Good'},
        minPrice: 500,
        sort: BrowseSort.priceLow,
      );
      expect(filters.isActive, isTrue);
      expect(filters.activeCount, 4);
    });
  });

  group('Seller ratings', () {
    Review review(int rating) => Review(
          id: 'r$rating',
          orderId: 'o$rating',
          sellerId: 'seller',
          buyerId: 'buyer',
          buyerName: 'Sara',
          rating: rating,
          text: '',
        );

    test('averages only real ratings', () {
      expect(averageRating(const <Review>[]), 0);
      expect(averageRating([review(5), review(4)]), 4.5);
      expect(averageRating([review(0), review(3)]), 3.0);
    });

    test('labels one decimal place', () {
      expect(ratingLabel(4.75), '4.8');
      expect(ratingLabel(5), '5.0');
    });
  });

  group('Seller analytics', () {
    ShopOrder order(DateTime? at, {int subtotal = 1000}) => ShopOrder(
          id: 'order-${at?.millisecondsSinceEpoch}',
          buyerId: 'buyer',
          buyerName: 'Sara',
          sellerId: 'seller',
          sellerName: 'Ayesha',
          sellerUsername: 'ayesha',
          lines: const [],
          subtotal: subtotal,
          deliveryFee: 200,
          status: 'delivered',
          shipping: const ShippingAddress(
            name: 'Sara',
            phone: '03001234567',
            city: 'Lahore',
            address: 'Model Town',
          ),
          createdAt: at,
        );

    test('groups orders and revenue by calendar day', () {
      final now = DateTime(2026, 11, 11);
      final days = last7DaysSales([
        order(DateTime(2026, 11, 11, 9)),
        order(DateTime(2026, 11, 11, 20), subtotal: 500),
        order(DateTime(2026, 11, 9), subtotal: 2000),
        order(DateTime(2026, 10, 1), subtotal: 900),
        order(null),
      ], now: now);

      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 11, 5));
      expect(days.last.orders, 2);
      expect(days.last.revenue, 1500);
      expect(days[4].revenue, 2000);
      expect(days.fold<int>(0, (s, d) => s + d.orders), 3);
    });

    test('weekday labels line up with the dates', () {
      final days = last7DaysSales(
        const <ShopOrder>[],
        now: DateTime(2026, 11, 11),
      );
      expect(days.first.weekdayShort, 'Thu');
      expect(days.last.weekdayShort, 'Wed');
    });
  });

  group('Discover deck', () {
    test('hides sold pieces but keeps your own listings', () {
      final items = [
        _item(id: 'other', sellerId: 'seller-2'),
        _item(id: 'mine', sellerId: 'me'),
        _item(id: 'sold', sellerId: 'seller-2', status: 'sold'),
      ];

      final deck = visibleDiscoverItems(items);
      expect(deck.map((i) => i.id), ['other', 'mine']);
    });

    test('applies category and condition filters together', () {
      final items = [
        _item(id: 'jacket', category: 'Outerwear', condition: 'Good'),
        _item(id: 'jacket-new', category: 'Outerwear', condition: 'Like New'),
        _item(id: 'bag', category: 'Bags', condition: 'Good'),
      ];

      final deck = visibleDiscoverItems(
        items,
        category: 'Outerwear',
        condition: 'Good',
      );
      expect(deck.map((i) => i.id), ['jacket']);
    });

    test('keeps every live piece when no filters are set', () {
      final items = [
        _item(id: 'a', sellerId: 's1'),
        _item(id: 'b', sellerId: 's2'),
      ];

      expect(visibleDiscoverItems(items), hasLength(2));
    });
  });
}
