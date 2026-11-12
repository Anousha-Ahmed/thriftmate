/// Stripe publishable key, supplied at build time:
/// `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
/// Card payments stay hidden when this is empty.
const String kStripePublishableKey =
    String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

bool get stripeConfigured => kStripePublishableKey.isNotEmpty;

/// Stripe does not support PKR, so card payments are charged in USD using a
/// fixed demo rate. The Cloud Function uses the same rate to build the intent.
const double kPkrPerUsd = 280;
const String kStripeCurrency = 'usd';

/// Converts a rupee total into USD cents for display and for the server.
int usdCentsForPkr(int pkr) {
  final cents = (pkr / kPkrPerUsd * 100).round();
  return cents < 50 ? 50 : cents;
}

String usdLabelForPkr(int pkr) =>
    '\$${(usdCentsForPkr(pkr) / 100).toStringAsFixed(2)}';
