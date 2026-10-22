import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'item_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final bool savedOnly;
  const MarketplaceScreen({super.key, this.savedOnly = false});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _query = '', _department = 'All', _category = 'All', _mode = 'All';
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= widget.savedOnly
        ? AppScope.of(context).market.bookmarks()
        : AppScope.of(context).market.listings();
  }

  void _open(String id) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ItemScreen(id: id)),
  );
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      final departments =
          {
            'All',
            ...docs
                .map((d) => d.data()['department'] as String? ?? '')
                .where((v) => v.isNotEmpty),
          }.toList()..sort(
            (a, b) => a == 'All'
                ? -1
                : b == 'All'
                ? 1
                : a.compareTo(b),
          );
      final filtered = docs.where((d) {
        final data = d.data();
        return ('${data['title']} ${data['category']} ${data['description'] ?? ''}'
                .toLowerCase()
                .contains(_query.toLowerCase())) &&
            (_department == 'All' || data['department'] == _department) &&
            (_category == 'All' || data['category'] == _category) &&
            (_mode == 'All' ||
                ((_mode == 'Buy' ? data['salePrice'] : data['dailyRate'])
                            as num? ??
                        0) >
                    0);
      }).toList();
      filtered.sort(
        (a, b) =>
            dateValue(
              b.data()[widget.savedOnly ? 'savedAt' : 'createdAt'],
            ).compareTo(
              dateValue(a.data()[widget.savedOnly ? 'savedAt' : 'createdAt']),
            ),
      );
      return LayoutBuilder(
        builder: (context, size) {
          final columns = size.maxWidth >= 1200
              ? 4
              : size.maxWidth >= 700
              ? 3
              : 2;
          final padding = size.maxWidth < 500 ? 16.0 : 32.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.savedOnly
                            ? 'Your saved finds'
                            : 'Good finds.\nBetter campus prices.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.savedOnly
                            ? 'Bookmarked essentials, ready when you are.'
                            : 'Academic essentials passed from one student to the next.',
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search textbooks, lab kits, calculators…',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: departments
                            .map(
                              (v) => ChoiceChip(
                                label: Text(v),
                                selected: _department == v,
                                onSelected: (_) =>
                                    setState(() => _department = v),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              items:
                                  [
                                        'All',
                                        'Books',
                                        'Electronics',
                                        'Lab equipment',
                                        'Stationery',
                                        'Other',
                                      ]
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(v),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) => setState(() => _category = v!),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _mode,
                              decoration: const InputDecoration(
                                labelText: 'Availability',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              items: ['All', 'Buy', 'Rent']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _mode = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CacheBanner(
                        cached: snapshot.data?.metadata.isFromCache ?? false,
                      ),
                      if (!snapshot.hasError && snapshot.hasData)
                        Text(
                          '${filtered.length} ${widget.savedOnly ? 'saved items' : 'available items'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(error: snapshot.error!),
                )
              else if (!snapshot.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: widget.savedOnly
                        ? Icons.bookmark_border_rounded
                        : Icons.search_off_rounded,
                    title: widget.savedOnly
                        ? 'No saved items yet'
                        : 'No items found',
                    body: widget.savedOnly
                        ? 'Tap the bookmark on an item to keep it here.'
                        : 'Try another filter, or be the first to list a campus essential.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: size.maxWidth < 500 ? 270 : 340,
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final doc = filtered[i];
                      if (widget.savedOnly) {
                        final d = doc.data();
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _open(doc.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ItemImage(
                                    url: d['imageUrl'] ?? '',
                                    category: d['category'] ?? '',
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['title'] ?? 'Saved item',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(d['department'] ?? ''),
                                      const SizedBox(height: 8),
                                      if ((d['salePrice'] as num? ?? 0) > 0)
                                        Text('${money(d['salePrice'])} to buy'),
                                      if ((d['dailyRate'] as num? ?? 0) > 0)
                                        Text('${money(d['dailyRate'])} / day'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final item = Listing.fromDoc(doc);
                      return ListingCard(
                        item: item,
                        onTap: () => _open(item.id),
                      );
                    }, childCount: filtered.length),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
