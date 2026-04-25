import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _whitelistRef =>
      _firestore.collection('whitelist');

  Future<bool> isAllowedEmail(String email) async {
    final doc = await _whitelistRef.doc(email.toLowerCase().trim()).get();
    return doc.exists;
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await _usersRef.doc(user.uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<String> getCurrentUserName() async {
    final profile = await getCurrentUserProfile();
    return profile?.displayName ?? currentUser?.email?.split('@').first ?? '?';
  }

  Stream<List<UserProfile>> getAllUsers() {
    return _usersRef.snapshots().map((snap) =>
        snap.docs.map((d) => UserProfile.fromMap(d.data())).toList());
  }

  Future<String?> signIn(String email, String password) async {
    final normalizedEmail = email.toLowerCase().trim();
    final allowed = await isAllowedEmail(normalizedEmail);
    if (!allowed) {
      return '此邮箱不在家庭成员列表中';
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        final doc = await _usersRef.doc(user.uid).get();
        if (!doc.exists) {
          final whiteDoc = await _whitelistRef.doc(normalizedEmail).get();
          final name = whiteDoc.data()?['displayName'] ??
              normalizedEmail.split('@').first;
          await _usersRef.doc(user.uid).set(UserProfile(
            uid: user.uid,
            email: normalizedEmail,
            displayName: name,
            joinedAt: DateTime.now(),
          ).toMap());
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return '账号不存在，请检查邮箱';
        case 'wrong-password':
        case 'invalid-credential':
          return '密码不正确';
        case 'too-many-requests':
          return '登录尝试次数过多，请稍后再试';
        default:
          return '登录失败: ${e.message}';
      }
    } catch (e) {
      return '登录失败: $e';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
