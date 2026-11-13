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
  const key = (STRIPE_SECRET_KEY.value() || '').trim();
  if (!key || !key.startsWith('sk_') || key.includes('replace_me')) {
    console.error('STRIPE_SECRET_KEY is missing or still a placeholder.');
    throw new HttpsError(
        'failed-precondition',
        'Server Stripe secret key is not set. Check functions/.env and ' +
        'restart the emulator.');
  }
  return new Stripe(key);
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

      let intent;
      try {
        intent = await stripeClient().paymentIntents.create({
        amount,
        currency: CURRENCY,
        payment_method_types: ['card'],
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
      } catch (err) {
        if (err instanceof HttpsError) throw err;
        console.error('Stripe error:', err);
        throw new HttpsError(
            'failed-precondition',
            `Stripe: ${err.message || 'could not create the payment'}`);
      }

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
 * reaches Firestore. Confirms that the intent
 *  - belongs to this buyer,
 *  - succeeded,
 *  - was created for exactly the items now being ordered (so a cheap payment
 *    cannot be reused for an expensive order), and
 *  - has not already been claimed for a different set of items.
 */
exports.verifyCardPayment = onCall(
    { secrets: [STRIPE_SECRET_KEY] },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            'unauthenticated', 'Please sign in again to confirm your payment.');
      }

      const data = request.data || {};
      const paymentIntentId = data.paymentIntentId;
      if (typeof paymentIntentId !== 'string' || !paymentIntentId.length) {
        throw new HttpsError('invalid-argument', 'Missing payment id.');
      }
      const rawIds = Array.isArray(data.itemIds) ? data.itemIds : [];
      const itemIds = [...new Set(
          rawIds.filter((id) => typeof id === 'string' && id.length))].sort();
      if (itemIds.length === 0) {
        throw new HttpsError('invalid-argument', 'Missing order items.');
      }

      const uid = request.auth.uid;
      const intent = await stripeClient().paymentIntents.retrieve(
          paymentIntentId);

      if (!intent.metadata || intent.metadata.uid !== uid) {
        throw new HttpsError(
            'permission-denied', 'This payment belongs to another account.');
      }
      if (intent.status !== 'succeeded') {
        throw new HttpsError(
            'failed-precondition', 'The card payment was not completed.');
      }

      const paidIds = String(intent.metadata.itemIds || '')
          .split(',').filter(Boolean).sort();
      const sameItems =
        paidIds.length === itemIds.length &&
        paidIds.every((id, i) => id === itemIds[i]);
      if (!sameItems) {
        throw new HttpsError(
            'permission-denied',
            'This payment was made for different items than this order.');
      }

      // Record the claim. Re-verifying the same payment for the same items is
      // fine (retry after a network error); any other use is refused.
      const db = admin.firestore();
      const claimRef = db.collection('paymentClaims').doc(intent.id);
      await db.runTransaction(async (tx) => {
        const claim = await tx.get(claimRef);
        if (claim.exists) {
          const c = claim.data();
          const claimedIds = (c.itemIds || []).slice().sort();
          const same =
            c.uid === uid &&
            claimedIds.length === itemIds.length &&
            claimedIds.every((id, i) => id === itemIds[i]);
          if (!same) {
            throw new HttpsError(
                'already-exists',
                'This payment has already been used for another order.');
          }
          return;
        }
        tx.set(claimRef, {
          uid,
          itemIds,
          amount: intent.amount,
          currency: intent.currency,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      return {
        paymentIntentId: intent.id,
        status: intent.status,
        amount: intent.amount,
        currency: intent.currency,
        totalPkr: Number(intent.metadata.totalPkr || 0),
      };
    });