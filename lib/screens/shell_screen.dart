import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../services/message_center.dart';
import 'marketplace_screen.dart';
import 'bookings_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

class ShellScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ShellScreen({super.key, required this.profile});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  static const _labels = ['Discover', 'Saved', 'Bookings', 'Messages', 'You'];
  static const _icons = [
    Icons.grid_view_rounded,
    Icons.bookmark_border_rounded,
    Icons.calendar_month_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _index = 0);
    },
    child: LayoutBuilder(
      builder: (context, size) {
        final wide = size.maxWidth >= 1000;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Text(
                  'UniMarket',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              if (size.maxWidth > 500)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(child: StatusPill('CB campus')),
                ),
              IconButton(
                tooltip: 'Settings and profile',
                onPressed: () => setState(() => _index = 4),
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (v) => setState(() => _index = v),
                  extended: true,
                  minExtendedWidth: 190,
                  destinations: List.generate(
                    _labels.length,
                    (i) => NavigationRailDestination(
                      icon: _navigationIcon(context, i),
                      label: Text(_labels[i]),
                    ),
                  ),
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    const MarketplaceScreen(),
                    const MarketplaceScreen(savedOnly: true),
                    const BookingsScreen(),
                    const ConversationListScreen(),
                    ProfileScreen(profile: widget.profile),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (v) => setState(() => _index = v),
                  destinations: List.generate(
                    _labels.length,
                    (i) => NavigationDestination(
                      icon: _navigationIcon(context, i),
                      label: _labels[i],
                    ),
                  ),
                ),
          floatingActionButton: _index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('List an item'),
                )
              : null,
        );
      },
    ),
  );
  Widget _navigationIcon(BuildContext context, int i) {
    final count = i == 3 ? MessageScope.maybeOf(context)?.totalUnread ?? 0 : 0;
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(_icons[i]),
    );
  }
}
