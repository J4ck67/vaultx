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
  bool _isUploading = false;

  String _rawExtractedText = "";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  late bool isPdf;

  @override
  void initState() {
    super.initState();

    // Verify it's actually a PDF. If it's a camera image, the extension might be .jpg or missing, but it's not a PDF.
    String pathLower = widget.documentFile.path.toLowerCase();
    isPdf = pathLower.endsWith('.pdf');

    _nameController.text = "${widget.category} Bill";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runOcrScanner();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /*──────── RUN OCR ────────*/

  Future<void> _runOcrScanner() async {
    try {
      final text = await OcrService.extractText(
        widget.documentFile,
      ).timeout(const Duration(seconds: 20));

      final amount = OcrService.guessAmount(text);
      final date = OcrService.guessDate(text);

      if (!mounted) return;

      setState(() {
        _rawExtractedText = text;

        if (amount > 0 && amount < 100000) {
          _amountController.text = amount.toStringAsFixed(2);
        }

        if (date != null) {
          _dateController.text = date;
        }

        _isScanning = false;
      });

      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No readable text detected.")),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isScanning = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not read document automatically.")),
      );
    }
  }

  /*──────── SAVE TO FIREBASE ────────*/

  Future<void> _saveToVault() async {
    if (_isUploading) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => _isUploading = true);

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
            Text(
              "Securing in Vault...",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    try {
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${widget.documentFile.path.split('/').last}";

      final storageRef = FirebaseStorage.instance.ref().child(
        "users/${user.uid}/documents/${widget.category}/$fileName",
      );

      await storageRef.putFile(widget.documentFile);

      final downloadUrl = await storageRef.getDownloadURL();

      String finalName = _nameController.text.trim();
      if (!finalName.toLowerCase().contains('.')) {
        finalName += isPdf ? '.pdf' : '.jpg';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add({
            'originalName': finalName,
            'name': _nameController.text.trim(),
            'category': widget.category,
            'amount': double.tryParse(_amountController.text.trim()) ?? 0.0,
            'date': _dateController.text.trim(),
            'ocrText': _rawExtractedText,
            'fileUrl': downloadUrl,
            'storagePath': storageRef.fullPath,
            // Make sure it saves explicitly as image if it's not a PDF
            'fileType': isPdf ? 'pdf' : 'image',
            'createdAt': FieldValue.serverTimestamp(),
            'searchIndex': _rawExtractedText.toLowerCase(),
          });

      if (!mounted) return;

      Navigator.pop(context);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _UploadSuccessDialog(),
      );

      if (!mounted) return;

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /*──────── UI ────────*/

  @override
  Widget build(BuildContext context) {
    bool valid =
        _nameController.text.isNotEmpty && _amountController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),

      appBar: AppBar(
        title: const Text(
          "Verify Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    'https://lottie.host/5b2210e3-ac11-44eb-bdf7-e17f0ec6fd93/s40P910F6z.json',
                    height: 150,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.document_scanner, size: 80, color: Colors.amber),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "AI is analyzing your document...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* DOCUMENT PREVIEW */
                  Center(
                    child: Container(
                      height: 180,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),

                      child: isPdf
                          ? const Icon(
                              Icons.picture_as_pdf,
                              size: 64,
                              color: Colors.red,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                widget.documentFile,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  _buildTextField(
                    "Document Name",
                    _nameController,
                    Icons.description,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    "Amount Due (₹)",
                    _amountController,
                    Icons.currency_rupee,
                    isNumber: true,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    "Due Date",
                    _dateController,
                    Icons.calendar_today,
                  ),

                  const SizedBox(height: 30),

                  if (_rawExtractedText.isNotEmpty)
                    ExpansionTile(
                      title: const Text("View OCR Text"),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_rawExtractedText),
                        ),
                      ],
                    ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: valid && !_isUploading ? _saveToVault : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Confirm & Vault",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /*──────── TEXT FIELD ────────*/

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.amber[700]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

/*──────── SUCCESS DIALOG ────────*/

class _UploadSuccessDialog extends StatefulWidget {
  const _UploadSuccessDialog();

  @override
  State<_UploadSuccessDialog> createState() => _UploadSuccessDialogState();
}

class _UploadSuccessDialogState extends State<_UploadSuccessDialog> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.pop(context);
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
              child: Lottie.network(
                'https://lottie.host/790757cc-0ca2-4217-be08-3001ad394ba0/GjL9T2g4S7.json',
                repeat: false,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.check_circle, size: 80, color: Colors.green),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "Vault Secured!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
