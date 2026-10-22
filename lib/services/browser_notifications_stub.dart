bool get browserNotificationsSupported => false;
Future<bool> requestBrowserNotificationPermission() async => false;
Future<bool> showBrowserNotification(
  String id,
  String title,
  String body,
) async => false;
void clearBrowserNotifications() {}
