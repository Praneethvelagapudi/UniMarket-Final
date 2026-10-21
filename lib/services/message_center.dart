import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'market_service.dart';
import '../app.dart';
import 'notification_service.dart';

class IncomingMessage {
  final String conversationId, title, sender, preview, messageId;
  const IncomingMessage(
    this.conversationId,
    this.title,
    this.sender,
    this.preview,
    this.messageId,
  );
}

/// Recipient-scoped real-time state. Owned by the authenticated shell so logout
/// disposes all subscriptions and clears previews/unread data from memory.
class MessageCenter extends ChangeNotifier with WidgetsBindingObserver {
  final MarketService market;
  final String userId;
  final void Function(IncomingMessage) onIncoming;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversations;
  final _subscriptions = <String, List<StreamSubscription>>{};
  final _messages =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final _chats = <String, Map<String, dynamic>>{};
  final _readAt = <String, Timestamp?>{};
  final _seen = <String, Set<String>>{};
  final _primed = <String>{};
  final _marking = <String>{};
  final _notifyInitial = <String>{};
  bool _conversationBaseline = false;
  String? activeConversation, error;
  bool _disposed = false;
  bool _foreground = true;
  MessageCenter(this.market, this.onIncoming) : userId = market.uid {
    WidgetsBinding.instance.addObserver(this);
    _conversations = market.conversations().listen((snapshot) {
      if (_disposed) return;
      final ids = snapshot.docs.map((d) => d.id).toSet();
      for (final id in _subscriptions.keys.toList()) {
        if (!ids.contains(id)) {
          for (final s in _subscriptions.remove(id)!) {
            unawaited(s.cancel());
          }
          _chats.remove(id);
          _messages.remove(id);
          _readAt.remove(id);
          _seen.remove(id);
          _primed.remove(id);
        }
      }
      for (final doc in snapshot.docs) {
        _chats[doc.id] = doc.data();
        if (!_subscriptions.containsKey(doc.id)) {
          if (_conversationBaseline && !snapshot.metadata.isFromCache) {
            _notifyInitial.add(doc.id);
          }
          _watch(doc.id);
        }
      }
      if (!snapshot.metadata.isFromCache) _conversationBaseline = true;
      notifyListeners();
    }, onError: _onError);
  }
  void _onError(Object e) {
    if (!_disposed) {
      error =
          'Message updates are unavailable. Check your connection and account access.';
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && activeConversation != null) {
      _markRead(activeConversation!);
    }
  }

  int unread(String id) {
    if (!_readAt.containsKey(id)) return 0;
    return (_messages[id] ?? []).where((doc) {
      final at = doc.data()['createdAt'] as Timestamp?;
      return doc.data()['senderId'] != userId &&
          at != null &&
          (_readAt[id] == null || at.compareTo(_readAt[id]!) > 0);
    }).length;
  }

  int get totalUnread =>
      _messages.keys.fold(0, (total, id) => total + unread(id));
  String senderName(String id, String senderId) {
    final chat = _chats[id];
    if (chat == null) return 'Participant';
    return chat[chat['buyerId'] == senderId ? 'buyerName' : 'sellerName']
            as String? ??
        'Participant';
  }

  String preview(String id) {
    final docs = _messages[id];
    if (docs == null || docs.isEmpty) return '';
    final d = docs.last.data();
    return d['type'] == 'audio' ? 'Voice message' : d['text'] as String? ?? '';
  }

  void setActive(String? id) {
    activeConversation = id;
    if (id != null) _markRead(id);
  }

