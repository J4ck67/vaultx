import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
// 🟢 Notice we removed Firebase Storage/Firestore imports because the Verification Screen handles that now!
import '../screens/ocr_verification_screen.dart'; // 🟢 Import your new verification screen

class UploadBillButton extends StatelessWidget {
  const UploadBillButton({super.key});

  /*──────────────── DOCUMENT TYPES ────────────────*/
  static const List<_DocType> _docTypes = [
    _DocType("Electricity", Icons.flash_on, Colors.amber),
    _DocType("Rent", Icons.home, Colors.blueAccent),
    _DocType("Internet", Icons.wifi, Colors.purpleAccent),
    _DocType("Insurance", Icons.security, Colors.green),
    _DocType("Subscription", Icons.subscriptions, Colors.redAccent),
    _DocType("Other", Icons.insert_drive_file, Colors.grey),
  ];

  /*──────────────── MAIN UI (The Screen) ────────────────*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Select Category", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDD53F),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDD53F), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "What type of bill are you uploading?",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // THE GRID OF CATEGORIES
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _docTypes.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    itemBuilder: (_, i) {
                      final item = _docTypes[i];
                      return _CategoryCard(
                        item: item,
                        onTap: () => _openSourcePicker(context, item.label),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*──────────────── SOURCE PICKER (Modal) ────────────────*/
  void _openSourcePicker(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Upload $type Bill",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: "Camera",
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context); // Close modal
                      _scanCamera(context, type);
                    },
                  ),
                  _SourceOption(
                    icon: Icons.folder_open_rounded,
                    label: "Files",
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context); // Close modal
                      _pickFile(context, type);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /*──────────────── LOGIC: CAMERA (WITH COMPRESSION) ────────────────*/
  Future<void> _scanCamera(BuildContext context, String type) async {
    final picker = ImagePicker();

    // 🟢 MASSIVE SPEED UP: Compress the image here before OCR!
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,      // Shrinks file size
      maxWidth: 1200,        // Caps resolution
    );

    if (image != null) {
      if (!context.mounted) return;
      _routeToVerification(context, File(image.path), type);
    }
  }

  /*──────────────── LOGIC: FILE PICKER ────────────────*/
  Future<void> _pickFile(BuildContext context, String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      _routeToVerification(context, File(result.files.single.path!), type);
    }
  }

  /*──────────────── LOGIC: ROUTE TO OCR VERIFICATION ────────────────*/
  void _routeToVerification(BuildContext context, File file, String type) {
    // 🟢 Instead of uploading here, we pass it to the new Verification Screen!
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrVerificationScreen(
          documentFile: file,
          category: type,
        ),
      ),
    );
  }
}

/*──────────────── HELPER WIDGETS ────────────────*/

class _DocType {
  final String label;
  final IconData icon;
  final Color color;
  const _DocType(this.label, this.icon, this.color);
}

class _CategoryCard extends StatelessWidget {
  final _DocType item;
  final VoidCallback onTap;

  const _CategoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 32, color: item.color),
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}