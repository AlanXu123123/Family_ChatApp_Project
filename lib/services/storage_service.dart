import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  static const _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'bmp': 'image/bmp',
  };

  Future<String> uploadImageBytes(Uint8List bytes, String fileName) async {
    final ext = fileName.split('.').last.toLowerCase();
    final contentType = _mimeTypes[ext] ?? 'image/jpeg';
    final ref = _storage.ref().child('images/${_uuid.v4()}.$ext');
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadVoice(String filePath) async {
    final ext = filePath.split('.').last;
    final ref = _storage.ref().child('voices/${_uuid.v4()}.$ext');
    final metadata = SettableMetadata(contentType: 'audio/$ext');
    final snapshot = await ref.putString(
      filePath,
      metadata: metadata,
    );
    return await snapshot.ref.getDownloadURL();
  }
}
