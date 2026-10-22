import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unimarket/services/notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual Android booking and incoming-message notification channels',
    (tester) async {
      final notifications = NotificationService();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Notification verification')),
          ),
        ),
      );
      expect(NotificationService.supported, isTrue);
      expect(
        await tester.runAsync(notifications.requestPermission),
        isTrue,
        reason: 'Grant POST_NOTIFICATIONS to this QA package before execution.',
      );
      final token = DateTime.now().millisecondsSinceEpoch.toString();
      for (final channel in ['bookings', 'messages']) {
        final id = channel == 'messages'
            ? 'message-qa-$token'
            : 'booking-qa-$token';
        expect(
          await tester.runAsync(
            () => notifications.show(
              id,
              channel == 'messages'
                  ? 'QA sender · UniMarket'
                  : 'Booking confirmed · UniMarket QA',
              'Android $channel delivery verification $token',
            ),
          ),
          isTrue,
        );
        debugPrint('NOTIFICATION_QA_${channel.toUpperCase()}_POSTED $token');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 8)),
        );
      }
      await tester.runAsync(notifications.clear);
      debugPrint('NOTIFICATION_QA_CLEARED');
      expect(tester.takeException(), isNull);
    },
  );
}
