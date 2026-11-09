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
| Discover | Swipe deck of other sellers' active listings with filters (category, condition), save/pass/undo, cart badge, and chat/offer shortcuts. Your own listings stay out of the deck. |
| Browse | Search, category chips, two-column grid, saved hearts, product detail. |
| Offers & chat | Start a plain chat ("Chat") or send an offer, 5/10/15% quick amounts, counter-offers, accept/decline, live thread, deal banner and "Buy at Rs X". |
| Cart & checkout | In-memory cart (items are one-of-a-kind), per-seller delivery fee, shipping address, cash on delivery. |
| Orders | One order per seller created in a transaction, items marked sold atomically, buyer tracking timeline, seller shipping status. |
| Profile | Listings / sold / saved counts, saved closet, rehoming count, seller dashboard entry, orders, reset password, logout. |
| Seller tools | Seller mode shell (Shop / Listings / Chats / Profile), stats and pending orders, add/edit listings (up to 4 compressed photos stored as base64), orders received. |

## Running

```bash
flutter pub get
flutter run -d chrome   # or an Android/iOS device
flutter test            # 27 unit tests, no Firebase needed
flutter analyze
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
  config/          app_config.dart (Google web client id)
  models/          item, user_profile, shop_order, chat
  services/        auth, item, order, cart, chat, saved
  screens/         auth screens + shell + discover/browse/chats/thread +
                   detail, cart, checkout, orders, seller screens
  theme/           app_theme.dart (palette, type, component themes)
  utils/           format, validators, role_router
  widgets/         app_logo, bottom nav, product card, price tag,
                   thrift photo, offer sheet, status chip, auth inputs
```

Navigation is a single `HomeScreen` shell with a five-tab bottom bar
(Discover · Browse · Sell · Chats · Profile). Sell opens the add-listing form;
both roles land in the same shell and can switch mode from Profile.

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
  paymentMethod: 'cod'
  createdAt / shippedAt / deliveredAt

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
`orders`, keep them and merge in the `chats` block below. The important
requirements for the rest of the app are unchanged:

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

## Tests

`test/widget_test.dart` contains pure unit tests (no Firebase required) for
money/number formatting, date formatting, per-seller delivery fees, cart
behaviour, platform fees, order helpers, chat flags, browse/discover filters
and the validators used by the auth screens.

## Notes

- Photos are stored as compressed base64 strings inside the item document
  (no Cloud Storage bucket required).
- Payment is cash on delivery; `orders.paymentMethod` is `cod`.
- The cart is intentionally in-memory because thrift listings have quantity 1.
- The rehoming count on the profile is computed from real delivered orders and
  items marked sold.
