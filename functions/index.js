const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const Stripe = require('stripe');

admin.initializeApp();

// firebase functions:secrets:set STRIPE_SECRET_KEY
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');

// Keep these in sync with lib/config/stripe_config.dart and lib/models/item.dart.
const PKR_PER_USD = 280;
const CURRENCY = 'usd';
const DELIVERY_FEE_PKR = 200;
const PLATFORM_FEE_RATE = 0.1;
const MAX_ITEMS = 20;

function usdCentsForPkr(pkr) {
  const cents = Math.round((pkr / PKR_PER_USD) * 100);
  return Math.max(50, cents);
}

function stripeClient() {
  return new Stripe(STRIPE_SECRET_KEY.value());
}

/**
 * Prices a cart from Firestore, never from the client. Accepted offers in
 * chats/{itemId}_{buyerId} replace the listed price for that buyer.
 */
async function priceCart(db, itemIds, buyerUid) {
  const snaps = await db.getAll(
      ...itemIds.map((id) => db.collection('items').doc(id)));

  let subtotal = 0;
  const sellers = new Set();

  for (const snap of snaps) {
    const data = snap.data();
    if (!data || data.status !== 'active') {
      throw new HttpsError(
          'failed-precondition',
          'One of the items in your cart is no longer available.');
    }
    if (data.sellerId === buyerUid) {
      throw new HttpsError(
          'failed-precondition', 'You cannot buy your own item.');
    }

    const listed = Math.round(Number(data.price) || 0);
    if (listed <= 0) {
      throw new HttpsError(
          'failed-precondition', 'One of the items has no valid price.');
    }

    const thread = await db
        .collection('chats')
        .doc(`${snap.id}_${buyerUid}`)
        .get();
    const accepted = thread.get('acceptedAmount');
    const agreed =
      typeof accepted === 'number' && accepted > 0 && accepted < listed ?
        Math.round(accepted) :
        listed;

    subtotal += agreed;
    sellers.add(data.sellerId);
  }

  const deliveryFee = sellers.size * DELIVERY_FEE_PKR;
  return { subtotal, deliveryFee, totalPkr: subtotal + deliveryFee };
}

exports.createPaymentIntent = onCall(
    { secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            'unauthenticated', 'Please sign in again to pay by card.');
      }

      const raw = request.data && request.data.itemIds;
      const itemIds = Array.isArray(raw) ?
        [...new Set(raw.filter((id) => typeof id === 'string' && id.length))] :
        [];
      if (itemIds.length === 0) {
        throw new HttpsError('invalid-argument', 'Your cart is empty.');
      }
      if (itemIds.length > MAX_ITEMS) {
        throw new HttpsError(
            'invalid-argument', 'Too many items for a single card payment.');
      }

      const uid = request.auth.uid;
      const db = admin.firestore();
      const { subtotal, deliveryFee, totalPkr } = await priceCart(
          db, itemIds, uid);
      const amount = usdCentsForPkr(totalPkr);

      const intent = await stripeClient().paymentIntents.create({
        amount,
        currency: CURRENCY,
        automatic_payment_methods: { enabled: true },
        description: `ThriftMate order · ${itemIds.length} item(s)`,
        metadata: {
          uid,
          itemIds: itemIds.join(','),
          totalPkr: String(totalPkr),
          subtotalPkr: String(subtotal),
          deliveryFeePkr: String(deliveryFee),
          platformFeePkr: String(Math.round(subtotal * PLATFORM_FEE_RATE)),
        },
      });

      return {
        clientSecret: intent.client_secret,
        paymentIntentId: intent.id,
        amount,
        currency: CURRENCY,
        totalPkr,
        subtotalPkr: subtotal,
        deliveryFeePkr: deliveryFee,
      };
    });

/**
 * Called by the app after the card sheet closes so a forged "paid" flag never
 * reaches Firestore. Confirms the intent belongs to this buyer and succeeded.
 */
exports.verifyCardPayment = onCall(
    { secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            'unauthenticated', 'Please sign in again to confirm your payment.');
      }

      const paymentIntentId =
        request.data && request.data.paymentIntentId;
      if (typeof paymentIntentId !== 'string' || !paymentIntentId.length) {
        throw new HttpsError('invalid-argument', 'Missing payment id.');
      }

      const intent = await stripeClient().paymentIntents.retrieve(
          paymentIntentId);

      if (!intent.metadata || intent.metadata.uid !== request.auth.uid) {
        throw new HttpsError(
            'permission-denied', 'This payment belongs to another account.');
      }
      if (intent.status !== 'succeeded') {
        throw new HttpsError(
            'failed-precondition', 'The card payment was not completed.');
      }

      return {
        paymentIntentId: intent.id,
        status: intent.status,
        amount: intent.amount,
        currency: intent.currency,
        totalPkr: Number(intent.metadata.totalPkr || 0),
      };
    });
