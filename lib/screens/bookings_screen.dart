import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String _filter = 'Active';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).market.bookings();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      final bookings =
          (snapshot.data?.docs ?? [])
              .map(Booking.fromDoc)
              .where(
                (b) =>
                    _filter == 'All' ||
                    (_filter == 'Active'
                        ? b.status == 'confirmed'
                        : b.status != 'confirmed'),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your campus plans',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Track purchases, rentals, pickups, and returns.'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: ['Active', 'Past', 'All']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v),
                    selected: v == _filter,
                    onSelected: (_) => setState(() => _filter = v),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          CacheBanner(cached: snapshot.data?.metadata.isFromCache ?? false),
          if (snapshot.hasError)
            ErrorState(error: snapshot.error!)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (bookings.isEmpty)
            const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No bookings here yet',
              body:
                  'Reserve an item from Discover and your pickup plan will appear here.',
            )
          else
            ...bookings.map((b) {
              final seller = b.sellerId == AppScope.of(context).market.uid;
              final overdue =
                  b.mode == 'rent' &&
                  b.status == 'confirmed' &&
                  b.endAt.isBefore(DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Icon(
                      b.mode == 'rent'
                          ? Icons.event_available_outlined
                          : Icons.shopping_bag_outlined,
                    ),
                    title: Text(b.title),
                    subtitle: Text(
                      '${seller ? 'You are the seller' : 'From ${b.sellerName}'}\n${displayTime(b.pickupAt)} · ${b.pickupSpot}\n${money(b.total)} · ${overdue ? 'Return overdue' : b.status}${b.simulated ? ' · test payment ${b.paymentStatus}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingReceiptScreen(id: b.id),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      );
    },
  );
}
