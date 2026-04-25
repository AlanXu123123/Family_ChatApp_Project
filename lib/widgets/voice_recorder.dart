import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

class VoiceRecorderButton extends StatefulWidget {
  final Future<void> Function(String path, int durationSeconds) onRecordComplete;

  const VoiceRecorderButton({super.key, required this.onRecordComplete});

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: '',
      );
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordSeconds++);
      });
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordSeconds;
    setState(() => _isRecording = false);

    if (path != null && duration > 0) {
      await widget.onRecordComplete(path, duration);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Text(
              '${_recordSeconds}s',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _cancelRecording,
              child: Icon(Icons.close, color: colorScheme.error, size: 20),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressEnd: (_) {
        if (_isRecording) _stopRecording();
      },
      child: IconButton(
        icon: const Icon(Icons.mic_none),
        onPressed: _startRecording,
        tooltip: '按住录音',
      ),
    );
  }
}
