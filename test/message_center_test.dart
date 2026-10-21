import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimarket/services/market_service.dart';
import 'package:unimarket/services/message_center.dart';
import 'auth_gate_test.dart' as fixtures;
import 'logout_test.dart' show SessionAuth;

// Test snapshots control server/cache events independently of UI rendering.
// ignore: subtype_of_sealed_class
class ChatDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> values;
  ChatDoc(this.id, this.values);
  @override
  Map<String, dynamic> data() => values;
}

// ignore: subtype_of_sealed_class
class ChatSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<ChatDoc> docs;
  @override
  final SnapshotMetadata metadata;
  ChatSnapshot(this.docs, {bool cached = false})
    : metadata = fixtures.TestMetadata(false, cached);
}

// ignore: subtype_of_sealed_class
class ReadSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Timestamp? at;
  ReadSnapshot(this.at);
  @override
  Map<String, dynamic>? data() => at == null ? null : {'readAt': at};
}

class ControlledMarket extends MarketService {
  final chats =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  final messageStreams =
      <String, StreamController<QuerySnapshot<Map<String, dynamic>>>>{};
  final readStreams =
      <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  final reads = <String, Timestamp>{};
  ControlledMarket(SessionAuth auth) : super(fixtures.TestDatabase(), auth);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> conversations() => chats.stream;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String id) =>
      messageStreams.putIfAbsent(id, () => StreamController.broadcast()).stream;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> readReceipt(String id) =>
      readStreams.putIfAbsent(id, () => StreamController.broadcast()).stream;
  @override
  Future<void> markConversationRead(String id, Timestamp at) async {
    reads[id] = at;
    readStreams[id]!.add(ReadSnapshot(at));
  }

  Future<void> close() async {
    await chats.close();
    for (final s in messageStreams.values) {
      await s.close();
    }
    for (final s in readStreams.values) {
      await s.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControlledMarket market;
  late MessageCenter center;
  late SessionAuth auth;
  late List<IncomingMessage> alerts;
  ChatDoc chat(String id) => ChatDoc(id, {
    'buyerId': 'buyer',
    'sellerId': 'seller',
    'buyerName': 'Buyer',
    'sellerName': 'Seller',
    'title': 'Calculator',
  });
  ChatDoc message(String id, String sender, int second, {bool audio = false}) =>
      ChatDoc(id, {
        'senderId': sender,
        'createdAt': Timestamp(second, 0),
        if (audio) 'type': 'audio',
        'text': 'Hello from $sender',
      });
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    auth = SessionAuth()..user = fixtures.TestUser('buyer');
    market = ControlledMarket(auth);
    alerts = [];
    center = MessageCenter(market, alerts.add);
  });
  tearDown(() async {
    center.dispose();
    await market.close();
    await auth.changes.close();
  });
  Future<void> baseline() async {
    market.chats.add(ChatSnapshot([chat('chat')]));
    await flush();
    market.readStreams['chat']!.add(ReadSnapshot(null));
    market.messageStreams['chat']!.add(
      ChatSnapshot([message('old', 'seller', 1)]),
    );
    await flush();
  }

  test(
    'historical messages count as unread without replaying old alerts',
    () async {
      await baseline();
      expect(center.unread('chat'), 1);
      expect(alerts, isEmpty);
      expect(center.senderName('chat', 'seller'), 'Seller');
    },
  );
  test(
    'recipient receives one alert; own sends and repeated snapshots do not alert',
    () async {
      await baseline();
      final docs = [
        message('old', 'seller', 1),
        message('own', 'buyer', 2),
        message('new', 'seller', 3, audio: true),
      ];
      market.messageStreams['chat']!.add(ChatSnapshot(docs));
      await flush();
      market.messageStreams['chat']!.add(ChatSnapshot(docs));
      await flush();
      expect(alerts.length, 1);
      expect(alerts.single.sender, 'Seller');
      expect(alerts.single.preview, 'Voice message');
      expect(center.totalUnread, 2);
    },
  );
  test(
    'opening a chat persists read state and suppresses alerts until backgrounded',
    () async {
      await baseline();
      center.setActive('chat');
      await flush();
      expect(center.totalUnread, 0);
      expect(market.reads['chat'], Timestamp(1, 0));
      market.messageStreams['chat']!.add(
        ChatSnapshot([
          message('old', 'seller', 1),
          message('visible', 'seller', 2),
        ]),
      );
      await flush();
      expect(alerts, isEmpty);
      expect(center.totalUnread, 0);
      center.didChangeAppLifecycleState(AppLifecycleState.paused);
      market.messageStreams['chat']!.add(
        ChatSnapshot([
          message('old', 'seller', 1),
          message('visible', 'seller', 2),
          message('background', 'seller', 3),
        ]),
      );
      await flush();
      expect(alerts.length, 1);
      expect(center.totalUnread, 1);
      center.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(center.totalUnread, 0);
    },
  );
  test(
    'a new conversation after startup can alert on its first message',
    () async {
      await baseline();
      market.chats.add(ChatSnapshot([chat('chat'), chat('new-chat')]));
      await flush();
      market.readStreams['new-chat']!.add(ReadSnapshot(null));
      market.messageStreams['new-chat']!.add(
        ChatSnapshot([message('first', 'seller', 5)]),
      );
      await flush();
      expect(alerts.length, 1);
      expect(alerts.single.conversationId, 'new-chat');
    },
  );
  test('cache replays do not emit new device alerts', () async {
    await baseline();
    market.messageStreams['chat']!.add(
      ChatSnapshot([message('cache', 'seller', 2)], cached: true),
    );
    await flush();
    expect(alerts, isEmpty);
  });
}
