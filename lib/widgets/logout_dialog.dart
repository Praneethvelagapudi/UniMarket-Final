import 'package:flutter/material.dart';
import '../app.dart';
import '../services/errors.dart';

/// All UI logout entry points share the same confirmation and error handling.
Future<void> confirmLogout(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _LogoutDialog(),
);

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog();
  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _busy = false;
  String? _error;
  Future<void> _logout() async {
    if (_busy) return;
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.auth.logout();
      // Authentication resets the app Navigator, disposing user-owned screens,
      // message subscriptions, controllers and unsent audio. Notification cleanup
      // must never turn a successful sign-out into a reported failure.
      try {
        await app.notifications.clear();
      } catch (_) {}
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('Log out of UniMarket?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'You can sign in again to see your saved items, bookings and conversations.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _logout,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(_busy ? 'Logging out…' : 'Logout'),
        ),
      ],
    ),
  );
}
