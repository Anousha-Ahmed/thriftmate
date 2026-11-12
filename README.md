# ThriftMate

A pre-loved clothing marketplace for Pakistan, built with Flutter + Firebase.
ThriftMate goes past a normal "list and browse" marketplace with three
signature ideas:

1. **Swipe to discover** — a Tinder-style deck for listings (drag to save,
   drag left to pass, undo, open details).
2. **Offers** — a real buyer/seller negotiation. Buyers send an offer from the
   item page, sellers accept or decline in chat, and an accepted price flows
   straight into checkout.
3. **Rehoming counter** — the profile counts the pieces you have sold or
   received, so your thrift activity is visible at a glance.

> This project ships with **no demo/seed data**. Every listing, profile,
> chat and order comes from Firestore, so screens show honest empty states
> until real data exists.

---

## Features

| Area | What it does |
| --- | --- |
| Onboarding & auth | Email/password, Google sign-in, password reset, unique usernames, profile completion, buyer/seller role. Auth code is unchanged from the original project. |
| Discover | Swipe deck of active listings with filters (category, condition), save/pass/undo, cart badge, notification bell, and chat/offer shortcuts. Your own pieces get a "Your listing" badge and open as a preview. |
| Browse | Search, category chips, two-column grid, saved hearts, product detail, plus a **Filter** sheet: sort (newest / price low→high / price high→low), size, condition, brand (only brands that actually have stock) and a PKR price range. |
| Offers & chat | Start a plain chat ("Chat") or send an offer, 5/10/15% quick amounts, counter-offers, accept/decline, live thread, deal banner and "Buy at Rs X". |
| Ratings & reviews | After delivery the buyer rates the seller 1–5 stars with an optional comment (one review per order). The seller's average stars and latest reviews appear on every item page, and the dashboard shows the live average. |
| Notifications | In-app bell with unread badge. New order, shipping/delivery updates, new offer, accepted/declined offer, chat replies and new reviews each create a notification that deep-links to the order or chat. |
| Cart & checkout | In-memory cart (items are one-of-a-kind), add-to-cart from Browse/Discover/detail, per-seller delivery fee, shipping address, cash on delivery, and card payment through Stripe when a publishable key is supplied. |
| Orders | One order per seller created in a transaction, items marked sold atomically, buyer tracking timeline (with the review CTA), seller shipping status. |
| Profile | Buyer mode: orders / delivered / saved counts and saved closet. Seller mode adds listings / sold counts, rehoming count and shop tools. |
| Seller tools | Seller mode shell (Shop / Listings / Chats / Profile), stats, **7-day sales chart**, average rating, pending orders, add/edit listings (up to 4 compressed photos stored as base64), orders received. |

## Running

```bash
flutter pub get
flutter run -d chrome   # or an Android/iOS device
flutter test            # 48 tests, no Firebase needed
flutter analyze

# With card payments enabled (see "Card payments (Stripe)"):
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
# or keep the key in a local, git-ignored .env file:
flutter run --dart-define-from-file=.env
```

Firebase project: `thriftmate-f93cd` (configured in `lib/firebase_options.dart`
and the platform folders). Google Sign-In on Android uses the Web client ID in
`lib/config/app_config.dart`.

## Startup flow

1. A branded splash (forest background + logo) covers app boot on Android and
   web, so no black frame appears.
2. `SplashScreen` restores the saved Firebase session, then routes.
3. First launch, signed out → 3-slide intro (Skip available) → Login.
4. Later launches with an active session → straight to the buyer/seller home,
   with no login prompt.
5. After signing out, the app opens on Login; the intro is not shown again.

The intro flag lives in `SharedPreferences` (`onboarding_seen_v1`). Clear the
app data (or browser storage) to watch the first-launch flow again.

## Project structure

