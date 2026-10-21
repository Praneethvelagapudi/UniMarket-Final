import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:unimarket/widgets/voice_message.dart';

class PermissionRecorder extends Fake implements AudioRecorder {
  final Future<bool> permission;
  bool disposed = false;
  PermissionRecorder(this.permission);
  @override
  Future<bool> hasPermission({bool request = true}) => permission;
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  Future<void> render(WidgetTester tester, AudioRecorder recorder) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => VoiceRecordDialog(recorder: recorder),
              ),
              child: const Text('Open voice'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pump();
  }

  testWidgets('microphone denial explains the error without enabling Send', (
    tester,
  ) async {
    await render(tester, PermissionRecorder(Future.value(false)));
    await tester.pump();
    expect(
      find.textContaining('Microphone permission was denied'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Send voice message'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'an unanswered permission prompt cannot trap the user in the dialog',
    (tester) async {
      final pending = Completer<bool>();
      final recorder = PermissionRecorder(pending.future);
      await render(tester, recorder);
      expect(find.text('Please wait…'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Voice message'), findsNothing);
      expect(recorder.disposed, isTrue);
      pending.complete(true);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an unanswered permission prompt times out with a clear explanation',
    (tester) async {
      final pending = Completer<bool>();
      await render(tester, PermissionRecorder(pending.future));
      await tester.pump(const Duration(seconds: 21));
      await tester.pump();
      expect(
        find.textContaining('Microphone permission is still waiting'),
        findsOneWidget,
      );
      expect(find.text('Record'), findsOneWidget);
      pending.complete(false);
      await tester.pump();
    },
  );
}
