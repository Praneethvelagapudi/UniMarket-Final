import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimarket/models/models.dart';
import 'package:unimarket/services/invoice_service.dart';

Booking fixture({
  String status = 'confirmed',
  String method = 'handover',
  String payment = 'unpaid',
}) => Booking(
  id: 'EVAL2-TEST-DOCUMENT',
  listingId: 'fixture',
  title: 'Scientific calculator - QA fixture',
  buyerId: 'buyer',
  sellerId: 'seller',
  buyerName: 'QA Buyer (test fixture)',
  sellerName: 'QA Seller (test fixture)',
  mode: 'rent',
  status: status,
  pickupSpot: 'Campus library entrance',
  pickupAt: DateTime(2026, 10, 21, 12),
  startAt: DateTime(2026, 10, 21),
  endAt: DateTime(2026, 10, 24),
  createdAt: DateTime(2026, 10, 20, 10, 30),
  total: 59.97,
  days: 3,
  paymentMethod: method,
  paymentStatus: payment,
  paymentReference: payment == 'succeeded'
      ? 'mock_EVAL2-TEST-DOCUMENT_test-attempt'
      : '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'confirmation eligibility distinguishes reservation, simulation and cancellation',
    () {
      expect(fixture().invoiceAvailable, isTrue);
      expect(
        fixture(method: 'mock', payment: 'succeeded').invoiceAvailable,
        isTrue,
      );
      for (final payment in ['pending', 'failed', 'cancelled']) {
        expect(
          fixture(method: 'mock', payment: payment).invoiceAvailable,
          isFalse,
        );
      }
      expect(fixture(status: 'cancelled').invoiceAvailable, isFalse);
      expect(fixture(status: 'unknown').invoiceAvailable, isFalse);
      expect(fixture(status: 'completed').invoiceAvailable, isTrue);
    },
  );
  test('Indian currency, safe filename and unpaid labels are truthful', () {
    expect(InvoiceService.currency(123456.7), '₹1,23,456.70');
    expect(
      InvoiceService.filename(fixture()),
      'UniMarket-EVAL2-TEST-DOCUMENT.pdf',
    );
    expect(fixture().paymentLabel, contains('payment not recorded'));
    expect(
      fixture(method: 'mock', payment: 'succeeded').paymentLabel,
      contains('no money moved'),
    );
  });
  test(
    'generates a valid PDF using bundled fonts for actual booking fields',
    () async {
      for (final simulated in [false, true]) {
        final b = fixture(
          method: simulated ? 'mock' : 'handover',
          payment: simulated ? 'succeeded' : 'unpaid',
        );
        final bytes = await InvoiceService.generate(b);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(5000));
        if (const bool.fromEnvironment('EVAL2_WRITE_EVIDENCE')) {
          final dir = Directory('output/evaluation2');
          await dir.create(recursive: true);
          await File(
            '${dir.path}/invoice-${simulated ? 'simulation' : 'handover'}-QA.pdf',
          ).writeAsBytes(bytes);
        }
      }
    },
  );
  test(
    'pending, failed and cancelled bookings cannot generate successful PDFs',
    () async {
      await expectLater(
        InvoiceService.generate(fixture(method: 'mock', payment: 'pending')),
        throwsStateError,
      );
      await expectLater(
        InvoiceService.generate(fixture(method: 'mock', payment: 'failed')),
        throwsStateError,
      );
      await expectLater(
        InvoiceService.generate(fixture(status: 'cancelled')),
        throwsStateError,
      );
    },
  );
}
