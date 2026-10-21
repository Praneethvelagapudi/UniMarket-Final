# Evaluation 2 formal testing record

Date: 20 October 2026, Asia/Kolkata. `PASS` means the stated check actually ran. `PENDING` means execution is still to be recorded; it is not a pass. Historical Review 1 logs remain separate.

## Baseline and automated results

- Before edits: **17/17 Flutter tests passed**, analysis found no issues, and **17/17 isolated Firestore security tests passed**. The existing browser login screen rendered successfully.
- Extended Firestore suite: **26/26 passed**, `tmp/eval2-rules-direct.log`. The first rerun launcher failed because the baseline emulator still held port 8080; the suite then ran successfully against that same local `demo-unimarket` emulator. No cloud database was cleared. The baseline emulator was stopped after testing.
- Flutter suite: **39/39 passed**, `tmp/eval2-final-tests.log` (earlier 34-case run: `tmp/eval2-tests-final.log`). The first new logout test fixture did not replay the session to new subscribers like Firebase does; it produced three test failures. Correcting the fixture's stream semantics made all targeted and full-suite checks pass. A later permission-timeout test initially left a debug platform override set; using Flutter's scoped platform variant fixed its invariant failure. These test-fixture defects were recorded rather than hidden.
- Targeted logout/message suite: **10/10 passed**, `tmp/eval2-session-message-tests.log`.
- Live two-client check: two-way real-time Firebase delivery and private/owned read receipts passed; `tmp/eval2-live-sync.log` and `.json`. These are concurrent authenticated SDK clients, not two physical phones.
- Final production analysis: **No issues found**, `tmp/eval2-final-analysis.log`.
- Browser: real demo login, reload/session restoration, live unread badges and sender names, read-count change after opening a chat, logout Cancel preserving the profile, mock reservation/failed payment/retry/pending/resume and saved history state were observed. Only explicitly labelled review fixtures were reserved. The embedded browser left its microphone permission request pending; this exposed and prompted the tested Cancel/timeout fix.
- PDF samples: both generated, text extracted, rasterized and visually inspected. Each is one A4 page; values include 3 × INR 19.99 = INR 59.97, actual fixture fields, correct unpaid/simulation labels, IDs and pickup. Samples are synthetic QA documents, not customer transactions.
- Static analysis/build/integration evidence is recorded below as those commands finish. Intermediate analysis found duplicate local names in the expanded integration test and style diagnostics; those were corrected before release builds.

## Test cases