```
lib/
  config/          app_config.dart (Google web client id),
                   stripe_config.dart (publishable key, PKR→USD rate)
  models/          item, user_profile, shop_order, chat, review,
                   app_notification
  services/        auth, item, order, cart, chat, saved, review,
                   notification, payment_service + card_payment (Stripe)
  screens/         auth screens + shell + discover/browse/chats/thread +
                   detail, cart, checkout, orders, notifications,
                   seller screens
  theme/           app_theme.dart (palette, type, component themes)
  utils/           format, validators, role_router, analytics
  widgets/         app_logo, bottom nav, product card, price tag,
                   thrift photo, offer sheet, status chip, auth inputs,
                   star rating, sales chart, notification bell
functions/         createPaymentIntent + verifyCardPayment (Node 20)
```

Navigation is a single `HomeScreen` shell with a role-aware bottom bar.
Buyer mode has four tabs (Discover · Browse · Chats · Profile). Seller mode
keeps a five-tab bar (Shop · Listings · Sell · Chats · Profile), where Sell
opens the add-listing form. Both roles use the same shell and can switch mode
from Profile.

## Design system

Warm "vintage editorial" look, defined in `lib/theme/app_theme.dart`.

| Token | Hex | Use |
| --- | --- | --- |
| canvas / background | `#FAF6EF` | app background |
| ink / textDark | `#1C1B18` | primary text |
| forest / primary | `#1F3D2E` | brand, buttons, prices |
| forestDeep | `#14281E` | dark surfaces |
| clay / darkAccent | `#B85C3A` | sell action, accents |
| mustard | `#E3A857` | price stickers |
| sage / secondary | `#879A7E` | soft accents |
| line / border | `#E7DFD3` | borders, dividers |
| sand / fill | `#F1E9DC` | image placeholders, chips |
| muted / textMuted | `#8C867B` | secondary text |

Type: **Fraunces** for headings (`.headlineMedium`, `.titleMedium`) and
**DM Sans** for body/UI text, both through `google_fonts`.

The palette keeps the legacy `AppColors` names as aliases, so every older
screen picks up the new theme without rewriting its layout.

## Firestore schema

```
users/{uid}
  name, username, email, role ('buyer' | 'seller')
  savedItems: [itemId, ...]           # written by SavedService

usernames/{username}
  uid                                  # uniqueness registry

items/{itemId}
  sellerId, sellerName, sellerUsername
  name, category, brand, size, condition, price, description
  images: [base64, ...] (max 4, compressed)
  status: 'active' | 'sold'
  views: number
  createdAt: timestamp

orders/{orderId}                       # one per seller per checkout
  buyerId, buyerName, buyerUsername
  sellerId, sellerName, sellerUsername
  lines: [{itemId, name, brand, size, price}]
  subtotal, deliveryFee, status ('pending' | 'shipped' | 'delivered')
  shipping: {name, phone, city, address}
  paymentMethod: 'cod' | 'card'
  paymentStatus: 'due' | 'paid'
  paymentIntentId (card orders only)
  createdAt / shippedAt / deliveredAt

reviews/{orderId}                      # one review per delivered order
  orderId, sellerId, buyerId, buyerName
  rating (1..5), text
  createdAt

notifications/{autoId}
  userId                               # recipient
  title, body
  type: 'order' | 'chat' | 'offer' | 'review' | 'system'
  read: boolean
  orderId / chatId / itemId (deep links, optional)
  createdAt

chats/{itemId}_{buyerId}               # one thread per item + buyer
  itemId, itemName, itemBrand, itemSize, itemPrice
  buyerId, buyerName, buyerUsername
  sellerId, sellerName, sellerUsername
  participants: [buyerId, sellerId]
  lastMessage, lastSenderId, lastAt
  acceptedAmount (optional)            # agreed offer price
  createdAt

chats/{itemId}_{buyerId}/messages/{messageId}
  senderId, senderName
  kind: 'text' | 'offer'
  text (for text messages)
  amount (for offers)
  status: 'pending' | 'accepted' | 'declined' | 'sent'
  createdAt
```

**Accepted offer flow:** seller accepts → `acceptedAmount` is stored on the
thread → buyer sees "Buy at Rs X" → checkout is opened with that price
override → the order line and subtotal use the negotiated price.

Queries deliberately avoid composite indexes: filters and timestamps are
sorted on the client (`activeItems`, `sellerItems`, `buyerOrders`,
`sellerOrders`, thread list).

