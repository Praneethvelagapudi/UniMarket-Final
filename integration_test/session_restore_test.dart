import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unimarket/app.dart';
import 'package:unimarket/main.dart' as app;
import 'package:unimarket/screens/auth_screen.dart';
import 'package:unimarket/screens/shell_screen.dart';
import 'package:unimarket/screens/profile_screen.dart';

// Run the identical command twice with --no-uninstall. A test-only preference
// selects setup on the first process and restoration on the next process.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('REVIEW_TEST_EMAIL');
  const password = String.fromEnvironment('REVIEW_TEST_PASSWORD');
  const expectedUid = String.fromEnvironment('REVIEW_TEST_UID');
  testWidgets('persist session across separate Android launches and log out', (
    tester,
  ) async {
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      fail('Screen did not appear: $finder');
    }

    expect(
      expectedUid,
      isNotEmpty,
      reason: 'Supply the ignored review-session define file.',
    );
    await app.main();
    await waitFor(find.byType(AuthGate));
    final scope = AppScope.of(tester.element(find.byType(AuthGate)));
    final setup =
        !(scope.settings.prefs.getBool('reviewSessionPrepared') ?? false);
    if (setup) {
      await tester.runAsync(() async {
        await scope.auth.logout();
        await scope.auth.login(email, password);
      });
    }
    await waitFor(find.byType(ShellScreen));
    expect(scope.auth.auth.currentUser?.uid, expectedUid);
    if (setup) {
      await tester.runAsync(
        () => scope.settings.prefs.setBool('reviewSessionPrepared', true),
      );
      debugPrint(
        'Session setup passed; launch this test again to verify restoration.',
      );
    } else {
      await tester.tap(find.byTooltip('Settings and profile'));
      await waitFor(find.text('Your campus corner'));
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Sign out'));
      await waitFor(find.text('Log out of UniMarket?'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(scope.auth.auth.currentUser?.uid, expectedUid);
      await tester.tap(find.text('Sign out'));
      await waitFor(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await waitFor(find.byType(AuthScreen));
      expect(scope.auth.auth.currentUser, isNull);
      await tester.runAsync(
        () => scope.settings.prefs.remove('reviewSessionPrepared'),
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'Session restored without login in a new process; UI logout passed.',
      );
    }
  });
}
