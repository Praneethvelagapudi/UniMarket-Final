import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'browser_notifications_stub.dart'
    if (dart.library.js_interop) 'browser_notifications_web.dart'
    as browser;

/// Local device/browser alerts while the app is running; no server push claim.
class NotificationService {
  static const _channel = MethodChannel('unimarket/notifications');
  static bool get supported => kIsWeb
      ? browser.browserNotificationsSupported
      : defaultTargetPlatform == TargetPlatform.android;
  Future<bool> requestPermission() async {
    if (!supported) return false;
    // An ignored browser/OS prompt must not hold a saved booking's receipt.
    final request = kIsWeb
        ? browser.requestBrowserNotificationPermission()
        : _channel
              .invokeMethod<bool>('requestPermission')
              .then((value) => value ?? false);
    return request.timeout(const Duration(seconds: 15), onTimeout: () => false);
  }

  Future<bool> show(String id, String title, String body) async {
    if (!supported) return false;
    if (kIsWeb) return browser.showBrowserNotification(id, title, body);
    return await _channel.invokeMethod<bool>('show', {
          'id': id,
          'title': title,
          'body': body,
        }) ??
        false;
  }

  Future<void> clear() async {
    if (kIsWeb) {
      browser.clearBrowserNotifications();
    } else if (supported) {
      await _channel.invokeMethod<void>('clear');
    }
  }
}
