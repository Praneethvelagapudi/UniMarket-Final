# Evaluation 2 verification and demonstration

This runbook concerns the Evaluation 2 build, version **1.0.2 (3)**. Review 1 archives and presentation remain historical. Use the fresh paths listed in `EVALUATION2_HANDOVER.md` rather than an earlier APK/source ZIP.

## Quick local start

From this workspace in PowerShell (Flutter is not on the default PATH):

```powershell
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' pub get
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' run -d web-server --web-port 5174 --web-hostname 127.0.0.1 --dart-define-from-file=config/firebase.json
```

Open `http://127.0.0.1:5174`. For the built web release, serve `build/web` with an HTTP server. A local release preview may already be running at `http://127.0.0.1:5176`; if it has stopped, use the run command above. Do not open `index.html` as a file.

Install the fresh release APK on an Android 7.0+ phone. Existing application ID and signing identity are preserved for an in-place update. Keep the private demo accounts in `dist/DEMO_ACCESS.txt` private. You can also register your own correctly formatted campus account; inbox verification remains disabled as before.

## Short demonstration sequence

1. Sign in, reload/restart, and confirm the session restores. Browse/search/filter a labelled review fixture. Save and unsave it. Existing real student listings should not be used for dummy reservations.
2. Open **You → Sign out**. Choose **Cancel** and confirm the same screen/session remains. Open it again and choose **Logout**; verify Back cannot reopen protected content. Sign in again.
3. Reserve a **[Review demo]** item with a future campus pickup. Leave **Try a test payment** off to demonstrate the preserved handover flow. Check the saved receipt and its unpaid label. Preview/export the PDF. Cancel the test booking so the fixture is available again.
4. Reserve the same fixture with **Try a test payment** on. The held-reservation screen says **Test payment required** and offers no successful PDF. Open **Continue to test payment** and check the saved amount. Demonstrate failure and retry, cancellation, pending/resume, then **Simulate success**. Verify the simulation label, reference and PDF; no real money is processed.
5. Sign in as the other review user on a second device/browser. Use the fixture's private conversation. Send text and confirm real-time appearance. Move the recipient out of that chat; send another message and verify unread count/banner and permitted device alert. Opening the chat clears unread state. Sender must not receive an own-message alert.
6. Tap the microphone, then **Record**. Allow the microphone in the browser/Android prompt. Stop, preview and send a short voice message. Play it as the recipient. Repeat with **Cancel** to show no message is sent. Test permission denial; if the browser leaves a prompt unanswered, Cancel remains available and a timeout explains the wait. Clips are limited to 15 seconds.
7. Show seller-side Bookings. Only the seller can confirm handover/return; a mock reservation must first complete its simulated payment. Use a rental if you need the fixture available for repeated demonstrations. Cancel unfinished test reservations afterward.

## Permissions and real device limits

Android: microphone permission is requested when recording; Android 13+ also requires notification permission. Both permissions can be changed in the app's Android settings. Device notifications have separate booking/message channels; denied notifications do not undo successful data operations. The app's notification setting controls previews/alerts; unread badges remain.

Browser: use HTTPS or localhost for microphone/Notifications APIs. Use current Chrome/Edge for the evaluation, grant the requested permissions, and keep the page running. Some embedded browsers do not expose a microphone permission UI; the app must remain cancellable and report that limitation. Printing/sharing follows the platform's available apps; web sharing may download the file instead.

Notifications are local, driven by live Firestore listeners. This build does not promise delivery after force-stop/termination, server push, or scheduled reminders. For assessment, distinguish the in-app banner from an actual Android/browser OS notification. Verify lock-screen privacy and sound on the physical phones; emulator success does not prove either.

## Reproducible checks and builds

Run Flutter commands sequentially and wait for each to finish. Dependency restoration, tests and release builds can rewrite generated plugin registration; do not run another Flutter/IDE build task concurrently. Never hand-edit `GeneratedPluginRegistrant.java`.

```powershell
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' pub get
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' analyze
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' test
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
& tools/firebase/node_modules/.bin/firebase.cmd emulators:exec --project demo-unimarket --only firestore 'node tools/firebase/rules.test.mjs'
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' build web --release --dart-define-from-file=config/firebase.json
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' build apk --release --dart-define-from-file=config/firebase.json
& 'C:\Users\jdvel\develop\flutter\bin\flutter.bat' build appbundle --release --dart-define-from-file=config/firebase.json
```

The emulator rules tests clear only the local `demo-unimarket` database. Check whether port 8080 is already occupied before starting a second emulator; do not clear or stop an unrelated server. The live sync script `node tools/firebase/eval2-live-check.mjs` requires the existing ignored `tmp/review-accounts.json` and writes only labelled review conversations; it does not contain credentials itself.

`integration_test/market_flow_test.dart` creates distinctly labelled test accounts/listings and exercises real Firebase services, receipts/cancellation, retry-safe voice/text persistence, read receipts, mock payments and PDF generation. `voice_device_test.dart` exercises the actual microphone/preview controls. Grant permissions to the installed app before unattended execution. The session test is run twice with `--no-uninstall` and an ignored account define file. These tests should not be run on a phone currently being used for personal activity.

## Build/signing interpretation

An **APK** is directly installable on Android. An **AAB** is a publishing bundle from which a distribution service generates device APKs; it is not directly installed by tapping it. The existing Android release configuration uses the development/debug certificate. Any fresh signed AAB produced here is an evaluation artifact, not a production Play signing setup. No private production key was created or replaced.

## Final human checks

Use two physical phones with different accounts and a browser. Check microphone quality, actual audible playback, OS permission denial, notification sound/lock-screen privacy/background behavior, file-save/share targets, restart persistence, seller/buyer synchronization and the complete primary workflow. Confirm your own contribution report and actual presentation requirements. Only after personally verifying the application should you explicitly authorize the separate Git/GitHub stage.
