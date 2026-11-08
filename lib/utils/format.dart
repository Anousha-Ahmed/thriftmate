/// 1200 -> "Rs. 1,200"
String formatPrice(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return 'Rs. ${buffer.toString()}';
}

/// 2026-11-05 15:45 -> "5 Nov 2026, 3:45 PM"
String formatDateTime(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = date.toLocal();
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hour12:$minute $suffix';
}
