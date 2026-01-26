import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../services/file_upload_service.dart';


class UploadBillButton extends StatelessWidget {
  const UploadBillButton({super.key});

  /*──────────────── DOCUMENT TYPES ────────────────*/
  static const List<_DocType> _docTypes = [
    _DocType("Electricity", Icons.flash_on),
    _DocType("Rent", Icons.home),
    _DocType("Internet", Icons.wifi),
    _DocType("Insurance", Icons.security),
    _DocType("Subscription", Icons.subscriptions),
    _DocType("Other", Icons.insert_drive_file),
  ];


  /*──────────────── CAMERA ────────────────*/
  Future<void> _scanCamera(BuildContext context, String type) async {
    final picker = ImagePicker();
    final XFile? image =
    await picker.pickImage(source: ImageSource.camera, imageQuality: 90);

    if (image != null) {
      try {
        await FileUploadService.uploadBill(
          file: File(image.path),
          category: type,
        );
        _snack(context, "Uploaded successfully");
      } catch (e) {
        _snack(context, "Upload failed");
      }
    }
  }



  /*──────────────── FILE PICKER ────────────────*/
  Future<void> _pickFile(BuildContext context, String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        await FileUploadService.uploadBill(
          file: File(result.files.single.path!),
          category: type,
        );
        _snack(context, "Uploaded successfully");
      } catch (e) {
        print("❌ Upload error: $e");
        _snack(context, "Upload failed: ${e.toString()}");
      }

    }
  }


  /*──────────────── SOURCE PICKER ────────────────*/
  void _openSourcePicker(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add $type bill",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _ActionTile(
                icon: Icons.camera_alt,
                label: "Scan using Camera",
                onTap: () {
                  Navigator.pop(context);
                  _scanCamera(context, type);
                },
              ),

              _ActionTile(
                icon: Icons.upload_file,
                label: "Upload from Files",
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(context, type);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*──────────────── DOC TYPE PICKER ────────────────*/
  void _openDocTypePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select document type",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                itemCount: _docTypes.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemBuilder: (_, i) {
                  final item = _docTypes[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _openSourcePicker(context, item.label);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*──────────────── FAB ────────────────*/
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _openDocTypePicker(context),
      child: const Icon(Icons.add, size: 28),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(msg),
        ),
      );
  }
}

/*──────────────── SUPPORT CLASSES ────────────────*/

class _DocType {
  final String label;
  final IconData icon;
  const _DocType(this.label, this.icon);
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
