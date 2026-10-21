import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/voice_message.dart';
import '../services/voice_clip.dart';
import '../services/message_center.dart';
import 'booking_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});
  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).market.conversations();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      final docs = (snapshot.data?.docs ?? []).toList()
        ..sort(
          (a, b) => dateValue(
            b.data()['createdAt'],
          ).compareTo(dateValue(a.data()['createdAt'])),
        );
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Campus conversations',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Ask a question, negotiate a price, or plan a pickup.'),
          const SizedBox(height: 24),
          if (MessageScope.maybeOf(context)?.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                MessageScope.maybeOf(context)!.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          CacheBanner(cached: snapshot.data?.metadata.isFromCache ?? false),
          if (snapshot.hasError)
            ErrorState(error: snapshot.error!)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (docs.isEmpty)
            const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Start a conversation',
              body:
                  'Open an item and tap Chat with seller to talk directly to another student.',
            )
          else
            ...docs.map((doc) {
              final d = doc.data();
              final buyer = d['buyerId'] == AppScope.of(context).market.uid;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(d['title']),
                    subtitle: Text(
                      '${buyer ? d['sellerName'] : d['buyerName']}\n${MessageScope.maybeOf(context)?.preview(doc.id) ?? ''}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Badge(
                      isLabelVisible:
                          (MessageScope.maybeOf(context)?.unread(doc.id) ?? 0) >
                          0,
                      label: Text(
                        '${MessageScope.maybeOf(context)?.unread(doc.id) ?? 0}',
                      ),
                      child: const Icon(Icons.chevron_right_rounded),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(id: doc.id, title: d['title']),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      );
    },
  );
}

class ChatScreen extends StatefulWidget {
  final String id, title;
  const ChatScreen({super.key, required this.id, required this.title});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _message = TextEditingController();
  bool _busy = false;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  MessageCenter? _center;
  String? _textId, _attemptText, _voiceId;
  VoiceClip? _voice;
  String? _sendError;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).market.messages(widget.id);
    _center ??= MessageScope.maybeOf(context);
    _center?.setActive(widget.id);
  }

  @override
  void dispose() {
    _message.dispose();
    if (_center?.activeConversation == widget.id) _center?.setActive(null);
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    if (_busy) return;
    final value = (text ?? _message.text).trim();
    if (value.trim().isEmpty) return;
    final market = AppScope.of(context).market;
    if (_attemptText != value) {
      _textId = market.newMessageId(widget.id);
      _attemptText = value;
    }
    setState(() {
      _busy = true;
      _sendError = null;
    });
    try {
      await market.sendMessage(widget.id, value, messageId: _textId);
      if (mounted) {
        if (text == null) _message.clear();
        _textId = null;
        _attemptText = null;
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _sendError =
              'Message not confirmed. Retry the same text safely, or check the conversation before changing it.',
        );
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _record() async {
    if (_busy) return;
    final clip = await showDialog<VoiceClip>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecordDialog(),
    );
    if (clip == null || !mounted) return;
    _voice = clip;
    _voiceId = AppScope.of(context).market.newMessageId(widget.id);
    await _sendVoice();
  }

  Future<void> _sendVoice() async {
    if (_busy || _voice == null || _voiceId == null) return;
    setState(() {
      _busy = true;
      _sendError = null;
    });
    try {
      await AppScope.of(
        context,
      ).market.sendVoice(widget.id, _voice!, messageId: _voiceId!);
      if (mounted) {
        setState(() {
          _voice = null;
          _voiceId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _sendError =
              'Voice message not confirmed. Your recording is kept here for a safe retry.',
        );
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _meetup() async {
    final location = await showDialog<String>(
      context: context,
      builder: (_) => const _MeetupLocationDialog(),
    );
    if (location == null || !mounted) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final pickup = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (pickup.isBefore(DateTime.now())) {
      showNotice(context, 'Choose a future meetup time.');
      return;
    }
    await _send(
      'Meetup proposal\n$location\n${displayTime(pickup)}\nPlease confirm this spot and time in chat.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Propose a meetup',
          onPressed: _busy ? null : _meetup,
          icon: const Icon(Icons.place_outlined),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Keep pickup arrangements on campus. Booking totals use the published listing price.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorState(error: snapshot.error!);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs.reversed.toList();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: CacheBanner(
                          cached: snapshot.data!.metadata.isFromCache,
                        ),
                      ),
                      Expanded(
                        child: docs.isEmpty
                            ? const EmptyState(
                                icon: Icons.waving_hand_outlined,
                                title: 'Say hello',
                                body:
                                    'Ask about the item or propose a price and campus pickup.',
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(20),
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final doc = docs[i];
                                  final d = doc.data();
                                  final own =
                                      d['senderId'] ==
                                      AppScope.of(context).market.uid;
                                  return Align(
                                    alignment: own
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 440,
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: own
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primaryContainer
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              own
                                                  ? 'You'
                                                  : _center?.senderName(
                                                          widget.id,
                                                          d['senderId'],
                                                        ) ??
                                                        'Participant',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                            if (d['type'] == 'audio')
                                              StoredVoiceMessage(
                                                key: ValueKey(doc.id),
                                                conversationId: widget.id,
                                                messageId: doc.id,
                                                durationMs:
                                                    d['durationMs'] as int,
                                              )
                                            else
                                              SelectableText(d['text'] ?? ''),
                                            const SizedBox(height: 6),
                                            Text(
                                              doc.metadata.hasPendingWrites
                                                  ? 'Sending…'
                                                  : d['createdAt'] == null
                                                  ? ''
                                                  : '${own ? 'Sent · ' : ''}${displayTime(dateValue(d['createdAt']))}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  _sendError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_voice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    VoicePlayback(
                      key: ValueKey(_voice),
                      load: () async => _voice!,
                      durationMs: _voice!.durationMs,
                    ),
                    TextButton(
                      onPressed: _busy ? null : _sendVoice,
                      child: const Text('Retry voice message'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _voice = null;
                              _voiceId = null;
                              _sendError = null;
                            }),
                      child: const Text('Discard recording'),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Record voice message (up to 15 seconds)',
                      onPressed: _busy || _voice != null ? null : _record,
                      icon: const Icon(Icons.mic_none_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _message,
                        enabled: !_busy,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Type a message…',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: _busy ? null : () => _send(),
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MeetupLocationDialog extends StatefulWidget {
  const _MeetupLocationDialog();
  @override
  State<_MeetupLocationDialog> createState() => _MeetupLocationDialogState();
}

class _MeetupLocationDialogState extends State<_MeetupLocationDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Propose a campus meetup'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        maxLength: 120,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Pickup spot'),
        validator: (v) => v == null || v.trim().length < 3
            ? 'Enter a specific campus location.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Choose time'),
      ),
    ],
  );
}
