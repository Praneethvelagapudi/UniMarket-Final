# Learning the UniMarket project

UniMarket uses one Flutter codebase for Android and web. Firebase Authentication stores accounts. Firestore stores profiles, items, bookings and conversations. Android also uses a small Kotlin bridge to show a device notification.

## Start with these files

Read `lib/main.dart`, then `lib/app.dart`, `lib/screens/auth_screen.dart` and `lib/screens/shell_screen.dart`. The README's operation table points to every feature. `docs/ARCHITECTURE.md` explains all collections and access rules.

`main()` initializes Flutter, reads saved settings, starts Firebase and creates the shared services. Public Uni-Market identifiers are bundled in `lib/config/firebase_config.dart`, so a normal Flutter or VS Code launch connects without extra arguments. `config/firebase.json` can override the identifiers through build-time Dart declarations; VS Code's supplied launch configurations pass that file. An explicitly missing or invalid configuration still produces a setup screen. These public identifiers do not grant administrator access.

`UniMarketApp` builds the Material theme. `AppScope` makes the services available to screens through `AppScope.of(context)`. `AuthGate` observes the Firebase account, loads that account's private campus profile, and shows either the auth form, profile recovery or marketplace shell. Firebase retains the login across process restarts. Sign out clears the account and returns to the auth screen.

## A screen, a service and a model do different jobs

A **screen** renders widgets and handles local form state. A **service** performs Firebase operations. A **model** turns stored document fields into useful Dart objects and performs shared calculations. This separation lets presenters explain a feature without reading the entire app.

For example, `BookingScreen` holds rental dates and the pickup location. It checks the form, shows the total and calls `MarketService.createBooking()`. That service runs a transaction which writes a booking and reserves the listing. `firestore.rules` independently checks the request. The receipt listens to the saved booking document and renders its buyer, seller, dates, location, total and status. A successful Android reservation then uses `NotificationService` and `MainActivity.kt` to post the device alert.

## Registration

`CampusPolicy` accepts `CB.SC.U4`, an alphabetic branch and a numeric student suffix. The email prefix must match the roll at `cb.students.edu`. Upper/lower case and surrounding whitespace are normalized. The name, password confirmation and empty fields also receive validation feedback.

`AuthService.register()` creates the Firebase account and then writes `users/{uid}`. If the profile write fails, the recovery form can complete it without creating another account. Inbox verification is disabled as requested. Explain this honestly: roll and email format checks do not prove that a person owns an institutional inbox.

## Own items and photographs

`UploadScreen` collects the title, description, department, category, condition and buy/rent prices. Gallery selection works on Android and web; Android also offers camera capture. A seller can enable buy, rent or both. `PhotoService` decodes the image, fixes orientation, resizes it and compresses a JPEG within 180,000 bytes. `MarketService.publish()` atomically writes the listing and its optional `listing-images` document.

The app uses Firestore photos to retain Spark. It does not use paid Firebase Storage. A separate image document keeps the photo out of ordinary listing queries. `ItemImage` in `lib/widgets/common.dart` loads the stored photo or shows a category icon. A successful upload immediately becomes visible to another signed-in account through the listing stream.

## Buy, rent, cancel and complete

A listing starts as **available**. A purchase or rental reservation sets it to **reserved** and creates a **confirmed** booking. Only one active reservation can hold that item. A student cannot reserve their own item.

A cancellation sets the booking to **cancelled** and makes the listing **available** again. The item owner completes a reservation after handover or rental return. A completed rental restores availability; a completed sale makes the listing **sold**. The history remains stored. The owner can archive an available listing under **You**.

Rentals use an exclusive return date. 6–9 October is three days. At ₹15 per day, the saved total is ₹45. Both the service and backend rules verify the total and valid dates. Payment happens directly at campus handover. Chat bargaining does not change the published booking price automatically.

## Two-way chat and pickup

The customer opens an item and taps **Chat with seller**. `openConversation()` creates an item-specific conversation with both participant IDs. `sendMessage()` writes the sender, text and server timestamp. `ChatScreen` listens to its message query, so replies on one phone appear on the other. **Messages** lists conversations for either role. Pickup proposals use the same conversation; the final booking stores the agreed location and time.

There is no global administrator dashboard in the app. The requested demo access consists of a customer and an item owner. Any campus account can be a seller for its own listings, and the rules restrict management to the appropriate owner or booking participants.

## State, navigation and errors

StatefulWidget/setState controls temporary forms, busy indicators and the selected navigation tab. Firestore streams control persistent marketplace state. The shell adapts from bottom navigation to a desktop rail. It retains its tab state and returns to Discover when Android back is pressed from another tab. Receipt navigation returns to the campus market without leaving a stack of old booking forms.

Controllers are disposed and async callbacks check `mounted` before updating the UI. Shared widgets provide loading, empty and error states. `lib/services/errors.dart` turns Firebase and network errors into readable messages. Reservations need internet access; a transaction cannot be confirmed offline.

Firestore caches previously fetched data. The Android integration test disables the network and reads cached bookmarks and chat. Content never fetched on a device cannot appear offline. After a timed-out write, refresh before retrying because the original request might still commit.

## Backend security and verification

`firestore.rules` checks account/profile eligibility, ownership, document fields, private participants, prices and atomic booking state changes. The UI alone never grants access. `firestore.indexes.json` disables indexing of large image payloads. The rules are deployed to the owner's Uni-Market project.

Read `test/` for form, campus, calculation, image and lifecycle checks. `test/auth_gate_test.dart` checks registration timing, account switching and offline profile access. `AuthService.watchProfile` includes metadata changes: `AuthGate` waits while `hasPendingWrites` is true because a local profile alone cannot satisfy the server's campus-membership rules. A profile stream keyed by user UID prevents an old account's profile from opening the next account's shell. `tools/firebase/rules.test.mjs` runs 17 isolated security tests against the local Firestore emulator. `integration_test/market_flow_test.dart` exercises actual cloud registration, photos, saved items, chat, booking/cancellation, rental return and Android notification delivery. `session_restore_test.dart` runs twice to verify a login in a fresh process without calling login again.

## Explaining the project during review

Show an action on screen, point to its screen/service/model files, and then show the resulting Firebase document or receipt. Explain one failed action such as an invalid roll/email, a wrong password, self-booking or double booking. Use the proposed module split in the architecture document after the team agrees on it. The prepared slides have speaker notes for each topic.

The software cannot supply a human signature, retroactively meet a submission deadline or prove every member attended. The rubric audit records those requirements separately. Print `UniMarket_Blueprint.pdf`, obtain real signatures and confirm the submission history with your faculty.
