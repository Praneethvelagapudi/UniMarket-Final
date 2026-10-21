# Review 1 rubric audit — UniMarket

Audit date: 6 October 2026. All twelve criteria from the supplied 15-mark rubric are accounted for below. PASS describes verified software evidence, not an assessor's awarded mark. The team's physical review and signed submission require human evidence.

| Criterion | Marks | Status | Evidence / remaining action |
| --- | ---: | --- | --- |
| A1: Layout, alignment and widget hierarchy | 1 | PASS | Shared forms/cards/status/loading/error widgets; live auth, marketplace, chat and receipt inspected. |
| A2: Theme and responsive mobile/web design | 1 | PASS | Material 3 theme, dark setting, phone bottom navigation and desktop rail/grid. Actual 390×844 and 1440×900 screenshots plus layout tests. |
| B1: Firebase registration and login | 2 | PASS | Email/password enabled in Uni-Market. Real Android registration creates campus profiles; live Android and web login verified. |
| B2: Validation, persistent session and logout | 1 | PASS | Campus/domain/roll/password/error tests pass. A fresh Android process restores the expected account without calling login, then logs out through UI. Browser refresh and logout also verified. |
| C1: Browse/select/book/view/cancel | 2 | PASS | Actual Firebase listings and favourites, web purchase receipt and cancellation. Android integration verifies photo publish, saved item, chat, purchase/cancellation, three-day rental, owner return and archive. |
| C2: Navigation, back stack and state | 1 | PASS | Responsive shell retains tab state; receipt returns to the market. Actual receipt cancellation/navigation and profile/logout tested; disposed-form async callback test passes. |
| D1: Firebase booking and correct immediate confirmation | 1 | PASS | Transaction persists booking and reserves the item. Real web receipt shows buyer/seller, pickup and ₹450 total. Android checks purchase ₹300 and rental 3×₹15=₹45 with actual persisted documents. |
| D2: Mobile booking confirmation/reminder notification | 1 | PASS | Android test posts a real confirmation. OS evidence records the UniMarket bookings channel, Booking confirmed and Review calculator · 3 days · ₹45. Confirmation option implemented; scheduled reminders are not claimed. |
| E1: Live mobile demonstration | 1 | PARTIAL | Release APK builds, installs and opens on Android emulator. Actual Firebase workflows and notifications run there. Two-phone runbook and accounts are ready; the team must install/present on its physical phones. No physical phone was connected for verification. |
| E2: Working Firebase-backed web demonstration | 1 | PASS | Final web release builds and runs against uni-market-7ef26. Real login/data, favourite, booking/cancellation, refresh/logout and prepared chat inspected. The customer account also publishes its own photo listing through the visible gallery/form flow. |
| E3: All team members present modules and explain design | 1 | PARTIAL | Sixteen-slide deck with speaker notes, four proposed modules, operation/file map and learning guide prepared. Actual attendance and each member's explanation require the team. |
| F1: Signed hardcopy blueprint before 30-09-2026 | 2 | BLOCKED | Printable blueprint with blank genuine signature/date fields supplied. The deadline precedes this audit. No timely submission evidence was provided; an automated project build cannot sign or retroactively establish submission. |

## Firebase configuration

- Project **Uni-Market**, ID `uni-market-7ef26`; Android package `edu.students.unimarket`, registered web app.
- Email/password Auth enabled. Matching campus email/roll checks accept varying alphabetic branches and numeric suffixes. Inbox verification intentionally disabled.
- Firestore Standard/native, Mumbai (`asia-south1`), free tier. Spark retained, with no Storage/Blaze upgrade.
- Rules deployed and compiled without warnings. Private profiles/bookmarks, participant-only bookings/chat, listing ownership and atomic price/date/status validation.
- Optional JPEG photos capped at 180,000 bytes, stored separately. Base64 indexing disabled.

## Verification record

- Final static analysis: no issues. Log: `evidence/flutter-analysis.txt`.
- Final 17 Flutter unit/widget tests: PASS, including default Firebase configuration, pending-profile acknowledgement, account switching and offline profile regression checks. Log: `evidence/flutter-unit-tests.txt`.
- Final 17 isolated Firestore emulator security tests: PASS. Log: `evidence/firestore-rule-tests.txt`.
- Android marketplace integration against real cloud Firebase: PASS. Log: `evidence/android-flow-tests.txt`.
- Android session setup and fresh-process restoration/UI logout: PASS. Log: `evidence/android-session-tests.txt`.
- Real Android OS notification record: `evidence/android-notification.txt`.
- Two separate authenticated demo clients both read messages from the customer and owner: `evidence/two-account-chat.txt`.
- Final configured release builds: `evidence/web-release-build.txt` and `evidence/android-release-build.txt`.
- The initial 1.0.0 release APK installed successfully and started with `Status: ok`; its UniMarket activity remained resumed with a live process and no AndroidRuntime/Flutter error records. Proof: `evidence/apk-install-launch.txt`. The updated 1.0.1/build 2 APK includes the registration timing fix covered by widget tests; package/ABI details and signature verification are recorded in `evidence/apk-metadata.txt` and `evidence/apk-signature.txt`. Installation on a physical phone must be checked on that phone.
- Browser evidence: `web-desktop.jpg`, `web-mobile.jpg`, `web-booking-confirmed.jpg`, `web-chat.jpg` and `web-upload.jpg` in `evidence/`.
- Presentation: 16 editable slides with speaker notes, native tables and actual app screenshots; all 16 rendered slides individually inspected for layout and readability.
- Browser photo upload and reciprocal item ownership: `evidence/browser-upload-check.txt`. Slide validation summary: `evidence/presentation-check.txt`.

The Android integration uses Firebase services directly for data operations and the actual receipt/cancellation/navigation UI. Browser checks cover the visible forms and live app. Gallery/camera hardware on the team's physical phones and actual review attendance cannot be inferred from emulator or browser tests.

## Deliverables and scope

The deliverables folder contains the installable APK, source and release-web archives, presentation with speaker notes, README/file map, learning guide, two-phone demo runbook, printable blueprint and private demo access file. VS Code Flutter/Dart extensions and launch/build configurations are supplied. The complete private bundle includes demonstration passwords; the source archive and slide deck exclude them.

One active reservation holds an item. Payment happens at campus handover; chat bargaining does not automatically change listing prices. Previously fetched data can be read offline, while booking transactions need internet. Notifications are local buyer confirmations. The APK uses a development certificate for the university demo. Android shrinking is disabled to support this low-memory build environment. These limits are documented, not presented as implemented extras.
