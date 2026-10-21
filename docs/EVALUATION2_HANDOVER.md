# UniMarket Evaluation 2 handover

20 October 2026 · Version 1.0.2+3 · Local verification build

## A. Overall status

Ready for the owner's browser verification with documented device limitations. The existing Flutter/Firebase application was audited and extended with logout confirmation, saved-record PDF confirmations, real voice-message recording/storage/playback, recipient message alerts/unread state, and an explicitly labelled local payment simulation. Real Razorpay payments are not connected. Native microphone, notification delivery and two-phone demonstration remain unverified because the available Android emulator repeatedly suffered a System UI ANR. This is not a claim of complete physical-device validation.

## B. Rubric compliance

The original detailed 25-mark rubric page was not supplied. The supplied A–J brief is mapped to A1–J1 in [EVALUATION2_RUBRIC.md](EVALUATION2_RUBRIC.md), with evidence and limits for every criterion. A1, B1, C1, D1 and I1 are Partial pending device/human demonstrations; E1, F1, G1 and J1 are Complete within their stated scope; H1 is Blocked by the owner's explicit deferral of Git/GitHub work. No marks or student ownership are invented.

## C. Changes made

See [EVALUATION2_CHANGES.md](EVALUATION2_CHANGES.md) for the complete source/schema/dependency inventory and [EVALUATION2_BASELINE.md](EVALUATION2_BASELINE.md) for the pre-edit audit. Existing branding, Firebase project, campus validation, listings/photos/favourites, buy/rent reservations, seller completion, meetup/text chat, theme/cache behavior and signing identity were preserved. New packages are pdf, printing, record, audioplayers and direct web; the bundled Noto Sans font supports INR text. Existing locked package versions were retained.

Defects fixed include protected routes remaining after session loss, pending microphone permission disabling Cancel, notification permission holding a saved operation indefinitely, notification-preference races, and unreliable automatic payment return. Successful mock payments now expose an explicit **View booking receipt** action. Failed/pending/cancelled mocks cannot issue a successful PDF. Stable message/payment attempt IDs prevent duplicate retry writes.

## D. Five requested features

| Feature | Implementation and evidence | Remaining limits |
| --- | --- | --- |
| Logout | Shared dialog, busy/error state, UID-keyed navigation; Cancel/confirm/failure/external-loss widget tests pass. Browser Cancel preserves session. | Two-process Android restart/logout check remains pending. |
| PDF | Server-read authorized booking, exact saved fields, INR font, preview/download/share/print. Real browser download matched ten fields/labels/timestamps and was visually inspected. Cancelled and unpaid mock eligibility tests pass. | Physical Android share/print targets need checking. Handover reservations correctly state unpaid. |
| Voice | Actual PCM microphone capture, bounded valid WAV, preview/cancel/send, private persisted audio and recipient playback. Codec/widget/rules tests pass. | Browser microphone permission remained unanswered; Cancel was verified. Android capture/playback and physical audio quality remain pending. Limits: mono 8kHz, 0.1–15 seconds. |
| Message notifications | Session-scoped Firestore listeners, unread/read state, sender previews, in-app alerts, Android/browser local alert adapters and preferences. Unit/security tests and live two-client synchronization pass. | Actual Android/browser OS alerts are not verified. No terminated-app push or scheduled reminders backend. |
| Payment fallback | Clearly labelled mock; saved amount, pending/failure/cancel/retry/success and immutable mock reference. Browser flows and security transitions pass. | No real checkout/charge/webhook. Official activation steps are documented separately. |

## E. Testing

Baseline: 17 Flutter tests and 17 security tests passed. Final automated suite: **39 Flutter tests passed**, **26 Firestore security tests passed**, and static analysis found no issues. See [EVALUATION2_TESTING.md](EVALUATION2_TESTING.md) for case IDs, actual results, failures encountered and fixes.

Live cloud checks verified two-way delivery, owner-only read receipts and unauthorized receipt denial using two authenticated SDK clients. The browser verified login/reload session restoration, live unread/read changes, sender identity, search, reservations, mock failure/retry/pending/resume/success, saved PDF download and booking cancellation. Two labelled fixture reservations were cancelled afterward to restore availability. The PDF snapshot records its successful state at issue time, before cancellation.

