import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/app.dart';

void main() {
  testWidgets(
    'unconfigured build shows honest setup status instead of fake functionality',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        UniMarketApp(
          settings: settings,
          startupError: 'Firebase has not been configured for this build.',
        ),
      );
      expect(find.text('UniMarket'), findsOneWidget);
      expect(
        find.text('Firebase has not been configured for this build.'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
