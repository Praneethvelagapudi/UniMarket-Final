import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as image;
import 'package:unimarket/main.dart' as app;
import 'package:unimarket/app.dart';
import 'package:unimarket/models/models.dart';
import 'package:unimarket/screens/auth_screen.dart';
import 'package:unimarket/screens/shell_screen.dart';
import 'package:unimarket/screens/booking_screen.dart';
import 'package:unimarket/services/notification_service.dart';
import 'package:unimarket/services/payment_service.dart';
import 'package:unimarket/services/invoice_service.dart';
import 'package:unimarket/services/voice_clip.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Firebase registration, photos, chat, buy/rent and cancellation', (
    tester,
  ) async {
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('Screen did not appear: $finder');
    }

    await app.main();
    await waitFor(find.byType(AuthGate));
    final scope = AppScope.of(tester.element(find.byType(AuthGate)));
    await tester.runAsync(scope.auth.logout);
    await waitFor(find.byType(AuthScreen));
    final db = scope.market.db;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final sellerRoll = 'CB.SC.U4CSE9$stamp';
    final buyerRoll = 'CB.SC.U4ECE9$stamp';
    final secureRandom = Random.secure();
    final password =
        'ReviewQa!${base64UrlEncode(List<int>.generate(24, (_) => secureRandom.nextInt(256)))}';
    String? sellerUid;
    String? itemId;
    String? buyerUid;
    String? conversationId;
    String? buyId;
    String? rentId;
    await tester.runAsync(() async {
      await scope.auth.register(
        'Review Test Seller',
        sellerRoll,
        '${sellerRoll.toLowerCase()}@cb.students.edu',
        password,
      );
      sellerUid = scope.market.uid;
    });
    await waitFor(find.byType(ShellScreen));
    await tester.runAsync(() async {
      // A tiny, valid PNG exercises the same bounded JPEG upload path as the UI.
      final photoBytes = image.encodePng(image.Image(width: 20, height: 20));
      itemId = await scope.market.publish(
        {
          'title': 'Review test calculator $stamp',
          'description':
              'Automated review fixture for buy, rent, photo and chat verification.',
          'department': 'ECE',
          'category': 'Electronics',
          'condition': 'Good',
          'salePrice': 300.0,
          'dailyRate': 15.0,
        },
        photoBytes,
        'image/png',
      );
      final photo = await db
          .collection('listing-images')
          .doc(itemId)
          .get(const GetOptions(source: Source.server));
      expect(photo.data()!['contentType'], 'image/jpeg');
      expect(
        base64Decode(photo.data()!['data']).length,
        lessThanOrEqualTo(180000),
      );
      await scope.auth.logout();
    });
    await waitFor(find.byType(AuthScreen));
    await tester.runAsync(() async {
      await scope.auth.register(
        'Review Test Buyer',
        buyerRoll,
        '${buyerRoll.toLowerCase()}@cb.students.edu',
        password,
      );
      buyerUid = scope.market.uid;
    });
    await waitFor(find.byType(ShellScreen));
    await tester.runAsync(() async {
      final item = Listing.fromDoc(
        await db
            .collection('listings')
            .doc(itemId)
            .get(const GetOptions(source: Source.server)),
      );
      await scope.market.saveBookmark(item, false);
      expect(
        (await db
                .collection('users')
                .doc(buyerUid)
                .collection('bookmarks')
                .doc(itemId)
                .get())
            .exists,
        isTrue,
      );
      conversationId = await scope.market.openConversation(item);
      await scope.market.sendMessage(
        conversationId!,
        'Can we meet at the campus library?',
      );
      expect(
        (await scope.market.messages(conversationId!).first).docs.single
            .data()['text'],
        'Can we meet at the campus library?',
      );
      await db.disableNetwork();
      try {
        expect(
          (await db
                  .collection('users')
                  .doc(buyerUid)
                  .collection('bookmarks')
                  .doc(itemId)
                  .get(const GetOptions(source: Source.cache)))
              .exists,
          isTrue,
        );
        expect(
          (await db
                  .collection('conversations')
                  .doc(conversationId)
                  .collection('messages')
                  .get(const GetOptions(source: Source.cache)))
              .docs
              .single
              .data()['text'],
          'Can we meet at the campus library?',
        );
      } finally {
        await db.enableNetwork();
      }
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final end = start.add(const Duration(days: 3));
      buyId = await scope.market.createBooking(
        item: item,
        mode: 'buy',
        start: start,
        end: end,
        pickupAt: start.add(const Duration(hours: 12)),
        pickupSpot: 'Campus library entrance',
      );
      final buy = Booking.fromDoc(
        await db
            .collection('bookings')
            .doc(buyId)
            .get(const GetOptions(source: Source.server)),
      );
      expect(buy.total, 300);
      expect(buy.status, 'confirmed');
      expect(buy.buyerId, buyerUid);
      expect(buy.sellerId, sellerUid);
    });
    // Render the actual persisted receipt and use its cancellation controls.
    final context = tester.element(find.byType(ShellScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingReceiptScreen(id: buyId!, confirmation: true),
      ),
    );
    await waitFor(find.text('You’re all booked.'));
    expect(find.text('Campus library entrance'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final receiptImage = await binding.takeScreenshot('eval2-saved-receipt');
    await tester.runAsync(
      () => File(
        '${Directory.systemTemp.path}/eval2-saved-receipt.png',
      ).writeAsBytes(receiptImage),
    );
    await tester.ensureVisible(find.text('Cancel booking'));
    await tester.tap(find.text('Cancel booking'));
    await waitFor(find.text('Cancel this booking?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await waitFor(find.text('Booking cancelled'));
    await tester.ensureVisible(find.text('Back to campus market'));
    await tester.tap(find.text('Back to campus market'));
    await waitFor(find.byType(ShellScreen));
    await tester.runAsync(() async {
      expect(
        (await db.collection('listings').doc(itemId).get()).data()!['status'],
        'available',
      );
      final item = Listing.fromDoc(
        await db.collection('listings').doc(itemId).get(),
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      rentId = await scope.market.createBooking(
        item: item,
        mode: 'rent',
        start: start,
        end: start.add(const Duration(days: 3)),
        pickupAt: start.add(const Duration(hours: 12)),
        pickupSpot: 'Campus library entrance',
      );
      final rental = Booking.fromDoc(
        await db.collection('bookings').doc(rentId).get(),
      );
      expect(rental.days, 3);
      expect(rental.total, 45);
      if (NotificationService.supported) {
        expect(
          await scope.notifications.requestPermission(),
          isTrue,
          reason: 'Grant POST_NOTIFICATIONS to the test APK before running.',
        );
        expect(
          await scope.notifications.show(
            rentId!,
            'Booking confirmed',
            'Review calculator · 3 days · ₹45',
          ),
          isTrue,
        );
        debugPrint('EVAL2_BOOKING_NOTIFICATION_POSTED');
        await Future<void>.delayed(const Duration(seconds: 8));
      }
      await scope.auth.logout();
      await scope.auth.login(
        '${sellerRoll.toLowerCase()}@cb.students.edu',
        password,
      );
      expect(
        (await scope.market.messages(conversationId!).first).docs.single
            .data()['senderId'],
        buyerUid,
      );
      final textId = scope.market.newMessageId(conversationId!);
      await scope.market.sendMessage(
        conversationId!,
        'Evaluation 2 test reply',
        messageId: textId,
      );
      await scope.market.sendMessage(
        conversationId!,
        'Evaluation 2 test reply',
        messageId: textId,
      );
      final voiceId = scope.market.newMessageId(conversationId!);
      final clip = VoiceClip.fromPcm(Uint8List(16000));
      await scope.market.sendVoice(conversationId!, clip, messageId: voiceId);
      await scope.market.sendVoice(conversationId!, clip, messageId: voiceId);
      final sent = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get(const GetOptions(source: Source.server));
      expect(
        sent.docs.length,
        3,
        reason: 'Retries must not duplicate text or voice messages.',
      );
      await scope.market.updateBooking(
        Booking.fromDoc(await db.collection('bookings').doc(rentId).get()),
        'completed',
      );
      expect(
        (await db.collection('listings').doc(itemId).get()).data()!['status'],
        'available',
      );
      await scope.auth.logout();
      await scope.auth.login(
        '${buyerRoll.toLowerCase()}@cb.students.edu',
        password,
      );
      final received = await scope.market.loadVoice(conversationId!, voiceId);
      expect(received.bytes, clip.bytes);
      expect(received.durationMs, 1000);
      final messages = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt')
          .get(const GetOptions(source: Source.server));
      final lastAt = messages.docs.last.data()['createdAt'] as Timestamp;
      await scope.market.markConversationRead(conversationId!, lastAt);
      expect(
        (await db
                .collection('conversations')
                .doc(conversationId)
                .collection('reads')
                .doc(buyerUid)
                .get())
            .data()!['readAt'],
        lastAt,
      );
      final available = Listing.fromDoc(
        await db
            .collection('listings')
            .doc(itemId)
            .get(const GetOptions(source: Source.server)),
      );
      final mockTomorrow = DateTime.now().add(const Duration(days: 1));
      final mockStart = DateTime(
        mockTomorrow.year,
        mockTomorrow.month,
        mockTomorrow.day,
      );
      final mockId = await scope.market.createBooking(
        item: available,
        mode: 'buy',
        start: mockStart,
        end: mockStart.add(const Duration(days: 1)),
        pickupAt: mockStart.add(const Duration(hours: 12)),
        pickupSpot: 'Evaluation 2 campus library test',
        simulatePayment: true,
      );
      final payments = MockPaymentService(scope.market);
      final first = await payments.begin(mockId);
      expect(await payments.begin(mockId), first);
      await payments.finish(mockId, first, 'failed');
      await expectLater(
        InvoiceService.loadSaved(scope.market, mockId),
        throwsStateError,
      );
      final second = await payments.begin(mockId);
      expect(second, isNot(first));
      await payments.finish(mockId, second, 'cancelled');
      final third = await payments.begin(mockId);
      expect(third, isNot(second));
      await payments.finish(mockId, third, 'pending');
      expect(await payments.begin(mockId), third);
      await payments.finish(mockId, third, 'succeeded');
      await payments.finish(mockId, third, 'succeeded');
      final confirmation = await InvoiceService.loadSaved(scope.market, mockId);
      expect(confirmation.total, 300);
      expect(confirmation.title, available.title);
      expect(confirmation.paymentReference, 'mock_${mockId}_$third');
      expect(confirmation.paymentStatus, 'succeeded');
      final pdf = await InvoiceService.generate(confirmation);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      final evidence = File(
        '${Directory.systemTemp.path}/eval2-saved-booking.pdf',
      );
      await evidence.writeAsBytes(pdf);
      await File(
        '${Directory.systemTemp.path}/eval2-saved-booking.json',
      ).writeAsString(
        jsonEncode({
          'id': confirmation.id,
          'title': confirmation.title,
          'buyer': confirmation.buyerName,
          'seller': confirmation.sellerName,
          'total': confirmation.total,
          'pickupSpot': confirmation.pickupSpot,
          'paymentReference': confirmation.paymentReference,
          'paymentStatus': confirmation.paymentStatus,
          'createdAtEpochMs': confirmation.createdAt.millisecondsSinceEpoch,
          'pickupAtEpochMs': confirmation.pickupAt.millisecondsSinceEpoch,
          'timeZoneOffsetMinutes':
              confirmation.createdAt.timeZoneOffset.inMinutes,
        }),
      );
      debugPrint('EVAL2_PDF_PATH ${evidence.path}');
      await scope.market.updateBooking(confirmation, 'cancelled');
      await scope.auth.logout();
      await scope.auth.login(
        '${sellerRoll.toLowerCase()}@cb.students.edu',
        password,
      );
      await scope.market.archiveListing(
        Listing.fromDoc(await db.collection('listings').doc(itemId).get()),
      );
      await scope.auth.logout();
    });
    await waitFor(find.byType(AuthScreen));
    // A real wrong-password response, followed by a valid login and logout.
    await tester.runAsync(() async {
      await expectLater(
        scope.auth.login(
          '${buyerRoll.toLowerCase()}@cb.students.edu',
          'wrong-password',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
      await scope.auth.login(
        '${buyerRoll.toLowerCase()}@cb.students.edu',
        password,
      );
    });
    await waitFor(find.byType(ShellScreen));
    await tester.runAsync(scope.auth.logout);
    await waitFor(find.byType(AuthScreen));
    expect(tester.takeException(), isNull);
  });
}
