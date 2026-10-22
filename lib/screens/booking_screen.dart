import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../services/invoice_service.dart';
import 'invoice_screen.dart';
import 'payment_screen.dart';

String displayDate(DateTime date) => DateFormat('d MMM yyyy').format(date);
String displayTime(DateTime date) =>
    DateFormat('d MMM yyyy, h:mm a').format(date);

class BookingScreen extends StatefulWidget {
  final Listing item;
  final String mode;
  const BookingScreen({super.key, required this.item, required this.mode});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _form = GlobalKey<FormState>();
  final _spot = TextEditingController();
  late DateTime _start, _end, _pickup;
  bool _busy = false;
  bool _simulatePayment = false;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day);
    _end = _start.add(const Duration(days: 1));
    _pickup = now.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _spot.dispose();
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: start ? today : _start.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (start) {
        _start = value;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(days: 1));
        _pickup = DateTime(value.year, value.month, value.day, 12);
      } else {
        _end = value;
      }
    });
  }

  Future<void> _meetup() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _pickup.isBefore(today) ? today : _pickup,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickup),
    );
    if (time != null && mounted) {
      setState(
        () => _pickup = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_pickup.isBefore(DateTime.now())) {
      showNotice(context, 'Choose a future pickup time.');
      return;
    }
    if (widget.mode == 'rent' &&
        (rentalDays(_start, _end) < 1 ||
            rentalDays(_start, _end) > 90 ||
            _pickup.isBefore(_start) ||
            !_pickup.isBefore(_end))) {
      showNotice(
        context,
        'Rent for 1–90 days and choose a pickup time within that period.',
      );
      return;
    }
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      final id = await app.market.createBooking(
        item: widget.item,
        mode: widget.mode,
        start: _start,
        end: _end,
        pickupAt: _pickup,
        pickupSpot: _spot.text,
        simulatePayment: _simulatePayment,
      );
      String? notificationMessage;
      if (!_simulatePayment &&
          app.settings.notifications &&
          NotificationService.supported) {
        try {
          final allowed = await app.notifications.requestPermission();
          if (allowed) {
            final delivered = await app.notifications.show(
              id,
              'Booking confirmed',
              '${widget.item.title} · ${displayTime(_pickup)} · ${_spot.text.trim()}',
            );
            if (!delivered) {
              notificationMessage =
                  'Booking confirmed. Enable booking notifications in Android settings to receive device alerts.';
            }
          } else {
            notificationMessage =
                'Booking confirmed. Device notifications are disabled; enable them in Android settings.';
          }
        } catch (_) {
          notificationMessage =
              'Booking confirmed. The device notification could not be sent.';
        }
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingReceiptScreen(
              id: id,
              confirmation: !_simulatePayment,
              notificationMessage: notificationMessage,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final days = rentalDays(_start, _end);
    final total = widget.mode == 'buy' ? item.salePrice : item.dailyRate * days;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.mode == 'buy' ? 'Reserve to buy' : 'Book a rental',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make it yours.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.title),
                        subtitle: Text('From ${item.ownerName}'),
                        trailing: StatusPill(
                          widget.mode == 'buy' ? 'Buy' : 'Rent',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (widget.mode == 'rent') ...[
                      Text(
                        'Rental period',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _date(true),
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text('Start: ${displayDate(_start)}'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _date(false),
                            icon: const Icon(Icons.event_outlined),
                            label: Text('Return: ${displayDate(_end)}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The return date is excluded. 6–7 Oct = 1 rental day. Maximum 90 days.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Plan your pickup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _spot,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Campus pickup location',
                        hintText: 'Agree on a campus spot with the seller',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (v) => v == null || v.trim().length < 3
                          ? 'Enter a specific pickup location.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _meetup,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(displayTime(_pickup)),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (widget.mode == 'rent')
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${money(item.dailyRate)} × $days ${days == 1 ? 'day' : 'days'}',
                                    ),
                                  ),
                                  Text(money(total)),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total agreed listing price',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  money(total),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Try a test payment'),
                      subtitle: const Text(
                        'Optional local simulation. No money moves. Otherwise pay directly at handover.',
                      ),
                      value: _simulatePayment,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _simulatePayment = value),
                    ),
                    const Text(
                      'Payment is arranged directly at handover. Bargaining in chat does not change this booking price. Confirm any negotiated terms with the seller before reserving.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: BusyButton(
                        busy: _busy,
                        onPressed: _submit,
                        label: _simulatePayment
                            ? 'Reserve & continue to test payment'
                            : 'Confirm reservation',
                        icon: Icons.check_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookingReceiptScreen extends StatefulWidget {
  final String id;
  final bool confirmation;
  final String? notificationMessage;
  const BookingReceiptScreen({
    super.key,
    required this.id,
    this.confirmation = false,
    this.notificationMessage,
  });
  @override
  State<BookingReceiptScreen> createState() => _BookingReceiptScreenState();
}

class _BookingReceiptScreenState extends State<BookingReceiptScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  bool _busy = false;
  Future<void> _invoice() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final booking = await InvoiceService.loadSaved(
        AppScope.of(context).market,
        widget.id,
      );
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoiceScreen(booking: booking)),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).market.booking(widget.id);
  }

  Future<void> _change(Booking booking, String status) async {
    final ok = await confirmAction(
      context,
      status == 'cancelled' ? 'Cancel this booking?' : 'Complete this booking?',
      status == 'cancelled'
          ? 'The item will become available again.'
          : 'For a rental, confirm that the item has been returned. For a sale, confirm handover is complete.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).market.updateBooking(booking, status);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Booking receipt')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorState(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Booking unavailable',
            body: 'This booking could not be found.',
          );
        }
        final b = Booking.fromDoc(snapshot.data!);
        final seller = b.sellerId == AppScope.of(context).market.uid;
        final paymentNeeded =
            b.simulated &&
            b.paymentStatus != 'succeeded' &&
            b.status == 'confirmed';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    b.status == 'confirmed' && !paymentNeeded
                        ? Icons.check_circle_rounded
                        : Icons.event_note_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    paymentNeeded
                        ? 'Test payment required'
                        : b.status == 'confirmed'
                        ? 'You’re all booked.'
                        : b.status == 'cancelled'
                        ? 'Booking cancelled'
                        : 'Booking completed',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(b.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusPill(b.status),
                          const SizedBox(height: 16),
                          _ReceiptRow('Booking ID', b.id),
                          _ReceiptRow(
                            'Type',
                            b.mode == 'rent'
                                ? 'Rental'
                                : 'Purchase reservation',
                          ),
                          _ReceiptRow('Buyer', b.buyerName),
                          _ReceiptRow('Seller', b.sellerName),
                          if (b.mode == 'rent')
                            _ReceiptRow(
                              'Rental period',
                              '${displayDate(b.startAt)} → ${displayDate(b.endAt)} (${b.days} days)',
                            ),
                          _ReceiptRow('Pickup', displayTime(b.pickupAt)),
                          _ReceiptRow('Location', b.pickupSpot),
                          _ReceiptRow('Total', money(b.total)),
                          _ReceiptRow('Payment', b.paymentLabel),
                          if (b.paymentReference.isNotEmpty)
                            _ReceiptRow('Test reference', b.paymentReference),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CacheBanner(cached: snapshot.data!.metadata.isFromCache),
                  if (paymentNeeded) ...[
                    const Text(
                      'Your reservation is held. Complete the simulation to receive its final confirmation and PDF, or cancel the booking.',
                    ),
                    const SizedBox(height: 12),
                    if (!seller)
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(id: b.id),
                                ),
                              ),
                        icon: const Icon(Icons.payment),
                        label: const Text('Continue to test payment'),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (b.invoiceAvailable) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _invoice,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Preview / download confirmation PDF'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.notificationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.notificationMessage!),
                    ),
                  if (b.status == 'confirmed')
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _change(b, 'cancelled'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel booking'),
                        ),
                        if (seller && !paymentNeeded)
                          BusyButton(
                            busy: _busy,
                            onPressed: () => _change(b, 'completed'),
                            label: b.mode == 'rent'
                                ? 'Confirm return'
                                : 'Confirm handover',
                            icon: Icons.check_rounded,
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('Back to campus market'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  const _ReceiptRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
