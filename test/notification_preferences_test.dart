import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/app.dart';
import 'package:unimarket/screens/profile_screen.dart';
import 'package:unimarket/services/notification_service.dart';
import 'auth_gate_test.dart' as fixtures;

class PendingNotifications extends NotificationService {
  final pending = Completer<bool>();
  @override
  Future<bool> requestPermission() => pending.future;
}

class UndeliveredNotifications extends NotificationService {
  final bool permission;
  int showCalls = 0;
  UndeliveredNotifications({required this.permission});
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<bool> show(String id, String title, String body) async {
    showCalls++;
    return false;
  }
}

void main() {
  for (final permission in [true, false]) {
    testWidgets(
      permission
          ? 'device notification check explains a blocked booking channel'
          : 'device notification check explains denied permission without posting',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings(await SharedPreferences.getInstance());
        final auth = fixtures.TestAuth();
        final notifications = UndeliveredNotifications(permission: permission);
        await tester.pumpWidget(
          AppScope(
            auth: fixtures.TestAuthService(auth),
            market: fixtures.TestMarketService(auth),
            notifications: notifications,
            settings: settings,
            child: MaterialApp(
              home: Scaffold(
                body: ProfileScreen(profile: fixtures.TestProfile().data()),
              ),
            ),
          ),
        );
        final button = find.text('Test device notification');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(notifications.showCalls, permission ? 1 : 0);
        expect(
          find.textContaining(
            permission
                ? 'The booking alert could not be shown.'
                : 'Allow notifications in device or browser settings.',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await auth.changes.close();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  testWidgets(
    'a pending OS prompt cannot overwrite a later disabled preview preference',
    (tester) async {
      SharedPreferences.setMockInitialValues({'notifications': false});
      final settings = AppSettings(await SharedPreferences.getInstance());
      final auth = fixtures.TestAuth();
      final service = fixtures.TestAuthService(auth);
      final notifications = PendingNotifications();
      await tester.pumpWidget(
        AppScope(
          auth: service,
          market: fixtures.TestMarketService(auth),
          notifications: notifications,
          settings: settings,
          child: MaterialApp(
            home: ProfileScreen(profile: fixtures.TestProfile().data()),
          ),
        ),
      );
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Message & booking notifications',
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(settings.notifications, isTrue);
      await tester.tap(toggle);
      await tester.pump();
      expect(settings.notifications, isFalse);
      notifications.pending.complete(false);
      await tester.pump();
      expect(settings.notifications, isFalse);
      expect(find.textContaining('In-app alerts are enabled.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await auth.changes.close();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
