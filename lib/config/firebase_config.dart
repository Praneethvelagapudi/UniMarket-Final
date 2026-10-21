import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Bundled public Uni-Market identifiers for normal Flutter/VS Code launches.
/// --dart-define-from-file can override these when using another project.
/// Do not place service-account keys or private credentials here.
class FirebaseConfig {
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'uni-market-7ef26',
  );
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyB_towm4VMlpD4JVw8ygNSxPH7GMBZyOLU',
  );
  static const androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyAkzs2dNxhupUV3gkRZXzQ-8XbJ-FCbfaw',
  );
  static const androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:411966556264:android:737a5120629b4eeffe53dd',
  );
  static const webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:411966556264:web:c712ae13474aaa78fe53dd',
  );
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '411966556264',
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'uni-market-7ef26.firebaseapp.com',
  );
  static bool get configured =>
      projectId.isNotEmpty &&
      apiKey.isNotEmpty &&
      senderId.isNotEmpty &&
      (kIsWeb ? webAppId : androidAppId).isNotEmpty;
  static FirebaseOptions get options => FirebaseOptions(
    apiKey: !kIsWeb && androidApiKey.isNotEmpty ? androidApiKey : apiKey,
    appId: kIsWeb ? webAppId : androidAppId,
    messagingSenderId: senderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}
