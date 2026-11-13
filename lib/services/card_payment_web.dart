import 'package:flutter/material.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';

import '../config/stripe_config.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'payment_service.dart';

/// Web has no Payment Sheet, so the Payment Element opens on its own page.
Future<void> presentCardPayment(
  BuildContext context,
  CardPaymentSession session,
) async {
  final paid = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => _CardPaymentPage(session: session)),
  );
  if (paid != true) {
    throw const PaymentException('Payment cancelled.');
  }
}

class _CardPaymentPage extends StatefulWidget {
  const _CardPaymentPage({required this.session});

  final CardPaymentSession session;

  @override
  State<_CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<_CardPaymentPage> {
  bool _paying = false;
  bool _complete = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await WebStripe.instance.confirmPaymentElement(
        ConfirmPaymentElementOptions(
          confirmParams: ConfirmPaymentParams(
            return_url: Uri.base.toString(),
          ),
          redirect: PaymentConfirmationRedirect.ifRequired,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StripeError catch (e) {
      _fail(e.message.isEmpty
          ? 'Card payment failed. Please try again.'
          : e.message);
    } catch (_) {
      _fail('Card payment failed. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Card payment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card_rounded,
                      color: AppColors.forest),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount ${formatPrice(session.totalPkr)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          'Charged as ${usdLabelForPkr(session.totalPkr)} by Stripe',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: PaymentElement(
                clientSecret: session.clientSecret,
                onCardChanged: (details) {
                  final complete = details?.complete ?? false;
                  if (complete != _complete) {
                    setState(() => _complete = complete);
                  }
                },
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _paying || !_complete ? null : _pay,
              child: _paying
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Pay now'),
            ),
          ],
        ),
      ),
    );
  }
}
