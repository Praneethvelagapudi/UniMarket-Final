import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unimarket/app.dart';
import 'package:unimarket/main.dart' as app;
import 'package:unimarket/screens/auth_screen.dart';
import 'package:unimarket/screens/chat_screen.dart';
import 'package:unimarket/screens/booking_screen.dart';
import 'package:unimarket/screens/shell_screen.dart';
import 'package:unimarket/models/models.dart';
import 'package:unimarket/services/market_service.dart';
import 'package:unimarket/services/message_center.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'live recipient banner, unread, read persistence and reply across two accounts',
    (tester) async {
      const primaryEmail = String.fromEnvironment('QA_PRIMARY_EMAIL');
      const primaryPassword = String.fromEnvironment('QA_PRIMARY_PASSWORD');
      const primaryUid = String.fromEnvironment('QA_PRIMARY_UID');
      const peerEmail = String.fromEnvironment('QA_PEER_EMAIL');
      const peerPassword = String.fromEnvironment('QA_PEER_PASSWORD');
      const peerUid = String.fromEnvironment('QA_PEER_UID');
      const conversationId = String.fromEnvironment('QA_CONVERSATION_ID');
      expect(
        primaryUid,
        isNotEmpty,
        reason: 'Supply the ignored Evaluation 2 demo-account define file.',
      );
      Future<void> waitUntil(bool Function() ready, String description) async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (ready()) return;
        }
        fail('Timed out: $description');
      }

      await app.main();
      await waitUntil(
        () => find.byType(AuthGate).evaluate().isNotEmpty,
        'auth gate',
      );
      final scope = AppScope.of(tester.element(find.byType(AuthGate)));
      expect(scope.market.db.app.options.projectId, 'uni-market-7ef26');
      await tester.runAsync(() async {
        await scope.auth.logout();
        await scope.auth.login(primaryEmail, primaryPassword);
      });
      await waitUntil(
        () => find.byType(ShellScreen).evaluate().isNotEmpty,
        'primary account shell',
      );
      expect(scope.market.uid, primaryUid);
      MessageCenter? center;
      await waitUntil(() {
        center = MessageScope.maybeOf(tester.element(find.byType(ShellScreen)));
        return center != null && center!.preview(conversationId).isNotEmpty;
      }, 'recipient message subscriptions');
      await tester.runAsync(
        () => scope.market
            .messages(conversationId)
            .firstWhere((s) => !s.metadata.isFromCache)
            .timeout(const Duration(seconds: 20)),
      );
      await tester.pump();
      final previousPreference = scope.settings.notifications;
      await tester.runAsync(() => scope.settings.setNotifications(true));
      expect(
        await tester.runAsync(scope.notifications.requestPermission),
        isTrue,
        reason:
            'Grant Android POST_NOTIFICATIONS to this test package before running.',
      );
      FirebaseApp? peerApp;
      FirebaseAuth? peerAuth;
      String? notificationListingId;
      String? notificationBookingId;
      try {
        late MarketService peer;
        await tester.runAsync(() async {
          peerApp = await Firebase.initializeApp(
            name: 'eval2-peer-${DateTime.now().millisecondsSinceEpoch}',
            options: scope.market.db.app.options,
          );
          peerAuth = FirebaseAuth.instanceFor(app: peerApp!);
          await peerAuth!.signInWithEmailAndPassword(
            email: peerEmail,
            password: peerPassword,
          );
          expect(peerAuth!.currentUser!.uid, peerUid);
          peer = MarketService(
            FirebaseFirestore.instanceFor(app: peerApp!),
            peerAuth!,
          );
        });
        final before = center!.unread(conversationId);
        final token = 'Eval2 sync ${DateTime.now().millisecondsSinceEpoch}';
        await tester.runAsync(() => peer.sendMessage(conversationId, token));
        await waitUntil(
          () => center!.unread(conversationId) > before,
          'recipient unread update',
        );
        await waitUntil(
          () => find.textContaining(token).evaluate().isNotEmpty,
          'incoming in-app banner',
        );
        debugPrint('EVAL2_MESSAGE_NOTIFICATION_POSTED $token');
        // A bounded observation window lets the host capture the actual Android
        // NotificationRecord before session cleanup removes private previews.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 8)),
        );
        final chat = await tester.runAsync(
          () => scope.market.db
              .collection('conversations')
              .doc(conversationId)
              .get(const GetOptions(source: Source.server)),
        );
        final title = chat!.data()!['title'] as String;
        expect(title, startsWith('[Review demo]'));
        Navigator.of(tester.element(find.byType(ShellScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(id: conversationId, title: title),
          ),
        );
        await waitUntil(
          () => find.byType(ChatScreen).evaluate().isNotEmpty,
          'recipient chat',
        );
        await waitUntil(
          () => center!.unread(conversationId) == 0,
          'persisted read state',
        );
        final reply = '$token reply';
        await tester.enterText(find.byType(TextField), reply);
        await tester.tap(find.byTooltip('Send message'));
        await tester.runAsync(
          () => peer
              .messages(conversationId)
              .firstWhere(
                (snapshot) =>
                    snapshot.docs.any((d) => d.data()['text'] == reply),
              )
              .timeout(const Duration(seconds: 20)),
        );
        expect(
          center!.unread(conversationId),
          0,
          reason: 'The sender must not gain unread state for its own reply.',
        );
        notificationListingId = await tester.runAsync(
          () => scope.market.publish(
            {
              'title': '[Notification QA] Calculator $token',
              'description': 'Disposable notification verification fixture.',
              'department': 'CSE',
              'category': 'Electronics',
              'condition': 'Good',
              'salePrice': 100.0,
              'dailyRate': 5.0,
            },
            null,
            null,
          ),
        );
        await tester.runAsync(() async {
          await scope.auth.logout();
          await scope.auth.login(peerEmail, peerPassword);
        });
        await waitUntil(
          () =>
              find.byType(ShellScreen).evaluate().isNotEmpty &&
              scope.market.uid == peerUid,
          'buyer shell for actual booking notification',
        );
        final item = await tester.runAsync(() async {
          return Listing.fromDoc(
            await scope.market.db
                .collection('listings')
                .doc(notificationListingId)
                .get(const GetOptions(source: Source.server)),
          );
        });
        expect(item!.ownerId, primaryUid);
        Navigator.of(tester.element(find.byType(ShellScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => BookingScreen(item: item, mode: 'buy'),
          ),
        );
        await waitUntil(
          () => find.byType(BookingScreen).evaluate().isNotEmpty,
          'actual reservation form',
        );
        await tester.enterText(
          find.byType(TextFormField),
          'Notification QA campus pickup',
        );
        final confirm = find.text('Confirm reservation');
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await waitUntil(
          () => find.byType(BookingReceiptScreen).evaluate().isNotEmpty,
          'saved receipt after native notification delivery',
        );
        notificationBookingId = tester
            .widget<BookingReceiptScreen>(find.byType(BookingReceiptScreen))
            .id;
        final saved = await tester.runAsync(
          () => scope.market.db
              .collection('bookings')
              .doc(notificationBookingId)
              .get(const GetOptions(source: Source.server)),
        );
        expect(saved!.data()!['buyerId'], peerUid);
        expect(saved.data()!['status'], 'confirmed');
        expect(saved.data()!['total'], 100.0);
        debugPrint(
          'NOTIFICATION_QA_LIVE_BOOKING_POSTED $notificationBookingId',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 8)),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          try {
            if (notificationBookingId != null) {
              final doc = await scope.market.db
                  .collection('bookings')
                  .doc(notificationBookingId)
                  .get(const GetOptions(source: Source.server));
              final booking = Booking.fromDoc(doc);
              if (booking.status == 'confirmed') {
                await scope.market.updateBooking(booking, 'cancelled');
              }
            }
            if (notificationListingId != null) {
              if (scope.market.uid != primaryUid) {
                await scope.auth.logout();
                await scope.auth.login(primaryEmail, primaryPassword);
              }
              final doc = await scope.market.db
                  .collection('listings')
                  .doc(notificationListingId)
                  .get(const GetOptions(source: Source.server));
              final listing = Listing.fromDoc(doc);
              if (listing.available) await scope.market.archiveListing(listing);
            }
          } finally {
            await peerAuth?.signOut();
            await peerApp?.delete();
            await scope.settings.setNotifications(previousPreference);
            await scope.auth.logout();
          }
        });
      }
    },
  );
}
