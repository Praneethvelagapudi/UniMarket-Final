# UniMarket architecture

UniMarket is one Flutter application targeting Android and web. The supplied Flutter platform scaffolding is retained, while the unrelated e-learning application source is preserved in `docs/original` and replaced with marketplace modules.

## Source responsibilities

| Folder or file | Responsibility |
| --- | --- |
| `lib/main.dart` | Firebase startup, persistent Auth session and Firestore cache configuration |
| `lib/app.dart` | Shared theme, settings persistence and service access through an inherited widget |
| `lib/config` | Owner-confirmed campus input policy and public Firebase app identifiers |
| `lib/models` | Listing and booking data plus rental duration and total calculations |
| `lib/services` | Firebase authentication, transactional marketplace operations, photo compression, device notifications and readable errors |
| `lib/screens` | Auth, responsive app shell, marketplace, details, upload, bookings, chat and profile |
| `lib/widgets` | Reusable item cards, photo display, status labels and loading/error/empty states |
| `firestore.rules` | Backend authorization, data validation and atomic booking transitions |
| `test` | Dart logic and Flutter form/layout/lifecycle tests |
| `tools/firebase/rules.test.mjs` | Firestore emulator security and booking-transition tests |
| `android/.../MainActivity.kt` | Native Android booking notification channel and runtime permission handling |

Screens own temporary form and navigation state with StatefulWidget/setState. Firebase streams supply shared marketplace data and update views after writes. An Auth gate restores the saved account session and requires a completed campus profile before opening the marketplace. Stream subscriptions are scoped to the relevant widgets; controllers are disposed and async callbacks check mounted state.

## Firestore data

| Collection | Stored information | Access |
| --- | --- | --- |
| `users/{uid}` | Name, roll, email, department and signup timestamp | Owner only |
| `users/{uid}/bookmarks/{listingId}` | Saved listing snapshot and timestamp | Owner only |
| `listings/{listingId}` | Description, branch/category, condition, sale/rental prices, seller name/ID, availability and current booking ID | Campus accounts with completed profiles |
| `listing-images/{listingId}` | Compressed JPEG as base64, owner and creation timestamp | Campus members; create only by listing owner |
| `bookings/{bookingId}` | Buyer/seller snapshots, type, rental dates, total, pickup place/time and status | Buyer and seller only |
| `conversations/{conversationId}` | Item and participant identities/names | Participants only |
| `conversations/{conversationId}/messages/{messageId}` | Sender, message text and server timestamp | Participants only |

Public listing snapshots expose a seller's display name, not their roll number or email. Registration checks `CB.SC.U4` followed by an alphabetic branch and numeric student suffix, with a matching email prefix at `cb.students.edu`. Case and whitespace are normalized. Inbox verification is disabled at the owner's request; these checks establish format compliance, not proof of institutional identity.

## Reservations and pricing

Both purchase and rental reservations atomically create a booking and change the item from available to reserved. The server rules independently verify identity, availability, participants, dates and published price. A single active reservation is permitted per item; future rental dates do not permit overlapping simultaneous reservations.

Cancellation atomically marks the booking cancelled and restores availability. The seller completes a booking after handover or rental return. A completed sale changes the item to sold; a completed rental makes it available again. Completed/cancelled bookings remain immutable in history. Archiving an available listing hides it from Discover without deleting history.

Rental return dates are exclusive: 6–7 October is one day. Rentals last 1–90 days. Payment is arranged directly at campus handover; the application does not process money. Bargaining messages are persisted, and booking totals use published prices rather than interpreting free-text messages as financial commitments.

## Spark plan photos and caching

The owner selected Firestore photos to keep the existing project on Spark. Input images are capped at 5 MB and compressed to a JPEG no larger than 180,000 bytes, generally with a maximum dimension of 800 pixels. A separate photo document avoids attaching image payloads to every listing query. Photo payload indexing is disabled. Firebase Storage and a billing upgrade are not required.

Firestore persistence caches loaded listings, favourites, conversations and photos on Android and in supported browsers. Previously read data remains available offline; items/messages never loaded on that device cannot be cached retroactively. A cache indicator describes saved data while checking for server updates. Reservations and status transitions use server transactions and cannot confirm offline. Message sending checks server access before acknowledging delivery; timed-out writes may still appear later, so the user is told to refresh before retrying.

## Notifications

After a successful reservation, Android requests notification permission where required and posts a real device notification containing the item, pickup time and location. Permission denial cannot undo a successful booking. The persisted receipt remains available. Settings include a notification switch and a device-notification check for the demo. Android owns the notification channel; no Firebase Cloud Messaging server or remote-push setup is required for the rubric's booking-confirmed option. This implementation does not schedule reminders or send seller push notifications.

## Team presentation preparation

Suggested module ownership follows the four team members listed in the supplied overview. The team should agree on the assignment rather than treating this suggestion as an attendance claim:

1. Authentication, campus validation and session/logout behavior.
2. Marketplace, upload, filtering, favourites and responsive UI.
3. Booking transactions, cancellation, tracking, confirmation and device notifications.
4. Chat, meetup planning, offline cache and backend security rules.

Each presenter should show one working interaction, explain the model/service/screen separation, and describe an error case tested in their module. A signed physical blueprint and actual presentation require human completion and evidence.
