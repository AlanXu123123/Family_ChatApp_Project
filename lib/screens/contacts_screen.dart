import 'dart:js_interop';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/badge_service.dart';
import '../widgets/glass_container.dart';
import 'chat_screen.dart';

@JS('_openUrl')
external void _jsOpenUrl(JSString url);

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();

  String get _myUid => _authService.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _listenTotalUnread();
  }

  void _listenTotalUnread() {
    if (_myUid.isEmpty) return;
    _chatService.getTotalUnreadCount(_myUid).listen((total) {
      updateAppBadge(total);
    });
  }

  void _openChat(UserProfile contact) async {
    await _chatService.ensureChatRoom(_myUid, contact.uid);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(otherUser: contact)),
      );
    }
  }

  void _openGroupChat(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          groupRoomId: group['id'] as String,
          groupName: group['name'] as String? ?? '群聊',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1C1C1E), const Color(0xFF000000)]
                : [const Color(0xFFE8ECF4), const Color(0xFFF2F2F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    _buildProfileCard(context, isDark),
                    const SizedBox(height: 16),
                    _buildVocabButton(context, isDark),
                    const SizedBox(height: 24),
                    _buildGroupChatsSection(context, isDark),
                    _buildFriendsSection(context, isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Text(
            'Justin Chat',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.more_horiz,
                  color: isDark ? Colors.white70 : Colors.black54, size: 20),
            ),
            onSelected: (value) {
              if (value == 'logout') _authService.signOut();
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 10),
                    Text('退出登录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool isDark) {
    return GlassContainer(
      blur: 30,
      opacity: isDark ? 0.08 : 0.6,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<String>(
        future: _authService.getCurrentUserName(),
        builder: (context, snap) {
          final name = snap.data ?? '...';
          return Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      )),
                  const SizedBox(height: 2),
                  Text(
                    _authService.currentUser?.email ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVocabButton(BuildContext context, bool isDark) {
    return GlassContainer(
      opacity: isDark ? 0.08 : 0.55,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9500), Color(0xFFFF6B00)],
            ),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
        ),
        title: Text(
          '英语学习',
          style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
        subtitle: Text(
          '背单词测验 · 语法训练 · AI造句',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black38),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14,
            color: isDark ? Colors.white24 : Colors.black26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () {
          try {
            _jsOpenUrl('https://alanxu123123.github.io/Justin-Vocabulary-Learning/vocabulary-quiz/'.toJS);
          } catch (_) {}
        },
      ),
    );
  }

  Widget _buildGroupChatsSection(BuildContext context, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getGroupChats(_myUid),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('群聊', isDark),
            const SizedBox(height: 8),
            ...groups.map((group) => _GroupChatCard(
                  group: group,
                  myUid: _myUid,
                  chatService: _chatService,
                  isDark: isDark,
                  onTap: () => _openGroupChat(group),
                )),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildFriendsSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('好友', isDark),
        const SizedBox(height: 8),
        StreamBuilder<List<UserProfile>>(
          stream: _authService.getAllUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final contacts = (snapshot.data ?? []).where((u) => u.uid != _myUid).toList();
            if (contacts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('等待其他成员登录...',
                      style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                ),
              );
            }
            return Column(
              children: contacts
                  .map((c) => _ContactCard(
                        contact: c,
                        myUid: _myUid,
                        chatService: _chatService,
                        isDark: isDark,
                        onTap: () => _openChat(c),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _GroupChatCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String myUid;
  final ChatService chatService;
  final bool isDark;
  final VoidCallback onTap;

  const _GroupChatCard({
    required this.group,
    required this.myUid,
    required this.chatService,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participants = List<String>.from(group['participants'] ?? []);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      opacity: isDark ? 0.08 : 0.55,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF34C759), Color(0xFF30D158)],
            ),
          ),
          child: const Icon(Icons.group, color: Colors.white, size: 22),
        ),
        title: Text(
          '${group['name'] ?? '群聊'} (${participants.length})',
          style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
        subtitle: Text(
          group['lastMessage'] as String? ?? '暂无消息',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black38),
        ),
        trailing: StreamBuilder<int>(
          stream: chatService.getRoomUnreadCount(group['id'] as String, myUid),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            if (count > 0) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final UserProfile contact;
  final String myUid;
  final ChatService chatService;
  final bool isDark;
  final VoidCallback onTap;

  const _ContactCard({
    required this.contact,
    required this.myUid,
    required this.chatService,
    required this.isDark,
    required this.onTap,
  });

  static const _avatarGradients = [
    [Color(0xFFFF9500), Color(0xFFFF6B00)],
    [Color(0xFF5856D6), Color(0xFFAF52DE)],
    [Color(0xFFFF2D55), Color(0xFFFF6482)],
    [Color(0xFF007AFF), Color(0xFF5AC8FA)],
    [Color(0xFF34C759), Color(0xFF30D158)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradientIndex = contact.displayName.hashCode.abs() % _avatarGradients.length;
    final gradient = _avatarGradients[gradientIndex];

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      opacity: isDark ? 0.08 : 0.55,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: gradient),
          ),
          child: Center(
            child: Text(
              contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          contact.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
        subtitle: Text(
          contact.email,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black38),
        ),
        trailing: StreamBuilder<int>(
          stream: chatService.getUnreadCount(myUid, contact.uid),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            if (count > 0) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}
