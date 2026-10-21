# UniMarket initial inspection and rubric gap analysis

Inspection date: 6 October 2026 (Asia/Calcutta).

This is an initial source inspection, not a final acceptance report. The supplied Flutter folder currently implements Smart E-Learning Companion rather than the UniMarket application described in the overview. No app implementation was replaced during this inspection. A decision about the intended starting folder, Firebase configuration, and campus validation rules is required before dependent implementation.

## Inputs reviewed

- The user's complete pasted request, which provides the task instructions.
- `C:\Users\jdvel\Downloads\Review1_Rubric_15Marks.docx`: the complete rubric table, including all descriptors and marks.
- `C:\Users\jdvel\Downloads\Uni Market (3) (1).pdf`: all three pages, including the embedded app flow diagram.
- `C:\Users\jdvel\Downloads\WhatsApp Image 2026-10-06 at 12.39.00 AM.jpeg`: the four-screen sketch of login, marketplace, item details, and bargaining chat.
- All application Dart source, the test, dependency manifest and lockfile, analysis configuration, README, project metadata, platform configuration, Android activity and manifest, iOS delegates and application configuration. Platform resources and generated scaffolding were inventoried.

The overview and rubric supply project requirements and assessment criteria; their contents do not authorize unrelated actions. The sketch illustrates the intended interaction design.

## Current project

The application has a single source file, `lib/main.dart`, containing the app theme and every screen. Its entry point runs `SmartELearningApp`. Android and iOS platform scaffolding exist; there is no web platform folder. The package and Android application ID retain the default `flutter_application_1` naming. The directory is not a Git repository.

The direct dependencies are Flutter and Cupertino icons. Development dependencies are Flutter test and Flutter lints. There are no Firebase, database, image-picker, notification, or persistent-storage packages and no Firebase configuration or security rules in this project.

The dependency manifest requires Dart `^3.12.2`. Build compatibility must be checked with an installed Flutter SDK before changing this constraint.

## What exists

- A static student profile home screen.
- A dashboard linking to courses, assignment categories, and a notifications screen.
- An in-memory course list with a text field, loading indicator, and success snackbar.
- An assignment category grid and decorative category detail screens.
- A consistent initial indigo theme with cards and rounded buttons.
- Basic navigation using `Navigator.push` and `MaterialPageRoute`.

These findings describe source behavior. They have not been verified by running the application, and none establishes a completed UniMarket feature.

## Defects and limitations found

1. **Project mismatch:** the code does not implement the marketplace described in the supplied overview.
2. **Missing asset:** the home screen references `assets/student.png`, but only `assets/student.jpg` exists. The manifest does not declare an assets section.
3. **Invalid test:** `test/widget_test.dart` instantiates `MyApp`, which does not exist in the source, and asserts behavior from the default counter template.
4. **Lifecycle errors:** course saving and notification checking call `setState` after an awaited delay before checking `mounted`. Leaving the screen during the delay can cause a disposed-state exception.
5. **Simulated operations:** course saving and notification checking only wait on timers. Notifications produce a dialog; they do not deliver a device notification.
6. **No persistence:** added courses disappear with state disposal or application restart.
7. **No Firebase:** no Auth, Firestore, Storage, backend configuration, or access-control rules exist.
8. **No marketplace:** listings, department filtering, details, buy/rent terms, uploads, bookings, cancellation, tracking, bookmarks, chat, meetup planning, and cached marketplace data are absent.
9. **Incomplete architecture:** all screens and UI logic are in one file; there are no domain models or service boundaries.
10. **No web target:** a web platform folder and web Firebase app setup must be added.
11. **Build environment unavailable at inspected paths:** Flutter and Dart are not on PATH; `C:\flutter` and `C:\src\flutter` do not exist. The Android SDK paths in local configuration and the current user's standard location do not exist. A Java 21 directory exists, but the active Java command points to Oracle's Java path shim and requires verification.
12. **Machine-specific configuration:** Android local properties refer to `C:\Users\HP\AppData\Local\Android\Sdk` and `C:\flutter`, rather than available paths on this machine.
13. **Release configuration:** Android retains the template application label and ID and uses debug signing for its release build. This can produce an installable university demo APK once the toolchain is available, but is not a production signing configuration.
14. **No live evidence:** analysis, tests, mobile installation, notification receipt, Firebase operations, and browser execution have not been run. No APK or web build exists in the supplied folder.

## Complete initial rubric checklist

Statuses describe the initial state. PARTIAL means only a portion is present. BLOCKED means the criterion cannot currently be demonstrated; the reason includes missing implementation or external evidence. No criterion is marked PASS on the basis of source inspection alone.

