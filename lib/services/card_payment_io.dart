import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'payment_service.dart';

/// Opens Stripe's native Payment Sheet (Android, iOS).
Future<void> presentCardPayment(
  BuildContext context,
  CardPaymentSession session,
) async {
  try {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: session.clientSecret,
        merchantDisplayName: 'ThriftMate',
        style: ThemeMode.light,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) {
      throw const PaymentException('Payment cancelled.');
    }
    throw PaymentException(
      e.error.localizedMessage ?? 'Card payment failed. Please try again.',
    );
  }
}
