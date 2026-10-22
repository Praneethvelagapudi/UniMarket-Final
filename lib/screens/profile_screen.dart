import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/logout_dialog.dart';
import 'item_screen.dart';
import 'upload_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ProfileScreen({super.key, required this.profile});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).market.myListings();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your campus corner',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person_outline, size: 32),
                ),
                const SizedBox(height: 16),
                Text(p['name'], style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(p['roll']),
                SelectableText(p['email']),
                const SizedBox(height: 12),
                StatusPill('${p['department']} · CB campus'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: app.settings,
          builder: (context, _) => Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark appearance'),
                  subtitle: const Text(
                    'A comfortable view for evening browsing',
                  ),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: app.settings.dark,
                  onChanged: app.settings.setDark,
                ),
                SwitchListTile(
                  title: const Text('Message & booking notifications'),
                  subtitle: const Text(
                    'Incoming message previews and booking alerts while the app runs',
                  ),
                  secondary: const Icon(Icons.notifications_outlined),
                  value: app.settings.notifications,
                  onChanged: (v) async {
                    try {
                      // Apply the user's preview preference immediately. A
                      // delayed OS prompt must not overwrite a later toggle.
                      await app.settings.setNotifications(v);
                      if (v && NotificationService.supported) {
                        final allowed = await app.notifications
                            .requestPermission();
                        if (!allowed) {
                          if (context.mounted && app.settings.notifications) {
                            showNotice(
                              context,
                              'In-app alerts are enabled. Allow notifications in device or browser settings for system alerts.',
                            );
                          }
                        }
                      }
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        if (NotificationService.supported)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final allowed = await app.notifications.requestPermission();
                  if (allowed) {
                    final delivered = await app.notifications.show(
                      'demo',
                      'UniMarket notification check',
                      'Device notifications are working. Your booking confirmations will appear here.',
                    );
                    if (!delivered && context.mounted) {
                      showNotice(
                        context,
                        'The booking alert could not be shown. Enable the Booking confirmations channel in device settings.',
                      );
                    }
                  } else if (context.mounted) {
                    showNotice(
                      context,
                      'Allow notifications in device or browser settings.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test device notification'),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your listings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) return ErrorState(error: snapshot.error!);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!.docs.map(Listing.fromDoc).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nothing listed yet',
                body: 'Pass on a book or lab kit you no longer need.',
              );
            }
            return Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          title: Text(item.title),
                          subtitle: Text('${item.department} · ${item.status}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemScreen(id: item.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => confirmLogout(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 20),
        const Text(
          'UniMarket · Campus peer-to-peer buy & rent\nStudent email and roll-number format checks are used. Inbox verification is disabled for this project.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