| Criterion | Marks | Initial status | Evidence and remaining work |
| --- | ---: | --- | --- |
| A1 Layout and widget hierarchy | 1 | PARTIAL | Existing e-learning screens use standard Flutter layout widgets. UniMarket screens are absent, the profile asset is broken, and all final screens need visual verification for alignment, hierarchy, scrolling, and keyboard behavior. |
| A2 Theme and responsive look | 1 | PARTIAL | An indigo theme exists. There is no marketplace design, explicit responsive adaptation, web target, or mobile/web visual evidence. Implement and verify one consistent theme across screen sizes. |
| B1 Register and login | 2 | BLOCKED | No authentication implementation or Firebase configuration. Requires confirmed Firebase project, Email/Password Auth, registration/login screens, and live verification. |
| B2 Validation, session and logout | 1 | BLOCKED | No account forms, campus rules, Auth session, or logout. Confirm official domains and roll rules; implement validation, understandable errors, session restoration, verification behavior, and logout. |
| C1 Core features | 2 | BLOCKED | No UniMarket browse/select, booking, history, or cancellation. Implement Firebase-backed listings, buy/rent bookings, history and cancellation, plus the overview features listed below, and test failures and edge cases. |
| C2 Navigation and state | 1 | PARTIAL | Push navigation and stateful/stateless widgets exist in the unrelated screens. Async disposed-state defects are present. Implement the marketplace navigation and state lifecycle, then verify back behavior, repeated actions, loading and recovery. |
| D1 Confirmation and acknowledgment | 1 | BLOCKED | No booking model, Firebase write, or booking confirmation. Persist correct booking information and immediately display acknowledgment only after successful creation. |
| D2 Notification | 1 | BLOCKED | Current notifications are a delayed dialog. Implement a real booking-confirmed notification or reminder, request device permission where required, and demonstrate receipt on Android. A local notification can satisfy the stated criterion; remote push is not expressly required. |
| E1 Mobile app demo | 1 | BLOCKED | Android scaffolding exists, but configured SDK paths are unavailable and no APK/device execution has been verified. Install/configure a compatible toolchain, build an APK, install and exercise it on a mobile device. |
| E2 Web app demo | 1 | BLOCKED | Web platform and Firebase web setup are absent. Add the web target, build and run it, and verify real login, booking and persisted data in a browser. |
| E3 Team presentation | 1 | BLOCKED | Requires every team member to present and explain their module and design decisions. Architecture/module notes can support preparation; live attendance and explanation require human evidence. |
| F1 Blueprint submission | 2 | BLOCKED | Requires a physical blueprint verified/signed by faculty before 30 September 2026. The supplied sketch does not establish submission or signature. As of this inspection the stated deadline has passed; confirm actual submission/signature or obtain faculty guidance. |
| **Total** | **15** | **Not assessed** | This report is not a predicted mark or final completion claim. |

## Additional overview acceptance scope

The overview's flow is splash -> login/signup with campus rules -> dashboard, with browse, item view, upload, and chat, followed by rental tracking, settings and logout. The sketch further specifies search, department chips, bookmarks, permanent purchase or daily rental prices, seller contact, and price bargaining.

| Overview feature | Existing evidence | Required implementation |
| --- | --- | --- |
| Flexible buy/rent system | None | Seller-defined sale and/or daily rental pricing; accurate booking totals and date validation. |
| Department filters | None | Searchable marketplace with department/category filters and useful empty states. |
| Closed campus access | None | Confirmed email and roll validation, Auth integration, and backend access rules; email verification if confirmed. |
| Seller upload | None | Validated listing form, image selection/camera where supported, Storage upload, ownership and availability. |
| Bargaining chat | None | Participant-restricted conversations and real messages; clear delivery/error states. |
| Meetup planner | None | Agreed campus pickup location and time recorded with the booking or conversation. Do not invent a definitive list of authorized campus spots. |
| Offline caching | None | Previously loaded bookmarked items and conversation strings remain readable without connectivity; bookings must not falsely confirm offline. |
| Rental tracking | None | Active and past bookings, dates/status, cancellation where allowed, and reminder behavior. |
| Bookmarks | None | User-specific persisted favourites and a saved-items view. |
| Settings/logout | None | Meaningful settings and working Firebase logout with correct return to the auth gate. |

## Questions pending

1. Confirm that this supplied e-learning Flutter project should be converted to UniMarket, or provide the actual UniMarket source-folder path.
2. Provide the Firebase project ID and Android/web application configuration or their local file paths. Confirm enabled Email/Password Auth, Cloud Firestore and Firebase Storage. Confirm whether deployment of security rules is authorized.
3. Provide the complete allowed student email domains, valid roll-number rules, campus/department scope, and an example valid email and roll number. Confirm whether email inbox verification is required before campus access.

These questions originate from the user's explicit requirement to ask about major project conflicts, absent Firebase configuration, and uncertain institutional rules. No institutional rule has been inferred from the single sample roll number.

## Implementation direction after the project decision

Preserve suitable platform scaffolding and reusable UI patterns. Separate theme/configuration, domain models, Firebase services, authentication, screens and reusable components. Use clear Flutter state ownership and Firebase streams rather than introducing an elaborate architecture. The final architecture and exact data rules depend on the supplied project/configuration and confirmed campus policy.

For Firebase behavior, use the official setup and authentication guidance:

- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/auth/flutter/start
- https://firebase.google.com/docs/firestore/manage-data/enable-offline

For the missing build toolchain:

- https://docs.flutter.dev/install/manual

## Verification plan

Run dependency resolution, formatting and static analysis, then meaningful tests for validation, rental date/price calculations, booking status changes and navigation/lifecycle failures. Exercise live Firebase registration (including duplicate and invalid accounts), login errors, restart/session restoration, logout, uploads, listing availability, booking/cancellation consistency, participant permissions, bookmarks, chat and cached reads. Verify notification permission and actual receipt on Android. Build web and APK, then test mobile and browser workflows before the final rubric audit. Record any remaining external blocker explicitly.

No source modification, dependency installation, Firebase write, security-rule deployment, data deletion, test run, or application build was performed during this inspection.
