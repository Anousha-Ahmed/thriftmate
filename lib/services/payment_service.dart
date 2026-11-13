import 'package:cloud_functions/cloud_functions.dart';

import '../config/stripe_config.dart';
import '../models/item.dart';

class PaymentException implements Exception {
  const PaymentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Data needed to finish a card payment on the client.
class CardPaymentSession {
  const CardPaymentSession({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
    required this.totalPkr,
    this.itemIds = const <String>[],
  });

  final String clientSecret;
  final String paymentIntentId;

  /// Amount in the smallest currency unit (USD cents).
  final int amount;
  final String currency;

  /// Rupee total the function charged for, delivery included.
  final int totalPkr;

  /// Items this payment was created for; sent back when verifying so the
  /// server can tie the payment to exactly this order.
  final List<String> itemIds;
}

/// Creates Stripe PaymentIntents through the `createPaymentIntent`
/// Cloud Function. The secret key lives only in the function's environment.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  Future<CardPaymentSession> createCardSession(List<Item> items) async {
    if (!stripeConfigured) {
      throw const PaymentException(
        'Card payments are not set up. Add the Stripe publishable key first.',
      );
    }
    if (items.isEmpty) {
      throw const PaymentException('Your cart is empty.');
    }

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('createPaymentIntent');
      final response = await callable.call(<String, dynamic>{
        'itemIds': items.map((i) => i.id).toList(),
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final secret = (data['clientSecret'] ?? '') as String;
      if (secret.isEmpty) {
        throw const PaymentException(
          'The payment server did not return a client secret.',
        );
      }
      return CardPaymentSession(
        clientSecret: secret,
        paymentIntentId: (data['paymentIntentId'] ?? '') as String,
        amount: ((data['amount'] ?? 0) as num).toInt(),
        currency: (data['currency'] ?? kStripeCurrency) as String,
        totalPkr: ((data['totalPkr'] ?? 0) as num).toInt(),
        itemIds: items.map((i) => i.id).toList(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(_messageFor(e));
    } on PaymentException {
      rethrow;
    } catch (_) {
      throw const PaymentException(
        'Could not reach the payment server. Check your connection and try again.',
      );
    }
  }

  /// Confirms with Stripe that the intent for [session] actually succeeded
  /// before the app records the order as paid.
  Future<void> verifyCardPayment(CardPaymentSession session) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyCardPayment');
      await callable.call(<String, dynamic>{
        'paymentIntentId': session.paymentIntentId,
        'itemIds': session.itemIds,
      });
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(_messageFor(e));
    } on PaymentException {
      rethrow;
    } catch (_) {
      throw const PaymentException(
        'Could not confirm the card payment. Check your connection and try again.',
      );
    }
  }

  String _messageFor(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unavailable':
      case 'not-found':
        return 'Card payments are not deployed yet. Deploy the Cloud Function first.';
      case 'unauthenticated':
        return 'Please sign in again to pay by card.';
      case 'permission-denied':
        return e.message ?? 'This payment belongs to another account.';
      case 'already-exists':
        return e.message ?? 'This payment has already been used.';
      case 'failed-precondition':
        return e.message ?? 'One of the items is no longer available.';
      case 'invalid-argument':
        return e.message ?? 'This cart cannot be paid by card.';
      default:
        return e.message ?? 'Card payment could not start. Please try again.';
    }
  }
}
