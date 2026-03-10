
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/ocr_verification_screen.dart';

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

/*──────────────── MAIN UI ────────────────*/

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.white,
appBar: AppBar(
title: const Text(
"Select Category",
style: TextStyle(fontWeight: FontWeight.bold),
),
backgroundColor: const Color(0xFFFDD53F),
elevation: 0,
foregroundColor: Colors.black,
),
body: Container(
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

Expanded(
child: GridView.builder(
physics: const BouncingScrollPhysics(),
itemCount: _docTypes.length,
gridDelegate:
const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 2,
mainAxisSpacing: 16,
crossAxisSpacing: 16,
childAspectRatio: 1.3,
),
itemBuilder: (_, i) {
final item = _docTypes[i];

return _CategoryCard(
item: item,
onTap: () =>
_openSourcePicker(context, item.label),
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

/*──────────────── SOURCE PICKER ────────────────*/

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
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold),
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
Navigator.pop(context);
_scanCamera(context, type);
},
),

_SourceOption(
icon: Icons.folder_open_rounded,
label: "Files",
color: Colors.purple,
onTap: () {
Navigator.pop(context);
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

/*──────────────── CAMERA CAPTURE ────────────────*/

  Future<void> _scanCamera(BuildContext context, String type) async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (image == null) return;

    final originalFile = File(image.path);

    /// Forcefully write the image as a definitive .jpg file to avoid 
    /// extension issues that make the preview screen treat it as a PDF
    final tempDir = await getTemporaryDirectory();
    final fixedPath = "${tempDir.path}/camera_${DateTime.now().millisecondsSinceEpoch}.jpg";
    
    // Read bytes and write to the new explicit JPG path instead of just copying
    final bytes = await originalFile.readAsBytes();
    final fixedFile = File(fixedPath);
    await fixedFile.writeAsBytes(bytes);

    if (!context.mounted) return;

    _routeToVerification(context, fixedFile, type);
  }

/*──────────────── FILE PICKER ────────────────*/

Future<void> _pickFile(BuildContext context, String type) async {

final result = await FilePicker.platform.pickFiles(
type: FileType.custom,
allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
);

if (result == null) return;

final path = result.files.single.path;

if (path == null) return;

final file = File(path);

if (!context.mounted) return;

_routeToVerification(context, file, type);
}

/*──────────────── ROUTE TO OCR ────────────────*/

void _routeToVerification(
BuildContext context,
File file,
String type,
) {

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

/*──────────────── HELPER MODELS ────────────────*/

class _DocType {
final String label;
final IconData icon;
final Color color;

const _DocType(this.label, this.icon, this.color);
}

/*──────────────── CATEGORY CARD ────────────────*/

class _CategoryCard extends StatelessWidget {

final _DocType item;
final VoidCallback onTap;

const _CategoryCard({
required this.item,
required this.onTap,
});

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
child: Icon(item.icon,
size: 32,
color: item.color),
),

const SizedBox(height: 12),

Text(
item.label,
style: const TextStyle(
fontWeight: FontWeight.w600,
fontSize: 14,
),
),
],
),
),
);
}
}

/*──────────────── SOURCE OPTION ────────────────*/

class _SourceOption extends StatelessWidget {

final IconData icon;
final String label;
final Color color;
final VoidCallback onTap;

const _SourceOption({
required this.icon,
required this.label,
required this.color,
required this.onTap,
});

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
child: Icon(icon,
size: 32,
color: color),
),

const SizedBox(height: 8),

Text(
label,
style: const TextStyle(
fontWeight: FontWeight.w500,
),
),
],
),
);
}
}
