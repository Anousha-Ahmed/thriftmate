import '../models/shop_order.dart';

/// Sales for one calendar day, used by the seller dashboard chart.
class DailySales {
  const DailySales({
    required this.day,
    required this.orders,
    required this.revenue,
  });

  final DateTime day;
  final int orders;
  final int revenue;

  String get weekdayShort {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }
}

/// Orders placed on each of the last [days] days (oldest first), counted from
/// [now]. Revenue uses the order subtotal, so delivery fees are excluded.
List<DailySales> last7DaysSales(
  List<ShopOrder> orders, {
  DateTime? now,
  int days = 7,
}) {
  final today = now ?? DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  final start = end.subtract(Duration(days: days - 1));

  final counts = List<int>.filled(days, 0);
  final revenue = List<int>.filled(days, 0);

  for (final order in orders) {
    final created = order.createdAt?.toLocal();
    if (created == null) continue;
    final day = DateTime(created.year, created.month, created.day);
    final index = day.difference(start).inDays;
    if (index < 0 || index >= days) continue;
    counts[index] += 1;
    revenue[index] += order.subtotal;
  }

  return List.generate(days, (i) {
    final day = start.add(Duration(days: i));
    return DailySales(day: day, orders: counts[i], revenue: revenue[i]);
  });
}
