import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'encryption_service.dart';

class FileViewService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<File> downloadAndDecrypt({
    required String storagePath,
    required String originalName,
  }) async {
    // 1️⃣ Download encrypted bytes from Firebase Storage
    final ref = _storage.ref(storagePath);
    final Uint8List? encryptedBytes = await ref.getData();

    if (encryptedBytes == null) {
      throw Exception("Failed to download encrypted file");
    }

    // 2️⃣ Decrypt bytes → temp file
    final decryptedFile = await EncryptionService.decryptFile(
      encryptedBytes: encryptedBytes,
      originalFileName: originalName,
    );

    return decryptedFile;
  }
}
