import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/voice_recorder.dart';

class ChatScreen extends StatefulWidget {
  final UserProfile? otherUser;
  final String? groupRoomId;
  final String? groupName;

  const ChatScreen({super.key, this.otherUser, this.groupRoomId, this.groupName});

  bool get isGroup => groupRoomId != null;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();
  final _storageService = StorageService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isSending = false;
  bool _showExtraActions = false;
  bool _showEmojiPicker = false;
  bool _showMentionPicker = false;
  String _myName = '';
  StreamSubscription? _readSub;
  List<Map<String, String>> _groupMembers = [];

  late final _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

  bool get _isDesktopOrWeb =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  String get _myUid => _authService.currentUser?.uid ?? '';

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isDesktopOrWeb) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _sendText();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _loadMyName();
    _doMarkAsRead();
    if (widget.isGroup) _loadGroupMembers();

    _textController.addListener(_onTextChanged);

    final msgStream = widget.isGroup
        ? _chatService.getMessagesByRoom(widget.groupRoomId!, limit: 1)
        : _chatService.getMessages(_myUid, widget.otherUser!.uid, limit: 1);

    _readSub = msgStream.listen((messages) {
      if (messages.isNotEmpty && messages.first.senderId != _myUid) {
        _doMarkAsRead();
      }
    });
  }

  Future<void> _loadGroupMembers() async {
    final members = await _chatService.getGroupMemberProfiles(widget.groupRoomId!);
    if (mounted) setState(() => _groupMembers = members);
  }

  void _onTextChanged() {
    if (!widget.isGroup) return;
    final text = _textController.text;
    final sel = _textController.selection;
    if (!sel.isValid || sel.baseOffset == 0) return;
    final charBefore = text[sel.baseOffset - 1];
    if (charBefore == '@' && !_showMentionPicker) {
      setState(() => _showMentionPicker = true);
    }
  }

  void _insertMention(Map<String, String> member) {
    final text = _textController.text;
    final sel = _textController.selection;
    final cursorPos = sel.isValid ? sel.baseOffset : text.length;
    final atIndex = text.lastIndexOf('@', cursorPos - 1);
    if (atIndex >= 0) {
      final mention = '@${member['displayName']} ';
      final newText = text.replaceRange(atIndex, cursorPos, mention);
      _textController.text = newText;
      _textController.selection = TextSelection.collapsed(offset: atIndex + mention.length);
    }
    setState(() => _showMentionPicker = false);
    _focusNode.requestFocus();
  }

  Future<void> _loadMyName() async {
    final name = await _authService.getCurrentUserName();
    if (mounted) setState(() => _myName = name);
  }

  Future<void> _doMarkAsRead() async {
    if (widget.isGroup) {
      await _chatService.markRoomAsRead(widget.groupRoomId!, _myUid);
    } else {
      await _chatService.markAsRead(_myUid, widget.otherUser!.uid);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _readSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() {
      _showExtraActions = false;
      _showEmojiPicker = false;
    });

    if (widget.isGroup) {
      await _chatService.sendTextToRoom(
        roomId: widget.groupRoomId!,
        senderId: _myUid,
        senderName: _myName,
        text: text,
      );
    } else {
      await _chatService.sendTextMessage(
        senderId: _myUid,
        senderName: _myName,
        receiverId: widget.otherUser!.uid,
        text: text,
      );
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 60,
    );
    if (xFile == null) return;

    setState(() => _isSending = true);
    try {
      final bytes = await xFile.readAsBytes();
      final name = xFile.name.contains('.') ? xFile.name : '${xFile.name}.jpg';
      final url = await _storageService.uploadImageBytes(bytes, name);
      if (widget.isGroup) {
        await _chatService.sendImageToRoom(
          roomId: widget.groupRoomId!,
          senderId: _myUid,
          senderName: _myName,
          imageUrl: url,
        );
      } else {
        await _chatService.sendImageMessage(
          senderId: _myUid,
          senderName: _myName,
          receiverId: widget.otherUser!.uid,
          imageUrl: url,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片发送失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleVoiceRecordComplete(String path, int durationSeconds) async {
    setState(() => _isSending = true);
    try {
      final url = await _storageService.uploadVoice(path);
      if (widget.isGroup) {
        await _chatService.sendVoiceToRoom(
          roomId: widget.groupRoomId!,
          senderId: _myUid,
          senderName: _myName,
          voiceUrl: url,
          durationSeconds: durationSeconds,
        );
      } else {
        await _chatService.sendVoiceMessage(
          senderId: _myUid,
          senderName: _myName,
          receiverId: widget.otherUser!.uid,
          voiceUrl: url,
          durationSeconds: durationSeconds,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji.emoji);
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: start + emoji.emoji.length,
    );
    setState(() {});
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      _showExtraActions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = widget.isGroup ? widget.groupName! : widget.otherUser!.displayName;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withValues(alpha: 0.85),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18,
              color: isDark ? Colors.white : const Color(0xFF007AFF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: widget.isGroup
                    ? const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF30D158)])
                    : const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5856D6)]),
              ),
              child: Center(
                child: widget.isGroup
                    ? const Icon(Icons.group, size: 18, color: Colors.white)
                    : Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Text(displayName,
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                )),
          ],
        ),
        centerTitle: false,
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: Icon(Icons.people_outline, size: 22,
                  color: isDark ? Colors.white : const Color(0xFF007AFF)),
              onPressed: _showMembersSheet,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1C1C1E), const Color(0xFF000000)]
                : [const Color(0xFFF2F2F7), const Color(0xFFE8ECF4)],
          ),
        ),
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_showMentionPicker) _buildMentionPicker(context),
            if (_isSending)
              LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: const Color(0xFF007AFF),
                minHeight: 2,
              ),
            _buildInputBar(context),
            if (_showExtraActions) _buildExtraActionsPanel(context),
            if (_showEmojiPicker) _buildEmojiPicker(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final stream = widget.isGroup
        ? _chatService.getMessagesByRoom(widget.groupRoomId!, limit: 100)
        : _chatService.getMessages(_myUid, widget.otherUser!.uid, limit: 100);

    return StreamBuilder<List<Message>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 56,
                    color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 16),
                Text('还没有消息\n发条消息开始聊天吧！',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                ),
              ],
            ),
          );
        }

        final messages = snapshot.data!;
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg.senderId == _myUid;

            bool showDateSeparator = false;
            if (index == messages.length - 1) {
              showDateSeparator = true;
            } else {
              final nextMsg = messages[index + 1];
              if (msg.timestamp.difference(nextMsg.timestamp).inMinutes > 5) {
                showDateSeparator = true;
              }
            }

            return Column(
              children: [
                if (showDateSeparator) _buildDateSeparator(msg.timestamp),
                MessageBubble(
                  message: msg,
                  isMe: isMe,
                  showSenderName: widget.isGroup,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    String label;
    if (msgDate == today) {
      label = '今天 ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      label = '昨天 ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      label = '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black38),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 8, right: 8, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!kIsWeb) VoiceRecorderButton(onRecordComplete: _handleVoiceRecordComplete),
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: const Color(0xFF007AFF), size: 24,
            ),
            onPressed: _toggleEmojiPicker,
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: _isDesktopOrWeb ? TextInputAction.none : TextInputAction.newline,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: _isDesktopOrWeb ? 'Enter发送, Shift+Enter换行' : '输入消息...',
                  hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              if (value.text.trim().isNotEmpty) {
                return Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: _sendText,
                  ),
                );
              }
              return IconButton(
                icon: Icon(
                  _showExtraActions ? Icons.close : Icons.add_circle,
                  color: const Color(0xFF007AFF), size: 28,
                ),
                onPressed: () => setState(() {
                  _showExtraActions = !_showExtraActions;
                  _showEmojiPicker = false;
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMentionPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherMembers = _groupMembers.where((m) => m['uid'] != _myUid).toList();
    if (otherMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF2C2C2E) : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: otherMembers.length,
        separatorBuilder: (_, __) => Divider(
          height: 1, indent: 56,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
        itemBuilder: (context, index) {
          final member = otherMembers[index];
          final name = member['displayName'] ?? '';
          final avatarGradients = [
            [const Color(0xFF007AFF), const Color(0xFF5856D6)],
            [const Color(0xFFFF9500), const Color(0xFFFF6B00)],
            [const Color(0xFF34C759), const Color(0xFF30D158)],
            [const Color(0xFFAF52DE), const Color(0xFF5856D6)],
            [const Color(0xFFFF2D55), const Color(0xFFFF6482)],
          ];
          final grad = avatarGradients[name.hashCode.abs() % avatarGradients.length];

          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _insertMention(member),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: grad),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(name,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMembersSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('群成员 (${_groupMembers.length})',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              ..._groupMembers.map((member) {
                final name = member['displayName'] ?? '';
                final email = member['email'] ?? '';
                final isMe = member['uid'] == _myUid;
                final avatarGradients = [
                  [const Color(0xFF007AFF), const Color(0xFF5856D6)],
                  [const Color(0xFFFF9500), const Color(0xFFFF6B00)],
                  [const Color(0xFF34C759), const Color(0xFF30D158)],
                  [const Color(0xFFAF52DE), const Color(0xFF5856D6)],
                  [const Color(0xFFFF2D55), const Color(0xFFFF6482)],
                ];
                final grad = avatarGradients[name.hashCode.abs() % avatarGradients.length];

                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: grad),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  title: Text(
                    isMe ? '$name (我)' : name,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  subtitle: Text(email,
                    style: TextStyle(fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38),
                  ),
                );
              }),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExtraActionsPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        border: Border(
          top: BorderSide(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(
            icon: Icons.photo_library_rounded, label: '相册',
            gradient: const [Color(0xFF007AFF), Color(0xFF5AC8FA)],
            onTap: () {
              setState(() => _showExtraActions = false);
              _pickAndSendImage(ImageSource.gallery);
            },
          ),
          _buildActionItem(
            icon: Icons.camera_alt_rounded, label: '拍照',
            gradient: const [Color(0xFF34C759), Color(0xFF30D158)],
            onTap: () {
              setState(() => _showExtraActions = false);
              _pickAndSendImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker(BuildContext context) {
    return SizedBox(
      height: 280,
      child: EmojiPicker(
        onEmojiSelected: _onEmojiSelected,
        onBackspacePressed: () {
          final text = _textController.text;
          if (text.isNotEmpty) {
            final selection = _textController.selection;
            final start = selection.isValid ? selection.start : text.length;
            if (start > 0) {
              final runes = text.substring(0, start).runes.toList();
              runes.removeLast();
              final newBefore = String.fromCharCodes(runes);
              _textController.text = newBefore + text.substring(start);
              _textController.selection = TextSelection.collapsed(offset: newBefore.length);
              setState(() {});
            }
          }
        },
        config: Config(
          height: 280,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 7,
            emojiSizeMax: 28 * (kIsWeb ? 1.0 : 1.0),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: Theme.of(context).colorScheme.primary,
            iconColorSelected: Theme.of(context).colorScheme.primary,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          searchViewConfig: SearchViewConfig(
            backgroundColor: Theme.of(context).colorScheme.surface,
            buttonIconColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon, required String label,
    required List<Color> gradient, required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
            fontSize: 12, color: isDark ? Colors.white54 : Colors.black54,
          )),
        ],
      ),
    );
  }
}
