import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final File file;

  const DocumentPreviewScreen({super.key, required this.file});

  bool get isImage =>
      file.path.endsWith('.jpg') ||
          file.path.endsWith('.png') ||
          file.path.endsWith('.jpeg');

  bool get isPdf => file.path.endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(file.path.split('/').last)),
      body: isImage
          ? Center(child: Image.file(file))
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
