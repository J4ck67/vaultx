import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '../services/ocr_service.dart';

class OcrVerificationScreen extends StatefulWidget {
  final File documentFile;
  final String category;

  const OcrVerificationScreen({
    super.key,
    required this.documentFile,
    required this.category,
  });

  @override
  State<OcrVerificationScreen> createState() => _OcrVerificationScreenState();
}

class _OcrVerificationScreenState extends State<OcrVerificationScreen> {
  bool _isScanning = true;
  String _rawExtractedText = "";

  // Controllers so the user can edit the AI's guesses
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set a default name based on the category they chose
    _nameController.text = "${widget.category} Bill";

    // Start the AI scanner the moment the screen opens!
    _runOcrScanner();
  }

  // ──────── 1. RUN THE AI SCANNER ────────
  Future<void> _runOcrScanner() async {
    try {
      // Send the compressed image to Google Cloud Vision
      String text = await OcrService.extractText(widget.documentFile);

      // Run your smart regex rules to find the numbers
      double amount = OcrService.guessAmount(text);
      String? date = OcrService.guessDate(text);

      if (mounted) {
        setState(() {
          _rawExtractedText = text;
          // Fill the text boxes with what the AI found
          if (amount > 0) _amountController.text = amount.toStringAsFixed(2);
          if (date != null) _dateController.text = date;

          // Stop the loading animation
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not read document automatically. Please enter details manually.")),
        );
      }
    }
  }

  // ──────── 2. FINAL UPLOAD TO FIREBASE VAULT ────────
  Future<void> _saveToVault() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show uploading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text("Securing in Vault...", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      // 1. Upload to Firebase Storage
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${widget.documentFile.path.split('/').last}";
      final storageRef = FirebaseStorage.instance.ref().child('uploads/${user.uid}/${widget.category}/$fileName');

      await storageRef.putFile(widget.documentFile);
      final downloadUrl = await storageRef.getDownloadURL();

      // 2. Save user-verified values to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add({
        'originalName': _nameController.text.trim(),
        'category': widget.category,
        'amount': double.tryParse(_amountController.text.trim()) ?? 0.0,
        'extractedDate': _dateController.text.trim(),
        'extractedText': _rawExtractedText,
        'fileType': widget.documentFile.path.endsWith('.pdf') ? 'pdf' : 'image',
        'fileUrl': downloadUrl,
        'storagePath': storageRef.fullPath,
        'createdAt': FieldValue.serverTimestamp(),
        'isEncrypted': false,
      });

      if (!mounted) return;
      Navigator.pop(context); // Close the loading dialog

      // 3. Show Success Animation
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _UploadSuccessDialog(),
      );

      if (!mounted) return;

      // 4. Go all the way back to the Home/Vault Screen!
      // We pop twice: Once to close this screen, once to close the Upload Modal
      Navigator.pop(context);
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /*──────────────── UI BUILDER ────────────────*/
  @override
  Widget build(BuildContext context) {
    bool isPdf = widget.documentFile.path.endsWith('.pdf');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Verify Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isScanning
          ? Center(
        // Show awesome scanning animation while Google Cloud is working
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network('https://lottie.host/880a4a83-bd86-455b-b9f1-a1286b978fc8/4xY8D79M9f.json', height: 150),
            const SizedBox(height: 16),
            const Text(
              "AI is analyzing your document...",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Document Image Preview
            Center(
              child: Container(
                height: 180,
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  image: isPdf ? null : DecorationImage(
                    image: FileImage(widget.documentFile),
                    fit: BoxFit.cover,
                  ),
                ),
                child: isPdf ? const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red) : null,
              ),
            ),
            const SizedBox(height: 30),

            // 2. Editable Fields (Pre-filled by AI)
            _buildTextField("Document Name", _nameController, Icons.description),
            const SizedBox(height: 16),
            _buildTextField("Amount Due (₹)", _amountController, Icons.currency_rupee, isNumber: true),
            const SizedBox(height: 16),
            _buildTextField("Due Date (DD/MM/YYYY)", _dateController, Icons.calendar_today),

            const SizedBox(height: 40),

            // 3. Confirm & Upload Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveToVault,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Confirm & Vault", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the text fields cleanly
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.amber[700]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

/*──────────────── SUCCESS ANIMATION DIALOG ────────────────*/
class _UploadSuccessDialog extends StatefulWidget {
  const _UploadSuccessDialog();
  @override
  State<_UploadSuccessDialog> createState() => _UploadSuccessDialogState();
}

class _UploadSuccessDialogState extends State<_UploadSuccessDialog> {
  @override
  void initState() {
    super.initState();
    // Auto-close after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                height: 150,
                width: 150,
                child: Lottie.network('https://lottie.host/80e9803d-2dc4-4cda-9273-0e8c07e05f6b/K3t5wE1sXv.json', repeat: false)
            ),
            const SizedBox(height: 16),
            const Text("Vault Secured!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}