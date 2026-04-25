import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import 'image_full_screen.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool showSenderName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playVoice() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    await _audioPlayer.play(UrlSource(widget.message.content));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = widget.isMe;
    final msg = widget.message;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (widget.showSenderName && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 3),
              child: Text(
                msg.senderName,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                _buildAvatar(msg, isDark),
                const SizedBox(width: 8),
              ],
              Flexible(child: _buildBubbleContent(context, isDark)),
              if (isMe) ...[
                const SizedBox(width: 8),
                _buildAvatar(msg, isDark),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 44, right: isMe ? 44 : 0, top: 3,
            ),
            child: Text(
              DateFormat('HH:mm').format(msg.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _avatarGradients = [
    [Color(0xFFFF9500), Color(0xFFFF6B00)],
    [Color(0xFF5856D6), Color(0xFFAF52DE)],
    [Color(0xFFFF2D55), Color(0xFFFF6482)],
    [Color(0xFF007AFF), Color(0xFF5AC8FA)],
    [Color(0xFF34C759), Color(0xFF30D158)],
  ];

  Widget _buildAvatar(Message msg, bool isDark) {
    final idx = msg.senderName.hashCode.abs() % _avatarGradients.length;
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(colors: _avatarGradients[idx]),
      ),
      child: Center(
        child: Text(
          msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context, bool isDark) {
    final isMe = widget.isMe;
    final msg = widget.message;

    switch (msg.type) {
      case MessageType.text:
        return Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5856D6)])
                : null,
            color: isMe ? null : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: isMe
                    ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildRichText(
            content: msg.content,
            baseStyle: TextStyle(
              fontSize: 16,
              color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
              height: 1.3,
            ),
            isMe: isMe,
            isDark: isDark,
          ),
        );

      case MessageType.image:
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ImageFullScreen(imageUrl: msg.content)),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
              maxHeight: 280,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: msg.content,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                width: 200, height: 150,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, _, _) => Container(
                width: 200, height: 150,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
        );

      case MessageType.voice:
        final duration = msg.voiceDurationSeconds ?? 0;
        final bubbleWidth = 80.0 + (duration.clamp(1, 30) * 4.0);
        return GestureDetector(
          onTap: _playVoice,
          child: Container(
            width: bubbleWidth.clamp(100.0, MediaQuery.of(context).size.width * 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5856D6)])
                  : null,
              color: isMe ? null : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: isMe ? Colors.white : const Color(0xFF007AFF),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildVoiceWaveform(isMe, isDark),
                      const SizedBox(height: 2),
                      Text(
                        '$duration″',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  static final _mentionRegex = RegExp(r'@\S+');

  Widget _buildRichText({
    required String content,
    required TextStyle baseStyle,
    required bool isMe,
    required bool isDark,
  }) {
    final matches = _mentionRegex.allMatches(content).toList();
    if (matches.isEmpty) {
      return Text(content, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isMe ? const Color(0xFFB3E5FF) : const Color(0xFF007AFF),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  Widget _buildVoiceWaveform(bool isMe, bool isDark) {
    final color = isMe ? Colors.white60 : const Color(0xFF007AFF).withValues(alpha: 0.5);
    return Row(
      children: List.generate(12, (i) {
        final heights = [4.0, 8.0, 6.0, 12.0, 8.0, 14.0, 10.0, 6.0, 12.0, 8.0, 4.0, 6.0];
        return Container(
          width: 2, height: heights[i],
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: _isPlaying ? color : color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