| ID | Description | Input / preconditions | Expected | Actual result | Status | Defect / fix |
| --- | --- | --- | --- | --- | --- | --- |
| AUTH-01 | Login validation | Empty/non-campus email and password | Specific validation errors, no sign-in | Existing widget suite passes | PASS | Preserved |
| AUTH-02 | Registration validation | Mismatched roll/email/password | Clear errors | Existing suite passes | PASS | Preserved |
| AUTH-03 | Firebase login errors | Invalid credential response | Readable message; loading ends | Existing suite passes | PASS | Preserved |
| AUTH-04 | Pending campus profile | Local unacknowledged profile | Protected queries wait | Existing auth-gate suite passes | PASS | Message subscriptions also wait for acknowledgement |
| AUTH-05 | Cached profile/account switch | Acknowledged cache, then new UID | Offline profile works; old profile discarded | Existing auth-gate suite passes | PASS | Preserved |
| AUTH-06 | Session after restart | Two fresh Android processes, retained app data | Same UID restores without login | Not completed: emulator System UI ANR at both RAM configurations | PENDING | Existing integration test updated for dialog |
| LOG-01 | Cancel logout | Protected detail route, active account | Session and route unchanged | Widget test passes | PASS | New confirmation dialog |
| LOG-02 | Confirm logout | Protected pushed route/dialog | Auth screen; no protected back stack | Widget test passes | PASS | MaterialApp Navigator keyed by UID |
| LOG-03 | Logout failure/loading | Failed then delayed sign-out | Visible error/retry; duplicate taps disabled | Two widget cases pass | PASS | Busy/error state implemented |
| LOG-04 | External session loss | Session emits null on a pushed route | Protected route disappears | Widget test passes | PASS | Same session boundary handles external loss |
| CORE-01 | Listing/photos/favourites | Publish valid photo item; save favourite | Real records and bounded JPEG; saved item readable | Baseline tests/rules pass; browser search/reserve/cancel verified; native run blocked by emulator ANR | PARTIAL | Existing behavior preserved |
| CORE-02 | Buy/rent totals | Exclusive return dates; 1–90 days | Correct totals and invalid-date rejection | Unit and rules suites pass | PASS | Preserved |
| CORE-03 | Reserve/cancel/complete/archive | Competing reservations and owner actions | Atomic availability; seller-only completion | Rules suite passes; UI device run pending | PARTIAL | Mock completion additionally gated |
| PDF-01 | Saved reservation PDF | Successful handover reservation | Correct private saved fields; unpaid label | Generation/text/raster QA passes on fixture | PASS | Embedded Noto Sans includes INR glyph |
| PDF-02 | Test-payment PDF | Succeeded local simulation | Prominent simulation; saved reference/amount | Generation/text/raster QA passes on fixture | PASS | PDF unavailable before success |
| PDF-03 | Failed/pending/cancelled export | Those statuses and cancelled booking | Reject successful confirmation | Unit suite passes | PASS | Explicit eligibility guard |
| PDF-04 | Saved database vs PDF | Android server-read record, generated PDF | IDs, names, item, amount, location and reference agree | Actual browser download matched ten saved fields/labels/timestamps; tmp/eval2-browser-pdf-verified.log | PASS | Test exports PDF and comparison JSON |
| PDF-05 | Download/share/print | Android apps / browser | Download or system share/save UI | Browser preview/download verified; Android share targets still pending | PARTIAL | Native printing plugin; no broad storage permission |
| VOICE-01 | PCM/WAV codec and bounds | 0.1–15s, 8kHz mono PCM | Exact samples/duration; valid WAV | Three unit tests pass including malformed/oversize rejection | PASS | Real bytes; no fake UI |
| VOICE-02 | Voice storage and privacy | Atomic bounded audio+metadata | Recipient reads; outsider/spoof/oversize rejected | Three security cases pass | PASS | Private nested audio docs; unindexed payload |
| VOICE-03 | Microphone controls | Record, stop, preview, cancel, send | Actual capture; cancel sends nothing | Embedded-browser permission unresolved; Cancel verified. Android test stopped after System UI ANR | PENDING | Permission/error/lifecycle handling implemented |
| VOICE-04 | Persisted recipient playback | Two users, retry same voice ID | Exact bytes; one message; native playback | Native playback pending due to System UI ANR; private exact-byte validation covered by codec/rules | PENDING | Transactional ID reuse |
| VOICE-05 | Denied/unanswered microphone permission | Fake denied or pending platform response | Useful error, disabled send, working Cancel, safe late response and timeout | Three widget cases pass | PASS | Fixed disabled Cancel while awaiting permission |
| NOT-01 | Recipient targeting/deduplication | Own send, new incoming, repeated snapshot | One recipient alert; no own alert | Message-center tests pass | PASS | Baseline/seen-ID tracking |
| NOT-02 | Unread/read synchronization | Open chat, new message, background/resume | Persistent read state and correct counts | Message-center and rules tests pass | PASS | Monotonic owned read timestamps |
| NOT-03 | New conversation/cache | First message in new chat; cache replay | New-chat alert; no historical replay | Message-center tests pass | PASS | New conversation priming |
| NOT-04 | Android OS alerts | Notification permission granted | Real booking/message channels and notification | Unverified: emulator System UI ANR prevented reliable OS inspection | PENDING | Existing native bridge extended |
| NOT-05 | Browser alerts / denial | Secure browser; grant/deny permission | Supported alerts; graceful denial | OS permission unresolved in embedded browser; in-app alerts covered by tests | PARTIAL | Conditional web Notifications API |
| NOT-06 | Terminated-app push/reminders | App terminated | Requires backend push/reminder service | No such backend exists | BLOCKED | Explicitly not claimed as supported |
| NOT-07 | Unanswered notification permission | Pending OS response | Saved-operation flow can continue after timeout | Widget case passes | PASS | Permission request bounded to 15 seconds |
| PAY-01 | Simulation creation | Optional mock reservation | Pending state; immutable saved amount | Rules suite passes | PASS | Legacy handover still default |
| PAY-02 | State transitions | Pending/success/failure/cancel/retry | Authorized transitions and mock reference | Five new payment security cases pass | PASS | Buyer ownership; attempt IDs; terminal-success lock |
| PAY-03 | Duplicate/late callbacks | Repeat attempt or cancelled booking | Idempotent service; late result rejected | Rules pass; fresh service device run pending | PARTIAL | Stable attempt IDs and DB verification |
| PAY-04 | Real Razorpay verification | No server/TEST credentials | No false real-money confirmation | Local mock explicitly labelled | PASS | Activation steps documented separately |
| DB-01 | Access/ownership/CRUD | Anonymous/outsider/wrong participant | Deny unauthorized operations | All 26 security tests pass | PASS | Original rules retained and extended |
| DB-02 | Delete and immutable records | Favourite delete vs booking/chat edit/delete | Own favourite deletion; private records immutable | Existing service/rules inspected; device delete pending | PARTIAL | No permissive test-mode rules |
| NAV-01 | Back navigation/session isolation | Nested detail and logout/account changes | No protected route after logout | Widget cases pass | PASS | Session-keyed Navigator |
| UI-01 | Mobile/desktop auth | 390×844, desktop | Responsive, no overflow | Existing auth widget cases pass; baseline desktop seen | PASS | Branding preserved |
| UI-02 | New PDF/chat/payment UI | Narrow screen, errors/disabled states | Readable controls and safe state | Browser payment/receipt/PDF and pending-mic Cancel inspected; native inspection pending | PARTIAL | Added responsive Wrap/scroll layouts |
| BUILD-01 | Web release | Configured existing Firebase project | Command exits 0; output exists | Release command succeeded; build/web exists | PASS | No framework migration |
| BUILD-02 | APK release/install | Existing development certificate | Actual installable file and launch | Release build/signature succeeded; earlier 1.0.2+3 candidate installed. Final receipt-action rebuild not reinstalled after emulator System UI ANR | PARTIAL | Existing key preserved |
| BUILD-03 | AAB release/signature | Existing development certificate | Real signed bundle; signing limits disclosed | Release build and jarsigner verification succeeded | PASS | No production key created |

