import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unimarket/services/voice_clip.dart';
import 'package:unimarket/widgets/voice_message.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual device microphone capture, preview and cancel controls', (
    tester,
  ) async {
    VoiceClip? result;
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('Control did not appear: $finder');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<VoiceClip>(
                  context: context,
                  builder: (_) => const VoiceRecordDialog(),
                );
              },
              child: const Text('Record device audio'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Record device audio'));
    await waitFor(find.text('Record'));
    await tester.tap(find.text('Record'));
    await waitFor(find.textContaining('Recording…'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.tap(find.text('Stop recording'));
    await waitFor(find.byTooltip('Play voice message'));
    await tester.tap(find.byTooltip('Play voice message'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.textContaining('Audio unavailable'), findsNothing);
    await tester.tap(find.text('Send voice message'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.durationMs, inInclusiveRange(100, 15000));
    expect(
      result!.bytes.length,
      inInclusiveRange(1644, VoiceClip.maxFileBytes),
    );
    expect(
      VoiceClip.decode(result!.encoded, result!.durationMs).bytes,
      result!.bytes,
    );
    debugPrint(
      'Actual microphone stream: ${result!.durationMs}ms, ${result!.bytes.length} WAV bytes. Hearing/physical microphone quality is not asserted.',
    );
    result = null;
    await tester.tap(find.text('Record device audio'));
    await waitFor(find.text('Record'));
    await tester.tap(find.text('Record'));
    await waitFor(find.textContaining('Recording…'));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
