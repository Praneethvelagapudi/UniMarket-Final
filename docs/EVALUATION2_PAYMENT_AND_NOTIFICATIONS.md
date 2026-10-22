# Evaluation 2 payment, audio and notification boundaries

## Payment simulation shipped in this project

The existing pay-at-handover flow remains the default. Enable **Try a test payment** before reserving to use the local mock. The saved reservation supplies the amount. **Continue to test payment** opens the summary; **Pay Now (simulation)** offers success, failure, cancellation and pending outcomes. No Razorpay SDK, checkout, real money, card input or payment secret is used.

`MockPaymentService` starts/resumes a transaction with an attempt ID. Failed/cancelled attempts retry with new IDs. Pending attempts resume the same ID. A successful result is immutable, and repeated acknowledgements are idempotent. The UI re-reads Firestore before showing success. Rules restrict simulation transitions to the booking buyer, keep amount/participants/provider immutable, require the `mock_...` reference, and reject late results after booking cancellation. This is database-authorized **local simulation**, not financial verification. Clients cannot write a Razorpay provider or real-money proof through these rules.

The reservation is held while a test payment is pending/failed/cancelled. Its final success heading/PDF and seller completion are unavailable until simulated success is committed. **Cancel booking** releases the item. No refund is implied by a simulation because no funds moved. Legacy reservations remain payable directly at handover and can issue a reservation confirmation clearly stating payment is not recorded.

## Activating official Razorpay TEST mode later

This requires a Razorpay merchant test account and an authenticated server capable of keeping secrets and verifying payments. Neither a payment backend nor test keys existed in the workspace. Do not put a secret in Dart, web configuration, source archives or logs. Do not switch to Live mode for the evaluation.

1. Create an authenticated backend endpoint that verifies the Firebase ID token, booking ownership, active status and saved total. Calculate integer INR paise from the server record. Create/reuse an order through Razorpay's Orders API with TEST keys stored in server secrets; bind that order to this booking and amount.
2. Add the official Flutter SDK for Android and the official browser checkout for web. Send only the public TEST key ID and server-issued order details to clients. Keep existing local mock records explicitly marked `mock`.
3. Send the checkout payment ID, order ID and signature to the backend. Use the order ID saved by the server and verify the HMAC/signature with the secret. Independently verify payment/order amount, currency, account, state and booking association through Razorpay's API. A client success callback is not proof.
4. Add verified webhooks with signature validation, replay protection and idempotent updates. Reconcile pending attempts with the provider. Permit real provider status writes only from the trusted backend; keep client rules denying them.
5. Test success, failure, cancellation, pending, duplicate callbacks, altered amounts/IDs, restart/reconciliation and refunds as applicable. Only generate a Razorpay test confirmation after server verification. Preserve a prominent TEST indication.

Primary references checked during this task: [Razorpay Flutter integration steps](https://github.com/razorpay/markdown-docs/blob/master/payments/payment-gateway/flutter-integration/standard/integration-steps.md), [official Flutter plugin](https://github.com/razorpay/razorpay-flutter), [API classes](https://razorpay.com/docs/payments/payment-gateway/flutter-integration/standard/payment-methods/api/).

## Voice messages

`record` captures actual microphone PCM; `VoiceClip` wraps it in a validated mono 8 kHz, 16-bit WAV. Limit: **15 seconds / 240,044 file bytes / 320,060 base64 characters**, with a minimum of 0.1 seconds. The UI offers record, stop, cancel, preview and send; failed sends retain the draft and reuse the same message ID on retry. Recording stops when the app loses foreground. Controllers, recorder, player and subscriptions are disposed on navigation/session changes.

Small audio payloads use the existing Firestore architecture: `/conversations/{id}/audio/{messageId}`. Message metadata and payload commit atomically. Only conversation participants can read them. Rules constrain sender, type, payload/duration bounds and immutable matching metadata. Client playback validates the complete WAV header, size and duration. Rules cannot perform a full codec inspection; a hostile participant could still submit bounded malformed bytes, which the player rejects. This is access-controlled transport, not end-to-end encryption or server-side audio moderation. Audio is fetched only on playback, and payload indexing is disabled.

Browser microphone access needs HTTPS or localhost and a supported browser. Permission denial/unavailable devices show an error without sending a fake message. Android requests RECORD_AUDIO. iOS has a microphone usage description, but iOS runtime verification requires macOS/iPhone and was not performed here.

## Notifications

Firestore conversation/message/read streams target the signed-in recipient. Old messages populate unread counts without replaying alerts. New incoming messages can show an in-app banner and, with permission, an Android OS or browser notification. Own messages and repeated snapshots do not create recipient alerts. Opening a foreground chat persists a monotonic read timestamp and clears its unread count; incoming messages while backgrounded remain unread. Notification preferences suppress previews/alerts while retaining unread badges.

Android has separate **Booking confirmations** and **Incoming messages** channels, private lock-screen visibility, and notification cleanup on logout. Supported browsers use the Notifications API after an explicit permission request. Denial does not undo a saved booking or message. Existing booking confirmation alerts remain integrated; simulated-payment booking alerts occur after the saved success state is verified.

These are **local alerts driven by a running app's Firestore listeners**. There is no FCM registration, service-worker push subscription, server notification fan-out or scheduled reminder service. Android may suspend the listener in the background; a terminated app cannot reliably receive notifications. Reliable closed-app delivery requires an authenticated notification backend plus FCM/web push, device-token ownership and logout cleanup, notification permission handling, and physical-device testing. Do not describe current local alerts as server push.

Package documentation: [record](https://pub.dev/packages/record), [audioplayers](https://pub.dev/packages/audioplayers), [printing](https://pub.dev/packages/printing). The PDF embeds the bundled SIL-licensed Noto Sans font; its license is in `assets/fonts/LICENSE.txt`.