## Evidence and interpretation

Expected-denial messages in rule-test logs are part of successful attack tests. They are not hidden application failures. Test totals refer to test cases, not every assertion. Unit/widget stubs control edge states; Firestore tests use the actual emulator rules engine. Device, live cloud, microphone, browser and physical multi-device results must be identified separately. No two-phone or iOS demonstration is inferred from an emulator build.

All fresh logs remain under `tmp/eval2-*`; final evidence copies will be placed in `docs/evaluation2-evidence/`. No secrets should be copied into evidence or source archives.

## Final browser and environment evidence

The actual browser PDF `output/evaluation2/browser-saved-booking.pdf` was matched against its server-read JSON: booking/item/parties/amount/pickup/reference/labels/timestamps all passed. Both labelled browser test reservations were cancelled after inspection. The snapshot reflects its successful state at issue time. Payment success now provides **View booking receipt**, a deterministic explicit action after saved success.

The native voice integration command began debug assembly but was stopped after the emulator repeatedly displayed a System UI ANR, including at its original 2 GB allocation. No native capture, notification delivery, fresh session persistence or full native regression pass is claimed. The failed environment screenshots are retained. Prior failed generated-plugin registration was corrected by normal sequential Flutter regeneration; subsequent release APK and AAB builds passed. Final permission-preference race coverage brings the Flutter count to 39.
