import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OcrService {

  // 🔑 Paste your NEW Google Cloud API Key here
  static const String _visionApiKey = 'AIzaSyBZKZ_p9Rj7YtIcyeO5JJZW-9YajXbIT1E';
  static const String _visionApiUrl = 'https://vision.googleapis.com/v1/images:annotate?key=$_visionApiKey';

  /// Extracts all text from either an Image (via Cloud Vision) or a PDF
  static Future<String> extractText(File file) async {
    try {
      final path = file.path.toLowerCase();

      // ──────── 1. HANDLE PDF DOCUMENTS (Local Extraction) ────────
      if (path.endsWith('.pdf')) {
        final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
        String text = PdfTextExtractor(document).extractText();
        document.dispose();

        debugPrint("📄 PDF Text Extracted: ${text.length} characters");
        return text;
      }
      // ──────── 2. HANDLE IMAGES (Cloud Vision API) ────────
      else if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
        return await _analyzeImageWithCloudVision(file);
      }

      return "";
    } catch (e) {
      debugPrint("❌ OCR Error: $e");
      return "";
    }
  }

  /// ☁️ SENDS IMAGE TO GOOGLE CLOUD VISION API
  static Future<String> _analyzeImageWithCloudVision(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      Map<String, dynamic> requestPayload = {
        "requests": [
          {
            "image": {
              "content": base64Image
            },
            "features": [
              {
                "type": "DOCUMENT_TEXT_DETECTION"
              }
            ]
          }
        ]
      };

      final response = await http.post(
        Uri.parse(_visionApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestPayload),
      );

      // 🟢 DEBUG: PRINT THE RAW RESPONSE TO THE CONSOLE
      debugPrint("====== 🔍 RAW CLOUD VISION RESPONSE ======");
      debugPrint(response.body);
      debugPrint("==========================================");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['responses'] != null &&
            responseData['responses'][0]['textAnnotations'] != null) {

          String extractedText = responseData['responses'][0]['textAnnotations'][0]['description'];

          debugPrint("☁️ Cloud Vision Extracted: \n$extractedText");
          return extractedText;
        } else {
          debugPrint("☁️ Cloud Vision found no text in this image.");
          return "";
        }
      } else {
        debugPrint("☁️ Cloud Vision API Error: ${response.statusCode} - ${response.body}");
        return "";
      }
    } catch (e) {
      debugPrint("☁️ Cloud Vision Request Failed: $e");
      return "";
    }
  }

  /// 🧠 SMART AMOUNT DETECTOR
  static double guessAmount(String rawText) {
    if (rawText.isEmpty) return 0.0;

    String text = rawText.toLowerCase().replaceAll(RegExp(r',(?=\d{3})'), '');
    RegExp amountRegex = RegExp(r'\b\d+(\.\d{1,2})?\b');
    List<String> keywords = [' grand total', 'amount due', 'amount','total amount', 'pay', 'due', '₹', 'rs', 'inr'];

    List<double> foundAmounts = [];

    for (String keyword in keywords) {
      int index = text.indexOf(keyword);
      if (index != -1) {
        String substring = text.substring(index, (index + 30).clamp(0, text.length));
        final match = amountRegex.firstMatch(substring);

        if (match != null) {
          double? amount = double.tryParse(match.group(0)!);
          if (amount != null && amount > 0) {
            foundAmounts.add(amount);
          }
        }
      }
    }

    if (foundAmounts.isNotEmpty) {
      foundAmounts.sort();
      return foundAmounts.last;
    }

    return 0.0;
  }

  /// 📅 SMART DATE DETECTOR (NEW)
  static String? guessDate(String rawText) {
    if (rawText.isEmpty) return null;

    // Matches standard formats like 12/04/2024, 15-Oct-2024
    final dateRegex = RegExp(r'\b(\d{1,2}[-/\s](?:[a-zA-Z]{3,4}|\d{1,2})[-/\s]\d{2,4})\b');
    final matches = dateRegex.allMatches(rawText);

    if (matches.isNotEmpty) {
      return matches.last.group(1);
    }

    return null;
  }
}