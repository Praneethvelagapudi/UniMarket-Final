import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/market_service.dart';
import 'services/notification_service.dart';
import 'services/message_center.dart';
import 'screens/auth_screen.dart';

class AppSettings extends ChangeNotifier {
  final SharedPreferences prefs;
  AppSettings(this.prefs);
  bool get dark => prefs.getBool('dark') ?? false;
  bool get notifications => prefs.getBool('notifications') ?? true;
  Future<void> setDark(bool value) async {
    await prefs.setBool('dark', value);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    await prefs.setBool('notifications', value);
    notifyListeners();
  }
}

class AppScope extends InheritedWidget {
  final AuthService auth;
  final MarketService market;
  final NotificationService notifications;
  final AppSettings settings;
  const AppScope({
    super.key,
    required super.child,
    required this.auth,
    required this.market,
    required this.notifications,
    required this.settings,
  });
  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;
  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

ThemeData marketTheme(bool dark) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF16705B),
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101B18)
        : const Color(0xFFF6F7F2),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -.8,
      ),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ),
  );
}

class UniMarketApp extends StatelessWidget {
  final AppSettings settings;
  final String? startupError;
  const UniMarketApp({super.key, required this.settings, this.startupError});
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return StreamBuilder<User?>(
      stream: startupError == null ? scope?.auth.auth.authStateChanges() : null,
      initialData: scope?.auth.auth.currentUser,
      builder: (context, session) => AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          // Replacing this Navigator on sign-out/account switch removes every
          // protected route, including dialogs and pushed chat/receipt screens.
          key: ValueKey('session-${session.data?.uid ?? 'signed-out'}'),
          builder: (context, child) => scope != null && session.data != null
              ? MessageHost(key: ValueKey(session.data!.uid), child: child!)
              : child!,
          title: 'UniMarket',
          debugShowCheckedModeBanner: false,
          theme: marketTheme(false),
          darkTheme: marketTheme(true),
          themeMode: settings.dark ? ThemeMode.dark : ThemeMode.light,
          home: startupError == null
              ? const AuthGate()
              : SetupScreen(message: startupError!),
        ),
      ),
    );
  }
}

class SetupScreen extends StatelessWidget {
  final String message;
  const SetupScreen({super.key, required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 52,
                    color: Color(0xFF16705B),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'UniMarket',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text('Campus essentials. Shared by students.'),
                  const SizedBox(height: 24),
                  Text(message),
                  const SizedBox(height: 20),
                  const Text(
                    'Please contact the project team to connect this build to Firebase.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
