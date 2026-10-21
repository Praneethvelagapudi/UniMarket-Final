import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/app.dart';
import 'package:unimarket/screens/auth_screen.dart';
import 'package:unimarket/services/auth_service.dart';
import 'package:unimarket/services/market_service.dart';
import 'package:unimarket/services/notification_service.dart';

class FakeAuth extends Fake implements FirebaseAuth {}

class FakeDatabase extends Fake implements FirebaseFirestore {}

class TestAuthService extends AuthService {
  Future<void> Function()? onLogin;
  TestAuthService() : super(FakeAuth(), FakeDatabase());
  @override
  Future<void> login(String email, String password) async {
    await onLogin?.call();
  }
}

Future<void> render(WidgetTester tester, TestAuthService auth) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    AppScope(
      auth: auth,
      market: MarketService(FakeDatabase(), FakeAuth()),
      notifications: NotificationService(),
      settings: settings,
      child: MaterialApp(theme: marketTheme(false), home: const AuthScreen()),
    ),
  );
}

void main() {
  testWidgets('mobile login validates empty and non-campus inputs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(tester, TestAuthService());
    await tester.tap(find.text('Enter campus market'));
    await tester.pump();
    expect(
      find.text('Use your roll-number email ending in @cb.students.edu.'),
      findsOneWidget,
    );
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'registration has matching-roll and matching-password validation',
    (tester) async {
      await render(tester, TestAuthService());
      await tester.tap(find.text('New here? Create an account'));
      await tester.pump();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Campus Student');
      await tester.enterText(fields.at(1), 'CB.SC.U4ECE24157');
      await tester.enterText(fields.at(2), 'cb.sc.u4cse24157@cb.students.edu');
      await tester.enterText(fields.at(3), 'password123');
      await tester.enterText(fields.at(4), 'different123');
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(
        find.text('The email prefix must match your roll number.'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match.'), findsOneWidget);
    },
  );
  testWidgets('Firebase login error is understandable and loading ends', (
    tester,
  ) async {
    final auth = TestAuthService()
      ..onLogin = () async {
        throw FirebaseAuthException(code: 'invalid-credential');
      };
    await render(tester, auth);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'cb.sc.u4cse24157@cb.students.edu',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');
    await tester.tap(find.text('Enter campus market'));
    await tester.pumpAndSettle();
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'disposing a screen during login does not update disposed state',
    (tester) async {
      final pending = Completer<void>();
      final auth = TestAuthService()..onLogin = () => pending.future;
      await render(tester, auth);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'cb.sc.u4cse24157@cb.students.edu',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Enter campus market'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop login uses responsive introduction without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(tester, TestAuthService());
    expect(find.text('Less spend.\nMore campus.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