An earlier 1.0.2+3 release candidate installed successfully using the existing certificate. The final receipt-action rebuild was build/signature verified; it was not reinstalled after stopping the unstable emulator. Attempts at 1 GB and 2 GB emulator RAM both produced **System UI isn't responding** dialogs. The actual device microphone integration attempt was stopped because this environment was unstable; it is not counted as passed. Native regression/session/notification integration files are provided for rerunning on a stable emulator or phone. Screenshots of the emulator failure are retained in evidence. No application crash was found in the captured earlier release Flutter/AndroidRuntime error log; that does not establish full native runtime correctness.

## F. Build artifacts

Fresh web, APK and AAB release commands succeeded. Exact delivered filenames, sizes and SHA-256 values are in `dist/evaluation2/ARTIFACTS.json` and `SHA256SUMS.txt`.

- APK: `C:\Users\jdvel\Downloads\UniMarket_Clean\dist\evaluation2\UniMarket-Evaluation2.apk`
- AAB: `C:\Users\jdvel\Downloads\UniMarket_Clean\dist\evaluation2\UniMarket-Evaluation2.aab`
- Source: `C:\Users\jdvel\Downloads\UniMarket_Clean\dist\evaluation2\UniMarket-Evaluation2-Source.zip`
- Web archive: `C:\Users\jdvel\Downloads\UniMarket_Clean\dist\evaluation2\UniMarket-Evaluation2-Web.zip`
- Web output: `C:\Users\jdvel\Downloads\UniMarket_Clean\build\web`, local preview `http://127.0.0.1:5176/`.

The release configuration retains the existing development/debug certificate. APK signature verification and AAB jar verification succeeded. The certificate is self-signed and has no trusted timestamp; production Play signing remains an owner setup step. The AAB cannot be installed by tapping it. Source archives exclude local credentials, caches, signing keys, build outputs and private demo access. Historical Review 1 deliverables remain separate.



Verified release sizes: APK **69,647,958 bytes**; AAB **66,383,191 bytes**.

## G. Evaluation preparation

- Formal test record: [EVALUATION2_TESTING.md](EVALUATION2_TESTING.md).
- Individual contribution draft: [EVALUATION2_CONTRIBUTION_DRAFT.md](EVALUATION2_CONTRIBUTION_DRAFT.md). Fill in and verify personal attribution/reflection.
- Demonstration/run instructions: [EVALUATION2_RUNBOOK.md](EVALUATION2_RUNBOOK.md).
- Payment/notification boundaries: [EVALUATION2_PAYMENT_AND_NOTIFICATIONS.md](EVALUATION2_PAYMENT_AND_NOTIFICATIONS.md).

For a physical demonstration use two different accounts on two phones: show text and audible voice delivery, recipient-only alert outside the active chat, unread clearing, notification sound/privacy, restart persistence and PDF sharing. A browser plus SDK clients does not substitute for two phones.

## H. Outstanding work

1. Validate on a stable Android phone/emulator: microphone capture/playback, native permission denial, booking/message OS channels, restart persistence, full listing/photo/favourite/seller workflow and system share/save targets. These remain pending due to emulator System UI ANRs; integration tests and capture helpers are supplied.
2. Grant microphone/notification permissions in a supported Chrome/Edge session to demonstrate browser hardware APIs; the embedded browser did not resolve the microphone prompt.
3. If real payments or closed-app push are required later, provision server-side gateway verification and push infrastructure using the documented steps. No client-secret shortcut was added.
4. Verify individual contribution claims and supply the original detailed marking sheet if exact marks/subcriteria are needed.
5. Explicitly approve the Git/GitHub stage only after reviewing the app.

## I. GitHub status

No commits, branches, pushes, pull requests or repository publication were made. The workspace is not a Git repository. The only Git inspection was a read-only status attempt. No GitHub mutation occurred.

## J. Shortest verification sequence

Open the local demo at **http://127.0.0.1:5176/**. It uses the existing Firebase backend. Private review credentials remain in the existing `dist/DEMO_ACCESS.txt`; do not publish them. Use only **[Review demo]** fixtures for test reservations.

1. Browse/search/save an item. Open You → Sign out → Cancel; later confirm Logout and verify protected Back navigation is cleared.
2. Reserve a review fixture with a future pickup. Preview/download its saved confirmation PDF. Cancel afterward.
3. Repeat with **Try a test payment** enabled. Demonstrate failure → retry → pending/resume → success → **View booking receipt** → PDF. Check all simulation labels. Cancel afterward.
4. Use another account/device for text/voice/unread/notification verification, then inspect the test record's remaining device cases.
5. Install the fresh APK on a phone for native checks. After personal validation, explicitly authorize the next stage.

If the preview server has stopped, follow the quick start in the runbook. No public hosting was created.
