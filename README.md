# UniMarket Final

Campus peer-to-peer academic buy and rent marketplace built with Flutter, Firebase Authentication and Firestore.

Repository owner: [Praneethvelagapudi](https://github.com/Praneethvelagapudi).

## Current repository status

Praneeth's authentication/Firebase/messaging imports, Mohith's navigation/state/build imports, and Poojith's UI/theme/presentation imports are now committed through their respective authenticated accounts. A fresh checkout is still incomplete: Chenchu's booking, payment simulation, PDF and notification modules remain to be added.

The complete local application is version 1.0.3 (4). Its earlier verification included 41 passing Flutter tests, clean analysis, and Android 10 booking/message notification checks. Those are results for the complete application, not a claim that this partial checkout can currently pass the same checks.

## Team and module allocation

| Member | GitHub | Responsibility | Import status |
| --- | --- | --- | --- |
| V. Praneeth | [Praneethvelagapudi](https://github.com/Praneethvelagapudi) | Authentication, Firebase, messaging and voice | Included |
| M. Mohith | [MohithKumar128](https://github.com/MohithKumar128) | Navigation, state and release readiness | Included through authenticated Mohith account |
| R. Chenchu Siva Sai | [Chenchu2007](https://github.com/Chenchu2007) | Booking confirmations, notifications, payment simulation and PDFs | Awaiting own account's commits |
| V. Poojith Kumar | [poojithkumarvemisetty](https://github.com/poojithkumarvemisetty) | UI design, theme and responsive layouts | Included through authenticated Poojith account |

Teammate accounts are invited as collaborators with write access. Each member must accept the invitation before pushing. An invitation alone does not create contributor credit.

## Praneeth's published modules

- Firebase client configuration templates and campus account validation.
- Authentication forms, sign-in, registration and acknowledged user profiles.
- Firestore access rules, indexing and the shared transactional data service.
- Private messaging, recipient read state and live synchronization checks.
- Bounded voice recording, WAV validation, preview and playback.

Shared services contain other modules' integration points. Importing a shared file does not establish exclusive authorship of every method. The team reports describe AI-assisted development and remain subject to each student's confirmation of personal work.

## History and contribution process

This repository was created on 22 October 2026 after the existing application had been developed. Current module commits explicitly import existing work using real dates; they do not establish regular commits during earlier development. Praneeth, Mohith and Poojith are recorded as author and committer for their respective imports. Each upload uses that member's authenticated Git account; assisted operations are performed on the account owner's behalf. See [the contribution process](CONTRIBUTING.md) and [team responsibilities](docs/TEAM_CONTRIBUTIONS.md).

## Mohith's published modules

- Flutter bootstrap, shared error handling and dependency configuration.
- Tab navigation and session restoration checks.
- Protected-route logout integration and state regression cases.
- Android build configuration and platform declarations.
- Existing iOS scaffold, without a claim of iOS device validation.
- Developer tooling and historical release-readiness documentation.

## Poojith's published modules

- UniMarket branding, app icons and Android launch appearance.
- Material theme and shared application presentation.
- Reusable UI states and bounded listing-photo processing.
- Marketplace discovery and listing-detail layouts.
- Listing forms and profile preferences presentation.
- Web presentation scaffold and demonstration guide.

## Setup after all modules are added

1. Install Flutter compatible with the Dart SDK constraint in the completed `pubspec.yaml`, together with the Android SDK.
2. Copy `config/firebase.example.json` to `config/firebase.json` and supply the intended Firebase project's public client configuration. For Android, register `edu.students.unimarket` and supply the ignored `android/app/google-services.json` required by its Google Services build plugin.
3. Enable Firebase email/password authentication and Firestore. Deploy `firestore.rules` and `firestore.indexes.json` only to your intended project with appropriate Firebase permissions.
4. Run `flutter pub get`, then `flutter run --dart-define-from-file=config/firebase.json`.
5. Run `flutter test` and `flutter analyze`; build with `flutter build apk --release --dart-define-from-file=config/firebase.json`.

Local deployment settings, account credentials, generated APKs, personal reports and raw presentation evidence are excluded. Local notifications depend on the app process and notification permission; terminated-app push delivery and real payment processing are not implemented.
