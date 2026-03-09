import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 import 'bills/kseb_receipt_parser.dart'; //

class FileUploadService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> uploadBill({
    required File file,
    required String category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final uid = user.uid;

    /* ─────────────── 1. PREPARE PATH ─────────────── */
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('documents')
        .doc();

    // Safe Extension Logic
    String extension = ".pdf";
    if (file.path.contains('.')) {
      extension = file.path.substring(file.path.lastIndexOf('.'));
    }

    // 🔴 UPDATED: Uploading to 'uploads/' folder
    final storagePath = 'uploads/$uid/$category/${docRef.id}$extension';

    /* ─────────────── 2. UPLOAD FILE ─────────────── */
    try {
      final ref = _storage.ref(storagePath);
      await ref.putFile(file);

      final downloadUrl = await ref.getDownloadURL();

      /* ─────────────── 3. SAVE METADATA ─────────────── */
      await docRef.set({
        'id': docRef.id,
        'category': category,
        'originalName': file.path.split('/').last,
        'storagePath': storagePath, // Saved correctly as 'uploads/...'
        'fileUrl': downloadUrl,
        'isEncrypted': false,
        'size': await file.length(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Uploaded to: $storagePath");

    } on FirebaseException catch (e) {
      print("❌ Firebase Error: ${e.message}");
      throw Exception("Upload failed: ${e.message}");
    }
  }
}