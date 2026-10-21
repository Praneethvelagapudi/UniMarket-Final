import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimarket/config/firebase_config.dart';

void main() {
  test(
    'launching without build arguments uses the registered Uni-Market apps',
    () {
      final registered =
          jsonDecode(File('config/firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(FirebaseConfig.configured, isTrue);
      expect(FirebaseConfig.projectId, registered['FIREBASE_PROJECT_ID']);
      expect(FirebaseConfig.webAppId, registered['FIREBASE_WEB_APP_ID']);
      expect(FirebaseConfig.apiKey, registered['FIREBASE_API_KEY']);
      expect(
        FirebaseConfig.options.appId,
        registered['FIREBASE_ANDROID_APP_ID'],
      );
      expect(
        FirebaseConfig.options.apiKey,
        registered['FIREBASE_ANDROID_API_KEY'],
      );
      expect(
        FirebaseConfig.options.messagingSenderId,
        registered['FIREBASE_MESSAGING_SENDER_ID'],
      );
      expect(
        FirebaseConfig.options.authDomain,
        registered['FIREBASE_AUTH_DOMAIN'],
      );
    },
  );
}
