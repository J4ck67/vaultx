import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';

class FileUploadService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> uploadBill({
    required File file,
    required String category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    final uid = user.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final docId = _firestore
        .collection('users')
        .doc(uid)
        .collection('documents')
        .doc()
        .id;

    /* ─────────────── 1. ENCRYPT FILE ─────────────── */
    final encryptedFile = await EncryptionService.encryptFile(file);

    /* ─────────────── 2. UPLOAD TO STORAGE ─────────────── */
    final storagePath = 'uploads/$uid/$category/$docId.enc';
    final ref = _storage.ref(storagePath);

    await ref.putFile(encryptedFile);

    /* ─────────────── 3. SAVE METADATA ONLY ─────────────── */
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('documents')
        .doc(docId)
        .set({
      'id': docId,
      'category': category,
      'originalName': file.path.split('/').last,
      'storagePath': storagePath,
      'encrypted': true,
      'size': await encryptedFile.length(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    print("🔥 Firestore document added for $docId");

  }
}
