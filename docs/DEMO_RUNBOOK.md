# Review demonstration with two phones

## Preparation

Install `dist/UniMarket.apk` on two Android phones running Android 7.0 or newer. The installation permission belongs to the file manager or browser opening the APK. The app itself needs internet access, and booking alerts need Android notification permission. A USB cable or VS Code is unnecessary for installing the ready APK.

Use the private `dist/DEMO_ACCESS.txt`: **Phone 1 = customer**, **Phone 2 = item owner**. These are separate real Firebase accounts in Uni-Market. The source archive and slide deck exclude their passwords. Demo items contain `[Review demo]` in their titles and do not represent actual offers.

## Demonstration order

1. **Login and campus validation.** Sign in to the customer account. Briefly show the registration form and explain that roll and email prefixes must match. Return without submitting a duplicate account.
2. **Browse and filter.** Discover shows academic items. Search for `calculator`, select ECE, open the scientific calculator and show sale/daily prices. Save it and show it under Saved.
3. **Two-way chat.** On Phone 1, tap Chat with seller and send a new message. On Phone 2, open Messages and the calculator conversation, then reply. Confirm that the customer sees the reply. A prepared example conversation is already available.
4. **Add your own item.** On Phone 2, use Discover > List an item. Enter a title such as `[Review demo] My textbook`, a specific description, department, category, condition and prices. Choose Gallery or Camera for your own photo. Publish. Search for the new title on Phone 1 and open its photo/details. Both accounts can publish their own items, but each manages only its own listings.
5. **Purchase and cancellation.** Reserve an available owner item from Phone 1. Enter a future pickup time and specific campus location. Confirm. Show the saved receipt and the Android notification. Phone 2 sees the same booking under Bookings. Cancel it from Phone 1 and show the restored availability.
6. **Rental.** Reserve the calculator for three days at ₹15 per day. Use a pickup time within the rental period. Show the ₹45 total, pickup fields, receipt and booking history on both phones. Phone 2 can later use Confirm return. Cancel the rental before repeating the demonstration if a return has not actually happened.
7. **Session and settings.** Close/reopen the app to demonstrate the retained session. Show You > dark appearance and notification settings. Use Test device notification if Android notification permission needs confirmation. Sign out and show the login screen.
8. **Web and code.** In VS Code open the complete UniMarket_Clean folder, select UniMarket - Web browser and press F5. Edge opens automatically on this laptop after compilation; the local URL is http://127.0.0.1:5174. Login and show the same Firebase listings and booking history. Use the README operation table to explain the screen/service/backend separation.

Avoid reserving an item owned by the same account. A reserved item disappears from available Discover results until cancelled or returned. View it through Bookings while reserved. The owner can archive an available demo item under You after the demonstration.

## split

Group 20 should agree on the actual assignment before presenting. Suggested modules:

- Authentication, campus validation, session restoration and logout.
- Marketplace, photographs, filters, favourites and responsive screens.
- Booking/rental transactions, cancellation, receipt and Android notifications.
- Chat, meetup planning, cached content and Firestore rules.

Use `dist/UniMarket_Review1.pptx` and its speaker notes. Keep demo passwords out of projected slides. Bring `docs/UniMarket_Blueprint.pdf` for real signatures and consult `docs/FINAL_RUBRIC_CHECKLIST.md` for the outstanding human submission requirements.

## If something goes wrong

- A login failure: copy the exact email/password from the private access file, with no spaces. Existing accounts do not need inbox verification.
- No notification: allow Android notifications, enable the app's setting, and run the device check under You. Android can also disable the Booking confirmations channel separately.
- No new item on the other phone: confirm both devices have internet, clear filters/search and refresh the view. Use the same UniMarket APK and project.
- Already reserved: cancel the active booking or use another available item. The server prevents two simultaneous reservations.
- VS Code cannot find Flutter: check `.vscode/settings.json` and select the installed Flutter SDK. Use the supplied launch configuration to pass `config/firebase.json`.
- A slow/failed request: read the error, restore connectivity and refresh before retrying. A timed-out write might still complete.
- Access denied just after signup in the earlier build: refresh the laptop page or reopen the app, then sign in with the account you already created. Version 1.0.1/build 2 waits for the profile save before opening the market. Update the installed APK from `dist/UniMarket.apk`.
