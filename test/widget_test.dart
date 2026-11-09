import 'package:flutter_test/flutter_test.dart';

import 'package:thriftmate/models/chat.dart';
import 'package:thriftmate/models/item.dart';
import 'package:thriftmate/models/shop_order.dart';
import 'package:thriftmate/screens/browse_screen.dart';
import 'package:thriftmate/screens/discover_screen.dart';
import 'package:thriftmate/services/cart_service.dart';
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
}) {
  return Item(
    id: id,
    sellerId: sellerId,
    sellerName: 'Ayesha',
    sellerUsername: 'ayesha',
    name: name,
    category: category,
    brand: 'Levi\'s',
    size: 'M',
    condition: condition,
    price: price,
    description: 'Barely worn.',
    images: const [],
    status: status,
    views: 0,
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
