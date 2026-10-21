import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimarket/services/voice_clip.dart';

void main() {
  test('WAV round trip preserves microphone PCM and exact duration', () {
    final pcm = Uint8List.fromList(List.generate(16000, (i) => i % 256));
    final clip = VoiceClip.fromPcm(pcm);
    expect(clip.durationMs, 1000);
    final decoded = VoiceClip.decode(clip.encoded, 1000);
    expect(decoded.bytes.sublist(44), pcm);
    expect(decoded.bytes.sublist(0, 4), [82, 73, 70, 70]);
    expect(
      ByteData.sublistView(decoded.bytes).getUint32(24, Endian.little),
      8000,
    );
  });
  test(
    'recording duration and byte limits include the exact upper boundary',
    () {
      expect(
        VoiceClip.fromPcm(Uint8List(VoiceClip.maxPcmBytes)).durationMs,
        15000,
      );
      expect(
        VoiceClip.fromPcm(Uint8List(VoiceClip.maxPcmBytes)).encoded.length,
        VoiceClip.maxBase64Length,
      );
      for (final length in [0, 1598, 1601, VoiceClip.maxPcmBytes + 2]) {
        expect(() => VoiceClip.fromPcm(Uint8List(length)), throwsArgumentError);
      }
    },
  );
  test(
    'malformed payload, MIME-container mismatch and duration tampering fail',
    () {
      final clip = VoiceClip.fromPcm(Uint8List(16000));
      expect(() => VoiceClip.decode(clip.encoded, 999), throwsFormatException);
      expect(() => VoiceClip.decode('not-base64', 1000), throwsFormatException);
      final tampered = Uint8List.fromList(clip.bytes)..[22] = 2;
      // Round-tripping the valid content uses the encoded container. The tampered
      // channel count must fail before any audio player sees untrusted bytes.
      expect(
        () => VoiceClip.decode(base64Encode(tampered), 1000),
        throwsFormatException,
      );
    },
  );
}
