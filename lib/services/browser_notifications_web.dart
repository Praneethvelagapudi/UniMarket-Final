import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

final _shown = <String, web.Notification>{};
bool get browserNotificationsSupported =>
    web.window.isSecureContext && web.window.has('Notification');
Future<bool> requestBrowserNotificationPermission() async {
  if (!browserNotificationsSupported) return false;
  return (await web.Notification.requestPermission().toDart).toDart ==
      'granted';
}

Future<bool> showBrowserNotification(
  String id,
  String title,
  String body,
) async {
  if (!browserNotificationsSupported ||
      web.Notification.permission != 'granted') {
    return false;
  }
  try {
    _shown.remove(id)?.close();
    final notification = web.Notification(
      title,
      web.NotificationOptions(body: body, tag: id),
    );
    _shown[id] = notification;
    // Keep native references bounded during long sessions.
    if (_shown.length > 40) _shown.remove(_shown.keys.first)?.close();
    return true;
  } catch (_) {
    return false;
  }
}

void clearBrowserNotifications() {
  for (final notification in _shown.values) {
    notification.close();
  }
  _shown.clear();
}
