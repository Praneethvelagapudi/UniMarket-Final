import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import 'market_service.dart';

class InvoiceService {
  static String filename(Booking b) =>
      'UniMarket-${b.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
  static String currency(num amount) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(amount);
  static String date(DateTime value) =>
      DateFormat('d MMM yyyy, h:mm a').format(value);

  /// Re-read the authorized saved record before issuing a document. Cached or
  /// unacknowledged writes never serve as proof of a completed operation.
  static Future<Booking> loadSaved(MarketService market, String id) async {
    final doc = await market.db
        .collection('bookings')
        .doc(id)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (!doc.exists || doc.metadata.hasPendingWrites) {
      throw StateError(
        'Wait for the booking to be saved before generating a PDF.',
      );
    }
    final booking = Booking.fromDoc(doc);
    if (!booking.invoiceAvailable) {
      throw StateError(
        'A PDF is available after a successful reservation or completed test payment. Cancelled bookings cannot issue confirmations.',
      );
    }
    if (booking.createdAt.millisecondsSinceEpoch <= 0) {
      throw StateError(
        'The booking date has not been confirmed by the server.',
      );
    }
    return booking;
  }

  static Future<Uint8List> generate(Booking b) async {
    if (!b.invoiceAvailable ||
        !b.total.isFinite ||
        b.total <= 0 ||
        b.createdAt.millisecondsSinceEpoch <= 0) {
      throw StateError('This booking cannot issue a confirmation.');
    }
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final green = PdfColor.fromHex('#164D3E');
    final doc = pw.Document(
      title: 'UniMarket booking ${b.id}',
      author: 'UniMarket',
      compress: true,
    );
    pw.Widget field(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 125,
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 15),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'UniMarket | Campus peer-to-peer buy & rent',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Container(
            color: green,
            padding: const pw.EdgeInsets.all(22),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'UniMarket',
                  style: pw.TextStyle(fontSize: 28, color: PdfColors.white),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'BOOKING CONFIRMATION',
                  style: const pw.TextStyle(
                    fontSize: 13,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Campus essentials. Shared by students.',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          if (b.simulated)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: PdfColors.amber100,
              child: pw.Text(
                'TEST PAYMENT SIMULATION - NO MONEY MOVED\nThis is a local demonstration, not a Razorpay payment or proof of funds.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          pw.SizedBox(height: 14),
          field('Booking ID', b.id),
          field('Booked on', date(b.createdAt)),
          field('Booking status', b.status),
          field('Buyer', b.buyerName),
          field('Seller', b.sellerName),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: [
              'Item / service',
              'Quantity / days',
              'Unit price',
              'Amount',
            ],
            data: [
              [
                b.title,
                b.mode == 'rent' ? '${b.days} days' : '1 item',
                currency(b.total / (b.mode == 'rent' ? b.days : 1)),
                currency(b.total),
              ],
            ],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: green),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellPadding: const pw.EdgeInsets.all(10),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.6),
            },
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 14),
          field('Subtotal', currency(b.total)),
          field('Total (INR)', currency(b.total)),
          pw.Text(
            'No additional charges or discounts are recorded for this booking.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          field(
            'Transaction type',
            b.mode == 'rent' ? 'Rental reservation' : 'Purchase reservation',
          ),
          if (b.mode == 'rent')
            field(
              'Rental period',
              '${DateFormat('d MMM yyyy').format(b.startAt)} to ${DateFormat('d MMM yyyy').format(b.endAt)} (return date excluded)',
            ),
          field('Campus pickup', date(b.pickupAt)),
          field('Pickup location', b.pickupSpot),
          field(
            'Payment method',
            b.simulated
                ? 'Local mock adapter (simulation)'
                : 'Direct payment at handover',
          ),
          field('Payment status', b.paymentLabel),
          if (b.paymentReference.isNotEmpty)
            field('Test reference', b.paymentReference),
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            b.simulated
                ? 'This document confirms the saved reservation and simulated payment state only. Any real settlement remains between buyer and seller.'
                : 'This document confirms a reservation. Payment has not been collected or verified by UniMarket. Arrange settlement directly with the seller.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'This is a booking confirmation, not a tax invoice. Times use the issuing device local timezone (${b.createdAt.timeZoneName}).',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