  void _watch(String id) {
    final reads = market.readReceipt(id).listen((snapshot) {
      if (_disposed) return;
      _readAt[id] = snapshot.data()?['readAt'] as Timestamp?;
      if (activeConversation == id && _foreground) _markRead(id);
      notifyListeners();
    }, onError: _onError);
    final messages = market.messages(id).listen((snapshot) {
      if (_disposed) return;
      error = null;
      _messages[id] = snapshot.docs;
      if (!snapshot.metadata.isFromCache) {
        final seen = _seen.putIfAbsent(id, () => <String>{});
        final newlyArrived = snapshot.docs
            .where((d) => !seen.contains(d.id))
            .toList();
        for (final doc in snapshot.docs) {
          seen.add(doc.id);
        }
        final wasPrimed = _primed.contains(id) || _notifyInitial.remove(id);
        _primed.add(id);
        if (wasPrimed && !(activeConversation == id && _foreground)) {
          for (final doc in newlyArrived) {
            final d = doc.data();
            final at = d['createdAt'] as Timestamp?;
            if (d['senderId'] == userId ||
                at == null ||
                (_readAt[id] != null && at.compareTo(_readAt[id]!) <= 0)) {
              continue;
            }
            final chat = _chats[id]!;
            final sender = chat['buyerId'] == userId
                ? chat['sellerName']
                : chat['buyerName'];
            final text = d['type'] == 'audio'
                ? 'Voice message'
                : d['text'] as String? ?? '';
            onIncoming(
              IncomingMessage(
                id,
                chat['title'],
                sender,
                text.length > 100 ? '${text.substring(0, 100)}…' : text,
                doc.id,
              ),
            );
          }
        }
      }
      if (activeConversation == id && _foreground) _markRead(id);
      notifyListeners();
    }, onError: _onError);
    _subscriptions[id] = [reads, messages];
  }

  void _markRead(String id) {
    if (_disposed || _marking.contains(id) || !_readAt.containsKey(id)) return;
    final incoming = (_messages[id] ?? []).where(
      (d) =>
          d.data()['senderId'] != userId && d.data()['createdAt'] is Timestamp,
    );
    if (incoming.isEmpty) return;
    final last = incoming.last.data()['createdAt'] as Timestamp;
    if (_readAt[id] != null && last.compareTo(_readAt[id]!) <= 0) return;
    _marking.add(id);
    unawaited(
      market
          .markConversationRead(id, last)
          .then(
            (_) {
              _marking.remove(id);
              if (!_disposed &&
                  (_readAt[id] == null || last.compareTo(_readAt[id]!) > 0)) {
                _readAt[id] = last;
                notifyListeners();
              }
              if (!_disposed && activeConversation == id && _foreground) {
                _markRead(id);
              }
            },
            onError: (Object e) {
              _marking.remove(id);
              _onError(e);
            },
          ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _conversations?.cancel();
    for (final list in _subscriptions.values) {
      for (final s in list) {
        s.cancel();
      }
    }
    _subscriptions.clear();
    _messages.clear();
    _chats.clear();
    _readAt.clear();
    _seen.clear();
    super.dispose();
  }
}

class MessageScope extends InheritedNotifier<MessageCenter> {
  const MessageScope({
    super.key,
    required MessageCenter? center,
    required super.child,
  }) : super(notifier: center);
  static MessageCenter? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MessageScope>()?.notifier;
}

class MessageHost extends StatefulWidget {
  final Widget child;
  const MessageHost({super.key, required this.child});
  @override
  State<MessageHost> createState() => _MessageHostState();
}

class _MessageHostState extends State<MessageHost> {
  MessageCenter? _center;
  NotificationService? _notifications;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    _notifications ??= app.notifications;
    _profile ??= app.auth.watchProfile(app.market.uid).listen((profile) {
      if (!mounted ||
          !profile.exists ||
          profile.metadata.hasPendingWrites ||
          _center != null) {
        return;
      }
      setState(
        () => _center = MessageCenter(app.market, (message) {
          if (!mounted) return;
          // Unread badges remain available even when preview notifications are off.
          if (!app.settings.notifications) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text('${message.sender}: ${message.preview}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          unawaited(
            app.notifications
                .show(
                  'message-${message.conversationId}-${message.messageId}',
                  '${message.sender} · UniMarket',
                  message.preview,
                )
                .catchError((_) => false),
          );
        }),
      );
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _profile?.cancel();
    _center?.dispose();
    final notifications = _notifications;
    if (notifications != null) {
      unawaited(notifications.clear().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MessageScope(center: _center, child: widget.child);
}
