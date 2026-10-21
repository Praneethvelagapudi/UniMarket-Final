import 'dart:convert';
import 'dart:typed_data';

/// Small, portable PCM WAV clips fit the project's existing private Firestore
/// architecture without requiring Firebase Storage or a billing-plan change.
class VoiceClip {
  static const sampleRate = 8000;
  static const maxSeconds = 15;
  static const maxPcmBytes = sampleRate * 2 * maxSeconds;
  static const maxFileBytes = maxPcmBytes + 44;
  static const maxBase64Length = 320060;
  final Uint8List bytes;
  final int durationMs;
  const VoiceClip._(this.bytes, this.durationMs);

  factory VoiceClip.fromPcm(Uint8List pcm) {
    if (pcm.length < 1600 || pcm.length > maxPcmBytes || pcm.length.isOdd) {
      throw ArgumentError('Record between 0.1 and 15 seconds of audio.');
    }
    final bytes = Uint8List(44 + pcm.length);
    final header = ByteData.sublistView(bytes);
    void label(int at, String value) =>
        bytes.setRange(at, at + value.length, ascii.encode(value));
    label(0, 'RIFF');
    header.setUint32(4, bytes.length - 8, Endian.little);
    label(8, 'WAVE');
    label(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    label(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    bytes.setRange(44, bytes.length, pcm);
    return VoiceClip._(bytes, pcm.length * 1000 ~/ (sampleRate * 2));
  }

  factory VoiceClip.decode(String data, int durationMs) {
    if (data.length > maxBase64Length) {
      throw const FormatException('Audio is too large.');
    }
    final bytes = base64Decode(data);
    if (bytes.length < 1644 || bytes.length > maxFileBytes) {
      throw const FormatException('Invalid audio size.');
    }
    final h = ByteData.sublistView(bytes);
    String label(int start, int end) =>
        ascii.decode(bytes.sublist(start, end), allowInvalid: true);
    if (label(0, 4) != 'RIFF' ||
        label(8, 12) != 'WAVE' ||
        label(12, 16) != 'fmt ' ||
        label(36, 40) != 'data' ||
        h.getUint32(4, Endian.little) != bytes.length - 8 ||
        h.getUint32(16, Endian.little) != 16 ||
        h.getUint16(20, Endian.little) != 1 ||
        h.getUint16(22, Endian.little) != 1 ||
        h.getUint32(24, Endian.little) != sampleRate ||
        h.getUint32(28, Endian.little) != sampleRate * 2 ||
        h.getUint16(32, Endian.little) != 2 ||
        h.getUint16(34, Endian.little) != 16 ||
        h.getUint32(40, Endian.little) != bytes.length - 44 ||
        (bytes.length - 44).isOdd ||
        durationMs != (bytes.length - 44) * 1000 ~/ (sampleRate * 2)) {
      throw const FormatException('Invalid voice message format.');
    }
    return VoiceClip._(bytes, durationMs);
  }
  String get encoded => base64Encode(bytes);
}