## Security rules

If your current rules already cover `items`, `users`, `usernames` and
`orders`, keep them and merge in the `reviews`, `notifications` and `chats`
blocks below. The important requirements for the rest of the app are
unchanged:

- signed-in users can read active items and increment `items.views`;
- sellers can create/update/delete their own listings;
- buyers create orders, both parties can read them, sellers update status;
- users can update their own profile, including `savedItems`.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }
    function participants(chatId) {
      return get(/databases/$(database)/documents/chats/$(chatId))
        .data.participants;
    }

    match /items/{itemId} {
      allow read: if true;
      allow create: if signedIn()
        && request.resource.data.sellerId == request.auth.uid;
      allow update: if signedIn()
        && (resource.data.sellerId == request.auth.uid
            || request.resource.data.diff(resource.data)
                 .affectedKeys().hasOnly(['views']));
      allow delete: if signedIn()
        && resource.data.sellerId == request.auth.uid;
    }

    match /users/{uid} {
      allow read: if signedIn();
      allow create, update: if signedIn() && request.auth.uid == uid;
    }

    match /usernames/{username} {
      allow read: if true;
      allow create: if signedIn();
      allow delete: if signedIn() && resource.data.uid == request.auth.uid;
    }

    match /orders/{orderId} {
      allow read: if signedIn()
        && (resource.data.buyerId == request.auth.uid
            || resource.data.sellerId == request.auth.uid);
      allow create: if signedIn()
        && request.resource.data.buyerId == request.auth.uid;
      allow update: if signedIn()
        && resource.data.sellerId == request.auth.uid;
    }

    match /reviews/{orderId} {
      allow read: if signedIn();
      allow create: if signedIn()
        && request.resource.data.buyerId == request.auth.uid
        && get(/databases/$(database)/documents/orders/$(orderId))
             .data.buyerId == request.auth.uid
        && get(/databases/$(database)/documents/orders/$(orderId))
             .data.status == 'delivered';
      allow update, delete: if false;
    }

    match /notifications/{notificationId} {
      allow read: if signedIn()
        && resource.data.userId == request.auth.uid;
      allow create: if signedIn();
      allow update: if signedIn()
        && resource.data.userId == request.auth.uid
        && request.resource.data.diff(resource.data)
             .affectedKeys().hasOnly(['read']);
      allow delete: if signedIn()
        && resource.data.userId == request.auth.uid;
    }

    match /chats/{chatId} {
      allow read: if signedIn()
        && request.auth.uid in resource.data.participants;
      allow create: if signedIn()
        && request.resource.data.buyerId == request.auth.uid
        && request.auth.uid in request.resource.data.participants;
      allow update: if signedIn()
        && request.auth.uid in resource.data.participants;

      match /messages/{messageId} {
        allow read: if signedIn()
          && request.auth.uid in participants(chatId);
        allow create: if signedIn()
          && request.auth.uid in participants(chatId)
          && request.resource.data.senderId == request.auth.uid;
        allow update: if signedIn()
          && request.auth.uid in participants(chatId);
      }
    }
  }
}
```

> `chats` uses `set(..., merge: true)`, so the first offer creates the thread
> and later offers update it. Orders are written inside a transaction together
> with marking items sold, so two buyers can never purchase the same piece.

## Card payments (Stripe)

Card checkout is optional and stays hidden until a Stripe publishable key is
passed at build time. Cash on delivery always works.

**1. Get test keys**

1. Create/sign in at <https://dashboard.stripe.com/register>.
2. Keep the dashboard in **Test mode** (toggle at the top right).
3. Open **Developers → API keys**.
4. Copy **Publishable key** (`pk_test_...`) and **Secret key**
   (`sk_test_...`, use "Reveal live key" only for real payments).

**2. Run the app with the publishable key**

```bash
flutter run -d chrome \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
# Android/iOS behave the same
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
```

**3. Deploy the payment functions (secret key stays on the server)**

```bash
firebase login
firebase use thriftmate-f93cd
cd functions && npm install && cd ..
firebase functions:secrets:set STRIPE_SECRET_KEY   # paste sk_test_...
firebase deploy --only functions
```

Cloud Functions need the Blaze (pay-as-you-go) plan; the free Spark plan
cannot deploy them. Until the functions are deployed, choosing card shows
"Card payments are not deployed yet."

**4. Pay with a test card**

`4242 4242 4242 4242`, any future expiry, any CVC, any postal code; the
`4242` card succeeds without 3-D Secure.

**How it works**

- `createPaymentIntent` (callable) re-prices the cart from Firestore (accepted
  offers included) and creates a PaymentIntent. The amount never comes from the
  client.
- Android/iOS show Stripe's native Payment Sheet; the web build opens a Payment
  Element page (Payment Sheet is not available on web).
- `verifyCardPayment` asks Stripe whether the intent really succeeded before
  the order is written as `paymentStatus: 'paid'`.
- Orders store `paymentMethod`, `paymentStatus` and `paymentIntentId`; buyer
  tracking and seller earnings show the payment label.

**Local card demo without the Blaze plan (emulator)**

Cloud Functions and Secret Manager both require the Blaze plan (which needs a
billing card). To demo card checkout without it, run the functions on the
local emulator:

1. Copy `functions/.env.example` to `functions/.env` and paste the Stripe
   **test secret key** (`sk_test_...`). That file is git-ignored and is only
   read locally.
2. Keep this running from the project root:

   ```bash
   firebase emulators:start --only functions
   ```

3. In a second terminal, run the app against the emulator:

   ```bash
   flutter run -d chrome \
     --dart-define-from-file=.env \
     --dart-define=USE_FUNCTIONS_EMULATOR=true
   ```

4. Checkout → Card → test card `4242 4242 4242 4242` works as usual.

`USE_FUNCTIONS_EMULATOR` defaults to false, so release builds keep calling the
deployed backend. On a physical Android device run
`adb reverse tcp:5001 tcp:5001` first.

**Important limitations**

- Stripe does not support Pakistan as a merchant country and does not support
  PKR, so card amounts are charged in **USD at a fixed demo rate**
  (`kPkrPerUsd = 280` in `lib/config/stripe_config.dart`; the Cloud Function
  uses the same constant). This is test-mode only.
- For a real launch in Pakistan use a local gateway (Safepay, PayFast,
  JazzCash) instead of Stripe.
- `flutter_stripe_web` 8.2.0 is pinned with `stripe_platform_interface` 14.1.0
  because 14.2.0 broke its build; remove the override once a newer web release
  lands.
- The demo rules let a buyer create their own order document. For production,
  create the order inside the Cloud Function (or from a payment webhook) so
  `paymentStatus` can only be set by the server.

## Tests

`test/widget_test.dart` contains 46 pure unit tests (no Firebase required) for
money/number formatting, date formatting, per-seller delivery fees, cart
behaviour, platform fees, order helpers, payment labels, PKR→USD conversion,
chat flags, browse/discover filters, browse filter/sort helpers, seller
rating averages, the 7-day analytics grouping and the validators used by the
auth screens.

`test/browse_ui_test.dart` pumps the real Browse screen (no Firebase) and
checks that the filter sheet narrows the grid by size and that price sorting
reorders the results.

## Notes

- Photos are stored as compressed base64 strings inside the item document
  (no Cloud Storage bucket required).
- Payment defaults to cash on delivery (`orders.paymentMethod` = `cod`);
  card orders store `card` / `paid` plus the Stripe payment intent id.
- The cart is intentionally in-memory because thrift listings have quantity 1.
- The rehoming count on the profile is computed from real delivered orders and
  items marked sold.
- Notifications are written best-effort (a failed notification never blocks an
  order, message, offer or review). Deep links open the order timeline or the
  chat thread directly.
- Reviews are keyed by order id, so editing or deleting a rating is impossible
  and a buyer cannot review the same order twice.
- The 7-day chart uses order subtotals (delivery fees excluded) and is drawn
  with a `CustomPainter` — no charting package added.
