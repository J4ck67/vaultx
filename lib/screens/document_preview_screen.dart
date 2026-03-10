
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:mime/mime.dart';

class DocumentPreviewScreen extends StatelessWidget {
final File file;

const DocumentPreviewScreen({super.key, required this.file});

bool get isImage {
final mime = lookupMimeType(file.path);
return mime != null && mime.startsWith("image/");
}

bool get isPdf {
final mime = lookupMimeType(file.path);
return mime == "application/pdf";
}

@override
Widget build(BuildContext context) {

debugPrint("Preview file path: ${file.path}");
debugPrint("Detected mime: ${lookupMimeType(file.path)}");

return Scaffold(
appBar: AppBar(title: Text(file.path.split('/').last)),

body: isImage
? Center(
child: Image.file(
file,
fit: BoxFit.contain,
),
)

    : isPdf
? PDFView(filePath: file.path)

    : Center(
child: ElevatedButton(
onPressed: () => OpenFilex.open(file.path),
child: const Text("Open file"),
),
),
);
}
}
