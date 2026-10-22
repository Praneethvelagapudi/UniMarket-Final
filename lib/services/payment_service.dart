import 'package:cloud_firestore/cloud_firestore.dart';
import 'market_service.dart';

/// Explicit local simulation adapter. Firestore authorizes the buyer and guards
/// transitions/idempotency; this never represents gateway-verified real money.
class MockPaymentService {
  final MarketService market;
  MockPaymentService(this.market);
  static const outcomes = ['succeeded', 'failed', 'cancelled', 'pending'];
  Future<String> begin(String bookingId) async {
    final userId = market.uid;
    final ref = market.db.collection('bookings').doc(bookingId);
    final newId = market.db.collection('payment-attempt-ids').doc().id;
    return market.db
        .runTransaction<String>((tx) async {
          final data = (await tx.get(ref)).data();
          _validate(data, userId);
          if (data!['paymentStatus'] == 'succeeded') {
            throw StateError('This test payment has already succeeded.');
          }
          if (data['paymentStatus'] == 'pending' &&
              (data['paymentAttemptId'] as String).isNotEmpty) {
            return data['paymentAttemptId'] as String;
          }
          tx.update(ref, {
            'paymentStatus': 'pending',
            'paymentAttemptId': newId,
            'paymentReference': '',
            'paymentUpdatedAt': FieldValue.serverTimestamp(),
          });
          return newId;
        })
        .timeout(const Duration(seconds: 20));
  }

  Future<void> finish(
    String bookingId,
    String attemptId,
    String outcome,
  ) async {
    if (!outcomes.contains(outcome)) {
      throw ArgumentError('Invalid simulated payment outcome.');
    }
    if (outcome == 'pending') {
      return; // A pending attempt can be resumed safely.
    }
    final userId = market.uid;
    final ref = market.db.collection('bookings').doc(bookingId);
    await market.db
        .runTransaction((tx) async {
          final data = (await tx.get(ref)).data();
          _validate(data, userId);
          if (data!['paymentAttemptId'] != attemptId) {
            throw StateError(
              'This payment attempt has changed. Reload the booking.',
            );
          }
          if (data['paymentStatus'] == outcome) return;
          if (data['paymentStatus'] != 'pending') {
            throw StateError('This test payment has already finished.');
          }
          tx.update(ref, {
            'paymentStatus': outcome,
            'paymentReference': outcome == 'succeeded'
                ? 'mock_${bookingId}_$attemptId'
                : '',
            'paymentUpdatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  static void _validate(Map<String, dynamic>? data, String uid) {
    if (data == null ||
        data['buyerId'] != uid ||
        data['status'] != 'confirmed' ||
        data['paymentMethod'] != 'mock') {
      throw StateError(
        'Only the buyer can simulate payment for an active test reservation.',
      );
    }
  }
}
