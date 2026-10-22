# UniMarket notification verification — 21 October 2026

The notification fixes are included in UniMarket **1.0.3 (version code 4)**.

## Results

- Full Flutter suite: **41 tests passed**.
- `flutter analyze`: **No issues found**.
- Android integration run: **both test cases passed**, followed by a successful framework teardown. The driver exited with code 0.
- Device: separate Android 10 / API 29 x86_64 AOSP emulator, `UniMarket_Notify_API29`. Android reported no ANR since boot during verification. The previous API 36 emulator repeatedly had System UI failures, so the successful device checks used API 29.
- Actual Android active notification records were captured for all four checks:
  - Native booking notification, on the `bookings` channel.
  - Native incoming-message notification, on the `messages` channel.
  - Incoming Firestore message between the existing review accounts, including recipient banner/unread update, entering the conversation, persisted read state, and a reply received by the peer account.
  - Booking created through the reservation screen, confirmed against the saved server record, with its real booking notification.
- Test cleanup cancelled the newly created reservation, archived its disposable listing, restored the notification preference, and signed out both test accounts. Synthetic messages remain in the existing review conversation.

Evidence is in [notification-verification-2026-10-21](notification-verification-2026-10-21/), including the four active Android notification records, test summaries, analysis result, signature, and release checksum.

## Fixes

1. Android permission checks now use the app-wide notification permission. Disabling the Booking confirmations channel no longer incorrectly reports the separate messages channel as unavailable. Posting still checks the selected channel before delivery.
2. The profile's **Test device notification** button now explains when permission is allowed but the booking alert cannot be posted. Tests cover this case and denied permission.
3. Successful mock payments now include feedback if the device notification cannot be posted.

## APK

`dist/notification-fix/UniMarket-1.0.3-Notifications.apk`

- Size: **69,647,962 bytes** (66.4 MiB).
- Package: `edu.students.unimarket`; minimum API 24; target API 36.
- APK signature verified. It uses the existing Android Debug certificate, matching the earlier university demo APK.
- The exact distributable APK was installed over the QA build and launched successfully. Android reported version 1.0.3 / code 4 and no ANR; the normal sign-in screen was visually checked in `release-launch.png`. AndroidRuntime reported no fatal error.
- SHA-256: `60f7d39337312529e355424b17b1aa5462d1f305e57cff44b8faa23c85d3a52f`.
- All 707 ZIP entries passed CRC reading. A scan found no private QA account values or QA notification test markers in this release APK.
- Built from the normal application entry point with the public Firebase configuration. The separate QA APK contains test account defines and was never copied to `dist/`. Automatic approval review rejected removal of its temporary copies with “blocked by policy”, so those QA APKs remain under ignored `tmp/` and `build/`; do not distribute them. The emulator now has the normal release APK installed. Private test configuration and intermediate build caches also remain ignored.

## Scope

These are local Android notifications. Live incoming-message alerts require the application process and its Firestore listener to be running. Notification permission, the relevant Android channel, and the in-app preference must permit delivery. There is no FCM/backend delivery after force-stop or process termination.

The successful native run used API 29, which has no Android 13+ notification permission dialog. Denied-permission feedback is covered by Flutter tests; the Android 13+ permission dialog was not validated on a healthy device in this run. Multi-phone delivery remains a separate presentation check.
