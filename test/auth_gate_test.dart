import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/app.dart';
import 'package:unimarket/screens/auth_screen.dart';
import 'package:unimarket/screens/shell_screen.dart';
import 'package:unimarket/services/auth_service.dart';
import 'package:unimarket/services/market_service.dart';
import 'package:unimarket/services/notification_service.dart';

class TestUser extends Fake implements User {
  @override
  final String uid;
  TestUser(this.uid);
}

class TestAuth extends Fake implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast();
  @override
  Stream<User?> authStateChanges() => changes.stream;
}

class TestDatabase extends Fake implements FirebaseFirestore {}

class TestMetadata extends Fake implements SnapshotMetadata {
  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;
  TestMetadata(this.hasPendingWrites, this.isFromCache);
}

// Controlled test fixture for pending-write metadata; production uses SDK snapshots.
// ignore: subtype_of_sealed_class
class TestProfile extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => true;
  @override
  final SnapshotMetadata metadata;
  TestProfile({bool pending = false, bool cached = false})
    : metadata = TestMetadata(pending, cached);
  @override
  Map<String, dynamic> data() => {
    'name': 'Campus Student',
    'roll': 'CB.SC.U4CSE24157',
    'email': 'cb.sc.u4cse24157@cb.students.edu',
    'department': 'CSE',
  };
}

class TestAuthService extends AuthService {
  final profiles =
      <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  TestAuthService(TestAuth auth) : super(auth, TestDatabase());
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String uid) =>
      profiles.putIfAbsent(uid, () => StreamController.broadcast()).stream;
}

class TestMarketService extends MarketService {
  int protectedRequests = 0;
  TestMarketService(TestAuth auth) : super(TestDatabase(), auth);
  Stream<QuerySnapshot<Map<String, dynamic>>> request() {
    protectedRequests++;
    return const Stream.empty();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> listings() => request();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> bookmarks() => request();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> bookings() => request();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> conversations() => request();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> myListings() => request();
}

void main() {
  late TestAuth auth;
  late TestAuthService service;
  late TestMarketService market;
  setUp(() {
    auth = TestAuth();
    service = TestAuthService(auth);
    market = TestMarketService(auth);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    await auth.changes.close();
    for (final stream in service.profiles.values) {
      await stream.close();
    }
  });
  Future<void> render(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      AppScope(
        auth: service,
        market: market,
        notifications: NotificationService(),
        settings: settings,
        child: MaterialApp(theme: marketTheme(false), home: const AuthGate()),
      ),
    );
    auth.changes.add(TestUser('first'));
    await tester.pump();
  }

  testWidgets('new profile cannot start protected queries until acknowledged', (
    tester,
  ) async {
    await render(tester);
    service.profiles['first']!.add(TestProfile(pending: true, cached: true));
    await tester.pump();
    expect(find.text('Saving your campus profile…'), findsOneWidget);
    expect(find.byType(ShellScreen), findsNothing);
    expect(market.protectedRequests, 0);

    // A metadata-only acknowledgement must unblock the same profile data.
    service.profiles['first']!.add(TestProfile());
    await tester.pump();
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(market.protectedRequests, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'previously acknowledged cached profile still permits offline use',
    (tester) async {
      await render(tester);
      service.profiles['first']!.add(TestProfile(cached: true));
      await tester.pump();
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(market.protectedRequests, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching accounts clears the previous campus profile', (
    tester,
  ) async {
    await render(tester);
    service.profiles['first']!.add(TestProfile());
    await tester.pump();
    expect(find.byType(ShellScreen), findsOneWidget);
    final requestsBeforeSwitch = market.protectedRequests;

    auth.changes.add(TestUser('second'));
    await tester.pump();
    expect(find.byType(ShellScreen), findsNothing);
    service.profiles['second']!.add(TestProfile(pending: true));
    await tester.pump();
    expect(market.protectedRequests, requestsBeforeSwitch);
    service.profiles['second']!.add(TestProfile());
    await tester.pump();
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(market.protectedRequests, requestsBeforeSwitch + 5);
    expect(tester.takeException(), isNull);
  });
}
