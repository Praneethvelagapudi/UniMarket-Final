import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';

class ItemScreen extends StatefulWidget {
  final String id;
  const ItemScreen({super.key, required this.id});
  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  bool _busy = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _itemStream, _bookmarkStream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final market = AppScope.of(context).market;
    _itemStream ??= market.listing(widget.id);
    _bookmarkStream ??= market.db
        .collection('users')
        .doc(market.uid)
        .collection('bookmarks')
        .doc(widget.id)
        .snapshots();
  }

  Future<void> _chat(Listing item) async {
    setState(() => _busy = true);
    try {
      final id = await AppScope.of(context).market.openConversation(item);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(id: id, title: item.title),
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
    final market = AppScope.of(context).market;
    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _itemStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorState(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Item no longer available',
              body:
                  'The listing was removed. You can browse other campus essentials.',
            );
          }
          final item = Listing.fromDoc(snapshot.data!);
          final owner = item.ownerId == market.uid;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(item.department),
                  StatusPill(item.category),
                  StatusPill(item.status),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text('${item.condition} · Listed by ${item.ownerName}'),
              const SizedBox(height: 24),
              Text(
                'About this item',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(item.description),
              const SizedBox(height: 28),
              Text(
                'Choose how you need it',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (item.salePrice > 0)
                _PriceRow(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Buy outright',
                  price: money(item.salePrice),
                ),
              if (item.dailyRate > 0)
                _PriceRow(
                  icon: Icons.event_available_outlined,
                  label: 'Rent per day',
                  price: money(item.dailyRate),
                ),
              const SizedBox(height: 12),
              const Text(
                'Reserve here, then arrange payment and handover with the seller on campus.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              if (owner) ...[
                const Text('This is your listing.'),
                const SizedBox(height: 12),
                if (item.available)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final ok = await confirmAction(
                              context,
                              'Archive this listing?',
                              'It will disappear from Discover. Existing bookings remain in history.',
                            );
                            if (!ok || !context.mounted) return;
                            setState(() => _busy = true);
                            try {
                              await market.archiveListing(item);
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive listing'),
                  ),
              ] else ...[
                if (!item.available)
                  const Text('This item is currently unavailable.'),
                if (item.available)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (item.salePrice > 0)
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BookingScreen(item: item, mode: 'buy'),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('Reserve to buy'),
                        ),
                      if (item.dailyRate > 0)
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BookingScreen(item: item, mode: 'rent'),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Book a rental'),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                BusyButton(
                  busy: _busy,
                  onPressed: () => _chat(item),
                  label: 'Chat with seller',
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ],
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _bookmarkStream,
                builder: (context, saved) {
                  final exists = saved.data?.exists ?? false;
                  return OutlinedButton.icon(
                    onPressed: !saved.hasData || _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await market.saveBookmark(item, exists);
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: Icon(
                      exists
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                    label: Text(
                      exists ? 'Remove from saved' : 'Save for later',
                    ),
                  );
                },
              ),
            ],
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (context, size) {
                    final image = ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: ItemImage(
                        url: item.imageUrl,
                        category: item.category,
                        height: size.maxWidth < 750 ? 280 : 440,
                      ),
                    );
                    return size.maxWidth >= 750
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: image),
                              const SizedBox(width: 40),
                              Expanded(child: details),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              image,
                              const SizedBox(height: 28),
                              details,
                            ],
                          );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final IconData icon;
  final String label, price;
  const _PriceRow({
    required this.icon,
    required this.label,
    required this.price,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(price, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
}
