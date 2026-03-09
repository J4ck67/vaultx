import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class FileViewService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<File> downloadFile({
    required String storagePath,
    required String originalName,
  }) async {
    try {
      // 1️⃣ Download raw bytes from Firebase Storage
      final ref = _storage.ref(storagePath);
      final Uint8List? fileBytes = await ref.getData();

      if (fileBytes == null) {
        throw Exception("File is empty (0 bytes).");
      }

      // 2️⃣ Fix Filename: Ensure it has an extension (Default to .pdf)
      String safeFileName = originalName;
      if (!safeFileName.toLowerCase().contains('.')) {
        safeFileName = "$safeFileName.pdf";
      }

      // 3️⃣ Get temporary directory and write file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$safeFileName');

      return await file.writeAsBytes(fileBytes);

    } catch (e) {
      print("❌ Download Error: $e");
      rethrow; // Pass error back to UI
    }
  }
}