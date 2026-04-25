import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/contacts_screen.dart';
import 'services/chat_service.dart';

Future<void> _seedWhitelist() async {
  final ref = FirebaseFirestore.instance.collection('whitelist');
  final members = {
    'alanxu1982@gmail.com': 'Alan',
    'xuzixiang2010@gmail.com': 'Justin',
    'gong_cheng76@hotmail.com': 'Shirley',
    '85626795@qq.com': '张磊',
    'wangshuyi563@gmail.com': 'Shuyi',
  };
  for (final entry in members.entries) {
    await ref.doc(entry.key).set({
      'displayName': entry.value,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

Future<void> _syncProfileNames() async {
  final firestore = FirebaseFirestore.instance;
  final results = await Future.wait([
    firestore.collection('users').get(),
    firestore.collection('whitelist').get(),
  ]);
  final usersSnap = results[0];
  final whitelistSnap = results[1];

  final whiteMap = <String, String>{};
  for (final doc in whitelistSnap.docs) {
    final name = doc.data()['displayName'];
    if (name is String) whiteMap[doc.id] = name;
  }

  await Future.wait(usersSnap.docs.map((userDoc) async {
    final email = userDoc.data()['email'] as String?;
    if (email == null) return;
    final newName = whiteMap[email];
    if (newName != null && newName != userDoc.data()['displayName']) {
      await userDoc.reference.update({'displayName': newName});
    }
  }));
}

Future<void> _renameFamilyGroup() async {
  final doc = FirebaseFirestore.instance.collection('chatRooms').doc('family_group');
  final snap = await doc.get();
  if (snap.exists && snap.data()?['name'] != '聊天室') {
    await doc.update({'name': '聊天室'});
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const JustinChatApp());

  Future.microtask(() async {
    try {
      await _seedWhitelist();
      await _syncProfileNames();
      await _renameFamilyGroup();
    } catch (_) {}
  });
}

class JustinChatApp extends StatelessWidget {
  const JustinChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Justin Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
          primary: const Color(0xFF007AFF),
          surface: const Color(0xFFF2F2F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF0A84FF),
          surface: const Color(0xFF1C1C1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<void> _ensureUserProfile(User user) async {
    final firestore = FirebaseFirestore.instance;
    final email = user.email?.toLowerCase().trim() ?? '';
    final whiteDoc = await firestore.collection('whitelist').doc(email).get();
    final name = whiteDoc.data()?['displayName'] ?? email.split('@').first;

    await firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'displayName': name,
      'avatarUrl': null,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await ChatService().ensureFamilyGroup(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          _ensureUserProfile(snapshot.data!);
          return const ContactsScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
