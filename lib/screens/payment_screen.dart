import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/models.dart';
import '../services/payment_service.dart';
import '../services/invoice_service.dart';
import '../widgets/common.dart';

class PaymentScreen extends StatefulWidget {
  final String id;
  const PaymentScreen({super.key, required this.id});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _busy = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).market.booking(widget.id);
  }

  Future<void> _pay() async {
    if (_busy) return;
    final app = AppScope.of(context);
    final payments = MockPaymentService(app.market);
    setState(() => _busy = true);
    try {
      final attempt = await payments.begin(widget.id);
      final saved = Booking.fromDoc(
        await app.market.db
            .collection('bookings')
            .doc(widget.id)
            .get(const GetOptions(source: Source.server)),
      );
      if (!mounted) return;
      final outcome =
          await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Local payment simulation'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saved.title),
                    const SizedBox(height: 8),
                    Text(
                      'Test amount: ${InvoiceService.currency(saved.total)}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Razorpay checkout is connected. No money will move. Choose a test outcome to demonstrate the flow.',
                    ),
                    const SizedBox(height: 16),
                    for (final entry in const {
                      'succeeded': 'Simulate success',
                      'failed': 'Simulate failure',
                      'cancelled': 'Cancel payment',
                      'pending': 'Leave pending',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, entry.key),
                            child: Text(entry.value),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ) ??
          'cancelled';
      await payments.finish(widget.id, attempt, outcome);
      // A callback/dialog result alone never produces a confirmation. Verify
      // the committed database record before presenting success or exporting.
      final verified = Booking.fromDoc(
        await app.market.db
            .collection('bookings')
            .doc(widget.id)
            .get(const GetOptions(source: Source.server)),
      );
      if (verified.paymentStatus != outcome) {
        throw StateError(
          'Payment state changed. Reopen the booking to check the saved result.',
        );
      }
      if (!mounted) return;
      if (outcome == 'succeeded') {
        String notice = 'Test payment saved. No money moved.';
        if (app.settings.notifications) {
          try {
            if (await app.notifications.requestPermission()) {
              final delivered = await app.notifications.show(
                verified.id,
                'Booking confirmed · test payment',
                '${verified.title} · ${verified.pickupSpot} · simulation only',
              );
              if (!delivered) notice += ' Device notification unavailable.';
            }
          } catch (_) {
            notice += ' Device notification unavailable.';
          }
        }
        if (mounted) {
          showNotice(context, notice);
        }
      } else {
        showNotice(
          context,
          outcome == 'pending'
              ? 'Test payment remains pending. You can resume it from this booking.'
              : outcome == 'failed'
              ? 'Test payment failed. Your reservation is held; retry or cancel it.'
              : 'Test payment cancelled. Retry or cancel the reservation.',
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Test payment')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorState(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Booking unavailable',
              body: 'This booking could not be found.',
            );
          }
          final b = Booking.fromDoc(snapshot.data!);
          final canPay =
              b.buyerId == AppScope.of(context).market.uid &&
              b.status == 'confirmed' &&
              b.simulated &&
              b.paymentStatus != 'succeeded';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusPill('SIMULATION · No real charges'),
                    const SizedBox(height: 24),
                    Text(
                      'Order summary',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            SelectableText('Booking: ${b.id}'),
                            Text('Seller: ${b.sellerName}'),
                            Text(
                              b.mode == 'rent'
                                  ? 'Rental · ${b.days} days'
                                  : 'Purchase · 1 item',
                            ),
                            const Divider(height: 32),
                            Text(
                              InvoiceService.currency(b.total),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(b.paymentLabel),
                            if (b.paymentReference.isNotEmpty)
                              SelectableText(b.paymentReference),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'This local mock demonstrates success, failure, cancellation and pending states. It does not collect payment credentials or contact Razorpay.',
                    ),
                    const SizedBox(height: 20),
                    CacheBanner(cached: snapshot.data!.metadata.isFromCache),
                    if (b.paymentStatus == 'succeeded')
                      FilledButton.icon(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('View booking receipt'),
                      ),
                    if (canPay)
                      SizedBox(
                        width: double.infinity,
                        child: BusyButton(
                          busy: _busy,
                          onPressed: _pay,
                          label:
                              b.paymentStatus == 'pending' &&
                                  b.paymentAttemptId.isNotEmpty
                              ? 'Resume test payment'
                              : b.paymentStatus == 'pending'
                              ? 'Pay Now (simulation)'
                              : 'Retry test payment',
                          icon: Icons.payment,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
