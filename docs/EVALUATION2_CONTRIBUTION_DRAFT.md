# Individual contribution report — draft for student verification

Student name: ____________________  Roll number: ____________________

Course: Mobile Application Development – 23CSE465

Project: UniMarket — Evaluation 2

This is an editable factual draft of work performed in this assisted development session. The student must verify attribution, describe their own learning/work accurately, and follow the institution's rules on assisted development. No person, commit, attendance, presentation or independent authorship is invented here.

## Existing work preserved

The project already contained Flutter Material 3 branding/responsive layouts, Firebase registration/login/campus profiles and persistent sessions, marketplace search/filter/detail/upload/photo compression, favourites, transactional buy/rent reservations and receipts, cancellation/handover/return/archive, private text/meetup chat, Android local booking notifications, dark mode/cache preferences, baseline tests, Android/web configuration, and Review 1 documentation. These are not new contributions from this task.

## Work added during this session

| Module | Contribution | Main files |
| --- | --- | --- |
| Session/logout | Shared themed Cancel/Logout dialog, busy/error/retry handling, session-keyed Navigator reset, notification cleanup | `lib/widgets/logout_dialog.dart`, `lib/app.dart`, auth/profile screens, native notification bridge |
| Confirmation documents | Server-read eligibility, branded INR PDF using saved fields, unpaid and simulation labels, preview/download/share/print | `lib/services/invoice_service.dart`, `lib/screens/invoice_screen.dart`, booking receipt screen, bundled Noto Sans |
| Payment demonstration | Optional local mock preserving handover; saved summary, pending/failed/cancelled/success, stable attempts, retries and server-record recheck | `lib/services/payment_service.dart`, `lib/screens/payment_screen.dart`, booking service/model/UI |
| Voice chat | Microphone recording, bounded WAV encoding/validation, stop/cancel/preview/send, private atomic payload persistence, retry-safe IDs, playback | `lib/services/voice_clip.dart`, market service, `lib/widgets/voice_message.dart`, chat screen, Android/iOS permission descriptions |
| Message state/alerts | Recipient streams, persisted read timestamps, unread badges, sender previews, own-message/replay suppression, active-chat behavior, browser and native local alerts | `lib/services/message_center.dart`, browser notification adapters, shell/chat/profile, native Android activity |
| Security | Participant-only audio, payload limits/immutability, owned monotonic receipts, constrained buyer-only simulation transitions, indexing disabled for payloads | `firestore.rules`, `firestore.indexes.json`, rules test suite |
| QA/readiness | Baseline inventory, new unit/widget/security tests, extended device/session tests, PDF visual QA, build attempts, final audit and runbook | `test/`, `integration_test/`, `tools/firebase/rules.test.mjs`, `docs/EVALUATION2_*` |

Direct additions: `pdf` (document layout), `printing` (cross-platform preview/export), `record` (real microphone capture), `audioplayers` (audio playback), and `web` (browser Notifications API). Firebase, state management, routing approach, database technology and existing UI theme were retained. Dependency resolution added their required platform/transitive packages; no general package upgrade was requested or performed.

## Challenges and solutions

- Existing Spark architecture had no Storage or payment server. Small private WAV documents reuse Firestore; a clearly labelled local payment mock avoids exposing secrets or falsely confirming real payments.
- A home-only auth gate cannot remove pushed screens by itself. The Navigator now resets by authenticated UID; tests cover logout and external session loss.
- Network acknowledgement can be uncertain. Transactional stable message/payment IDs make retries safe; booking transactions retain their existing availability lock.
- Notifications and recording have platform limits. Conditional browser code and Android bridges preserve both build targets; the handover distinguishes local alerts from closed-app push and documents device checks.
- Initial security-test launcher found a port already occupied by the baseline emulator. The suite reused that isolated emulator and passed; no cloud data was cleared.
- A new logout test fixture initially failed to replay auth state like Firebase. Its semantics were corrected and the full suite passed.

## Testing actually completed so far

Fresh baseline: 17 Flutter tests and 17 Firestore cases passed. Extended suites: 39 Flutter tests and 26 Firestore cases passed. Ten focused logout/message cases passed. Two one-page PDF fixtures were generated, text-extracted, rasterized and visually inspected. Firestore changes compiled and deployed successfully to the existing project. Two concurrent SDK clients exchanged messages in real time and verified private read receipts. Browser session restoration, logout Cancel, unread state and failed/pending mock-payment flows were observed. The embedded browser's unanswered microphone prompt exposed a cancellation issue; Cancel remains usable and timeout/denial tests now pass. Consult the final testing record for subsequent build/device/browser results rather than assuming this draft proves hardware or two-phone testing.

## Student reflection to complete

1. Which modules did I personally implement, review or explain?
2. What code and design decisions can I demonstrate without assistance?
3. Which tests did I personally execute on my phone and browser?
4. What limitations will I state during the evaluation?

Version-control stage is deferred. No commits, pushes, branches, PRs or publication were made during this session.
