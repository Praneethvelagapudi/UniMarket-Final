import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/app.dart';
import 'package:unimarket/screens/auth_screen.dart';
import 'package:unimarket/screens/shell_screen.dart';
import 'package:unimarket/services/notification_service.dart';
import 'package:unimarket/widgets/logout_dialog.dart';
import 'auth_gate_test.dart' as fixtures;

class SessionAuth extends fixtures.TestAuth {
  User? user;
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => Stream<User?>.multi((controller) {
    // Firebase replays the current session to every new subscriber, including
    // the AuthGate created when a session-keyed Navigator is reset.
    controller.add(user);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });
  void emit(User? value) {
    user = value;
    changes.add(value);
  }
}

class SessionService extends fixtures.TestAuthService {
  final SessionAuth session;
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;
  SessionService(this.session) : super(session);
  @override
  Future<void> logout() async {
    calls++;
    if (fail) throw StateError('Logout failed. Try again.');
    if (pending != null) await pending!.future;
    session.emit(null);
  }
}

void main() {
  late SessionAuth auth;
  late SessionService service;
  setUp(() {
    auth = SessionAuth();
    service = SessionService(auth);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    await auth.changes.close();
    for (final stream in service.profiles.values) {
      await stream.close();
    }
  });
  Future<void> render(WidgetTester tester) async {
    final settings = AppSettings(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      AppScope(
        auth: service,
        market: fixtures.TestMarketService(auth),
        notifications: NotificationService(),
        settings: settings,
        child: UniMarketApp(settings: settings),
      ),
    );
    auth.emit(fixtures.TestUser('first'));
    await tester.pump();
    await tester.pump();
    auth.emit(auth.user);
    await tester.pump();
    service.profiles['first']!.add(fixtures.TestProfile());
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShellScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ShellScreen))).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Protected detail')),
          body: TextButton(
            onPressed: () => confirmLogout(context),
            child: const Text('Sign out here'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Sign out here'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Cancel keeps the session and current protected navigation unchanged',
    (tester) async {
      await render(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.currentUser?.uid, 'first');
      expect(service.calls, 0);
      expect(find.text('Protected detail'), findsOneWidget);
      expect(find.text('Log out of UniMarket?'), findsNothing);
    },
  );
  testWidgets('Logout disposes all protected routes and the back stack', (
    tester,
  ) async {
    await render(tester);
    await tester.tap(find.text('Logout'));
    await tester.pump();
    await tester.pump();
    expect(auth.currentUser, isNull);
    expect(service.calls, 1);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Protected detail'), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(AuthScreen))).canPop(),
      isFalse,
    );
  });
  testWidgets(
    'remote logout failure remains visible without losing the session',
    (tester) async {
      await render(tester);
      service.fail = true;
      await tester.tap(find.text('Logout'));
      await tester.pump();
      expect(find.text('Logout failed. Try again.'), findsOneWidget);
      expect(auth.currentUser?.uid, 'first');
      service.fail = false;
      await tester.tap(find.text('Logout'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AuthScreen), findsOneWidget);
    },
  );
  testWidgets(
    'duplicate logout taps are disabled while the request is pending',
    (tester) async {
      await render(tester);
      service.pending = Completer<void>();
      await tester.tap(find.text('Logout'));
      await tester.pump();
      expect(find.text('Logging out…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(service.calls, 1);
      service.pending!.complete();
      await tester.pump();
      await tester.pump();
      expect(auth.currentUser, isNull);
    },
  );
  testWidgets(
    'external authentication loss also removes a pushed protected route',
    (tester) async {
      await render(tester);
      auth.emit(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Protected detail'), findsNothing);
      expect(find.text('Log out of UniMarket?'), findsNothing);
    },
  );
}
