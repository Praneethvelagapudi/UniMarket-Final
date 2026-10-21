import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../app.dart';
import '../services/voice_clip.dart';

class VoicePlayback extends StatefulWidget {
  final Future<VoiceClip> Function() load;
  final int durationMs;
  const VoicePlayback({
    super.key,
    required this.load,
    required this.durationMs,
  });
  @override
  State<VoicePlayback> createState() => _VoicePlaybackState();
}

class _VoicePlaybackState extends State<VoicePlayback> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _state;
  VoiceClip? _clip;
  bool _loading = false, _playing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _state = _player.onPlayerStateChanged.listen(
      (state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _playing = false;
            _loading = false;
            _error = 'Audio playback failed. Try again on this device.';
          });
        }
      },
    );
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_playing) {
        await _player.pause();
      } else {
        _clip ??= await widget.load();
        if (!mounted) return;
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else {
          await _player.play(BytesSource(_clip!.bytes, mimeType: 'audio/wav'));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Audio unavailable. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _state?.cancel();
    _player.dispose();
    _clip = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _playing ? 'Pause voice message' : 'Play voice message',
            onPressed: _loading ? null : _toggle,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_playing ? Icons.pause_circle : Icons.play_circle_fill),
          ),
          const Icon(Icons.graphic_eq_rounded),
          const SizedBox(width: 8),
          Text('Voice · ${(widget.durationMs / 1000).toStringAsFixed(1)}s'),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

/// Returns actual microphone bytes only after the sender previews and chooses
/// Send. Nothing is persisted for cancelled or denied recordings.
class VoiceRecordDialog extends StatefulWidget {
  final AudioRecorder? recorder;
  const VoiceRecordDialog({super.key, this.recorder});
  @override
  State<VoiceRecordDialog> createState() => _VoiceRecordDialogState();
}

class _VoiceRecordDialogState extends State<VoiceRecordDialog>
    with WidgetsBindingObserver {
  late final _recorder = widget.recorder ?? AudioRecorder();
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _stream;
  Timer? _timer;
  bool _recording = false, _busy = false;
  int _length = 0;
  VoiceClip? _clip;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) unawaited(_stop());
  }

  Future<void> _start() async {
    if (_busy || _recording) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _recorder.hasPermission().timeout(
        const Duration(seconds: 20),
      )) {
        throw StateError(
          'Microphone permission was denied. Allow microphone access in app or browser settings to record.',
        );
      }
      if (!mounted) return;
      if (!await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
        throw StateError(
          'This device does not support voice recording. Use Android or a supported browser on HTTPS or localhost.',
        );
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: VoiceClip.sampleRate,
          numChannels: 1,
        ),
      );
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      _pcm.clear();
      _length = 0;
      setState(() {
        _recording = true;
        _clip = null;
      });
      _stream = stream.listen(
        (chunk) {
          final remaining = VoiceClip.maxPcmBytes - _length;
          if (remaining <= 0) return;
          final take = chunk.length > remaining ? remaining : chunk.length;
          _pcm.add(Uint8List.sublistView(chunk, 0, take));
          _length += take;
          if (mounted) setState(() {});
          if (_length >= VoiceClip.maxPcmBytes) unawaited(_stop());
        },
        onError: (Object e) {
          if (mounted) {
            setState(
              () => _error = 'The microphone stopped. Try recording again.',
            );
          }
          unawaited(_stop());
        },
      );
      _timer = Timer(const Duration(seconds: VoiceClip.maxSeconds), _stop);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : e is TimeoutException
              ? 'Microphone permission is still waiting. Respond to the device or browser prompt, or cancel and try again.'
              : 'Microphone unavailable. Check permission and use HTTPS or localhost.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (!_recording || _busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      await _recorder.stop();
      await _stream?.cancel();
      _stream = null;
      final pcm = _pcm.takeBytes();
      final clip = VoiceClip.fromPcm(
        Uint8List.sublistView(pcm, 0, pcm.length - pcm.length % 2),
      );
      if (mounted) setState(() => _clip = clip);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No usable audio was captured. Record for at least a moment and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _recording = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stream?.cancel();
    _recorder.dispose();
    _pcm.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Voice message'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Record up to 15 seconds. Preview your message before sending.',
          ),
          const SizedBox(height: 16),
          if (_recording)
            Text(
              'Recording… ${(_length / 16000).toStringAsFixed(1)} / 15s',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (_clip != null)
            VoicePlayback(
              key: ValueKey(_clip),
              durationMs: _clip!.durationMs,
              load: () async => _clip!,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : _recording
                ? _stop
                : _start,
            icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
            label: Text(
              _busy
                  ? 'Please wait…'
                  : _recording
                  ? 'Stop recording'
                  : _clip == null
                  ? 'Record'
                  : 'Record again',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        // Browser permission prompts can remain unanswered indefinitely. Keep
        // cancellation available, even before permission/capture has resolved.
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _clip == null || _recording || _busy
            ? null
            : () => Navigator.pop(context, _clip),
        child: const Text('Send voice message'),
      ),
    ],
  );
}

class StoredVoiceMessage extends StatelessWidget {
  final String conversationId, messageId;
  final int durationMs;
  const StoredVoiceMessage({
    super.key,
    required this.conversationId,
    required this.messageId,
    required this.durationMs,
  });
  @override
  Widget build(BuildContext context) {
    final market = AppScope.of(context).market;
    return VoicePlayback(
      durationMs: durationMs,
      load: () => market.loadVoice(conversationId, messageId),
    );
  }
}
