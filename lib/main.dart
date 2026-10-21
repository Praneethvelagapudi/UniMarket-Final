import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/firebase_config.dart';
import 'services/auth_service.dart';
import 'services/market_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  final settings = AppSettings(await SharedPreferences.getInstance());
  if (!FirebaseConfig.configured) {
    runApp(
      UniMarketApp(
        settings: settings,
        startupError: 'Firebase has not been configured for this build.',
      ),
    );
    return;
  }
  try {
    const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    if (useEmulators) {
      if (kReleaseMode) {
        throw StateError('Emulators are only supported in development builds.');
      }
    }
    final firebaseApp = await Firebase.initializeApp(
      name: useEmulators ? 'local-demo' : null,
      options: FirebaseConfig.options,
    );
    final auth = FirebaseAuth.instanceFor(app: firebaseApp);
    final db = FirebaseFirestore.instanceFor(app: firebaseApp);
    if (useEmulators) {
      await auth.useAuthEmulator(emulatorHost, 9099);
      db.useFirestoreEmulator(emulatorHost, 8080);
    }
    if (kIsWeb) await auth.setPersistence(Persistence.LOCAL);
    db.settings = const Settings(persistenceEnabled: true);
    runApp(
      AppScope(
        auth: AuthService(auth, db),
        market: MarketService(db, auth),
        notifications: NotificationService(),
        settings: settings,
        child: UniMarketApp(settings: settings),
      ),
    );
  } catch (e) {
    runApp(
      UniMarketApp(
        settings: settings,
        startupError:
            'Firebase could not be started. Check the app configuration and connection.',
      ),
    );
  }
}
