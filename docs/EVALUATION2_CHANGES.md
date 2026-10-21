# Evaluation 2 change inventory and schema extensions

## Existing behavior retained

No framework, database, auth provider or state-management package was replaced. `lib/main.dart`, campus policy, auth service, photo service, marketplace/detail/upload screens, public Firebase configuration and existing Android signing configuration were preserved. Existing routes, model fields, text/meetup messages, atomic reservation/availability rules, handover payment, search/favourites, seller completion/return/archive and offline reading remain available. No user records were deleted, environment/signing files overwritten, or version-control operations performed.

## Modified source/configuration

| Files | Necessary extension |
| --- | --- |
| `lib/app.dart` | Reset the Navigator by authenticated UID; host user-scoped message listeners only after profile acknowledgement |
| `lib/models/models.dart` | Backward-compatible optional payment fields, truthful payment labels and PDF eligibility |
| `lib/screens/auth_screen.dart`, `profile_screen.dart` | Shared logout confirmation at every UI logout action; notification preferences handle delayed/denied OS permission without overwriting later choices |
| `shell_screen.dart`, `chat_screen.dart` | Unread badges, conversation previews, sender names, real voice controls/playback and safe retry states; existing text/meetup navigation retained |
| `booking_screen.dart`, `bookings_screen.dart` | Optional mock payment, saved state in history/receipt, gated confirmation/PDF and seller completion; handover remains default |
| `lib/services/market_service.dart` | Stable-ID transactional text/voice sends; private payload retrieval/read receipts; optional mock booking fields and completion guard |
| `lib/services/notification_service.dart` | Conditional browser implementation, bounded permission wait and session cleanup |
| Android manifest / `MainActivity.kt` | RECORD_AUDIO, separate incoming-message channel, private notification visibility and cleanup; existing booking channel retained |
| iOS `Info.plist` | Microphone usage description; iOS execution remains unverified on Windows |
| `firestore.rules`, `firestore.indexes.json` | Participant-only immutable audio, private monotonic read receipts, buyer-only mock-state transitions; audio payload indexing disabled |
| `pubspec.yaml`, `pubspec.lock` | Five focused dependencies, bundled PDF font and version 1.0.2+3; existing locked package versions preserved |
| `analysis_options.yaml` | Ignore generated/local `tmp/` evidence and original-source backup during analysis |
| Existing integration tests | Confirmation dialog expectations, expanded actual persistence/payment/PDF/audio coverage and evidence capture |

## New application files

- Screens: `lib/screens/invoice_screen.dart`, `payment_screen.dart`.
- Services: `invoice_service.dart`, `payment_service.dart`, `voice_clip.dart`, `message_center.dart`, `browser_notifications_stub.dart`, `browser_notifications_web.dart` under `lib/services/`.
- Widgets: `lib/widgets/logout_dialog.dart`, `voice_message.dart`.
- Font: `assets/fonts/NotoSans-Regular.ttf` and its SIL license. Bundling avoids a font-network dependency when generating PDFs.

Direct dependencies: `pdf` for document construction, `printing` for cross-platform preview/export, `record` for microphone capture, `audioplayers` for playback, and `web` for browser notification interop. Required platform/transitive packages were added without a broad dependency upgrade. Android SDK platform 35 and CMake 3.22.1 were installed by the build tooling using the existing SDK license setup because the added audio packages require them.

## Schema additions (legacy records need no migration)

| Path / fields | Invariants |
| --- | --- |
| `bookings/{id}`: optional `paymentMethod`, `paymentStatus`, `paymentAttemptId`, `paymentReference`, `paymentUpdatedAt` | Legacy missing fields mean handover/unpaid. New optional simulation starts as `mock/pending` with empty attempt/reference. Only buyer can transition an active mock reservation; total/parties/provider stay immutable. Success uses a `mock_...` reference, cannot be rewritten, and cannot occur after reservation cancellation. |
| `conversations/{id}/messages/{messageId}`: audio variant `senderId`, `type='audio'`, `audioId=messageId`, `durationMs`, `createdAt` | Existing text variant unchanged. Audio metadata and payload must exist atomically and match sender/duration. Messages remain immutable/private to participants. |
| `conversations/{id}/audio/{messageId}`: `senderId`, base64 `data`, `contentType='audio/wav'`, `durationMs`, `createdAt` | Private participant reads; own create only; bounded data/duration; no update/delete; payload not indexed. Codec/header validated before playback. |
| `conversations/{id}/reads/{uid}`: `readAt` | Read/write only by that participant; timestamp cannot go backward or into the future. It records received messages actually seen by a foreground chat. |

No Firebase Storage, gateway secret, server payment proof, FCM token or scheduled-reminder collection was introduced. Consult `EVALUATION2_PAYMENT_AND_NOTIFICATIONS.md` for the precise limits.

## QA and handover additions

New unit/widget tests cover invoices, logout, message state, voice encoding/permissions, notification timeout and delayed preference races. Added device tests exercise real microphone controls and a two-account recipient flow. Tools provide scoped live SDK checks, saved-record snapshots/PDF comparison, Android OS notification evidence and local packaging. New `docs/EVALUATION2_*` files contain the baseline, rubric, testing, contribution draft, runbook, boundaries, inventory and final handover. Generated build/plugin files are tooling output and are not hand-maintained modules.

The original pre-edit snapshot remains under `tmp/eval2-before/`; earlier Review 1 deliverables were not replaced with mocks or republished.
