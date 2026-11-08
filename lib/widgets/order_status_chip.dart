import 'package:flutter/material.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final String status;

  Color get _color {
    switch (status) {
      case 'shipped':
        return const Color(0xFF3B7DA8);
      case 'delivered':
        return const Color(0xFF2E9E5B);
      default:
        return const Color(0xFFB7791F);
    }
  }

  String get _label {
    switch (status) {
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
