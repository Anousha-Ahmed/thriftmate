import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'my_orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderIds,
    this.paidByCard = false,
  });

  final List<String> orderIds;
  final bool paidByCard;

  String _short(String id) =>
      '#${(id.length <= 6 ? id : id.substring(0, 6)).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final ids = orderIds.map(_short).join(', ');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E9E5B).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 56, color: Color(0xFF2E9E5B)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Order placed successfully',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                orderIds.length == 1
                    ? 'Order ID: $ids'
                    : 'Order IDs: $ids (one per seller)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              Text(
                paidByCard
                    ? 'Payment received. Your order is confirmed and the seller has been notified.'
                    : 'The seller has been notified. Pay in cash when your order arrives.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                  );
                },
                child: const Text('Track order'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: AppColors.primaryDark),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
