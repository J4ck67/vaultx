import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract full text from image
  static Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);a
    final RecognizedText recognizedText =
    await _textRecognizer.processImage(inputImage);

    return recognizedText.text;
  }

  /// Extract structured bill data
  static Future<Map<String, dynamic>> extractBillData(File imageFile) async {
    final text = await extractText(imageFile);

    final amount = _extractAmount(text);
    final dueDate = _extractDueDate(text);
    final biller = _extractBiller(text);

    return {
      "rawText": text,
      "amount": amount,
      "dueDate": dueDate,
      "biller": biller,
    };
  }

  static String? _extractAmount(String text) {
    final regex = RegExp(r'₹?\s?(\d{1,3}(,\d{3})*(\.\d{2})?)');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  static String? _extractDueDate(String text) {
    final regex = RegExp(
        r'(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\d{1,2}\s[A-Za-z]{3,9}\s\d{2,4})');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  static String? _extractBiller(String text) {
    final lines = text.split("\n");
    if (lines.isEmpty) return null;
    return lines.firstWhere(
          (line) => line.trim().isNotEmpty,
      orElse: () => "",
    );
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
