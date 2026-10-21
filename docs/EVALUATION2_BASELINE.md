# Evaluation 2 baseline — 20 October 2026 (Asia/Kolkata)

Inspected before source edits: Flutter/Dart manifests, Android build/manifest/native notification bridge, Firebase startup/configuration, every application screen, models, auth/market/photo/notification services, Firestore rules/indexes, unit/widget and integration tests, and existing documentation. Existing Review 1 evidence is historical and is not counted as a fresh Evaluation 2 test.

## Protected existing architecture

Flutter Material 3 mobile/web app; `lib/main.dart` initializes Firebase Auth and Firestore. `AppScope` supplies services, `AppSettings` uses ChangeNotifier/shared_preferences, and screens use Firestore streams and local StatefulWidget state. `AuthGate` waits for an acknowledged private campus profile; `ShellScreen` retains five tab states and responsive navigation. Firestore transactions reserve/release listings and persist immutable booking prices. Images use bounded separate Firestore documents on the existing Spark project; no Storage service or payment backend exists. Native Android MethodChannel posts local booking notifications. Firebase client identifiers are public configuration, not administrator secrets.

## Inventory at start

| Area | Existing implementation | Required work |
| --- | --- | --- |
| UI / navigation | Responsive branding, dark mode, marketplace/detail/upload/profile/chat/history/receipt screens | Preserve; test extensions for overflow |
| Authentication | Campus registration/login, validation, profile recovery, Firebase persistent sessions | Add confirmation at every UI logout entry; clear protected route stack |
| Core marketplace | Search/filter, photos, favourites, buy/rent reservations, cancellation, seller handover/return, archive | Preserve and regression test |
| Receipt | Live saved-booking screen with IDs, parties, dates, prices | Add real PDF generation, preview/save/share |
| Chat | Private Firestore conversations and text/meetup messages | Add real microphone audio, private payload storage, read state and alerts |
| Notifications | Actual Android local buyer booking confirmation; settings/permission check | Add recipient message alerts and browser support; distinguish from push |
| Payments | Direct payment at handover; no gateway/backend | Add optional explicitly local mock without changing handover behavior |
| Security | Deny by default; membership, ownership, prices, atomic booking transitions | Extend rules for audio/read receipts/mock states and test attacks |
| Builds | Earlier APK/web artifacts exist; release uses existing debug certificate | Produce fresh outputs; disclose signing limitations |
| Documentation | Review 1 audit/runbook/evidence | New Evaluation 2 rubric/testing/contribution/handover |

## Fresh baseline evidence

- `tmp/eval2-baseline-tests.log`: all **17** existing Flutter tests passed.
- `tmp/eval2-baseline-analysis.log`: **No issues found**, 174.5 seconds.
- Browser startup attempted on port 5176; compilation result recorded in `tmp/eval2-baseline-web.log`.
- Firestore baseline test execution recorded in `tmp/eval2-baseline-rules.log` (result to be added after completion).
- `flutter devices`: Windows, Chrome and Edge available; no connected Android device. Existing Android AVD `UniMarket_Test` is available for a later emulator attempt.
- `git status --short`: **not a git repository**. No Git metadata or version-control changes created.
- Source/configuration snapshot: `tmp/eval2-before/`. No credentials, signing files or existing database records overwritten.

## Concrete risks found by inspection

1. Profile/recovery logout actions sign out immediately; no confirmation exists.
2. AuthGate is only the home route: pushed protected routes can remain visible after an external session loss unless the route stack is reset.
3. Chat writes use generated `.add` IDs and a timeout; retry after an uncertain acknowledgement can duplicate messages. New UI sends need stable IDs and transactional deduplication.
4. No microphone, PDF, unread state or payment simulation exists.
5. Existing native notifications depend on a running app. No server push/FCM service is configured; terminated-app delivery cannot be honestly promised.

No existing feature is labelled broken solely because an old document or fixture exists. Live database changes and deployment must be verified separately from local rules tests.
