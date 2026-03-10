import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class OcrService {
  /// 🔑 Replace with your Google Vision API key
  static const String apiKey = "AIzaSyDddMaJ2BemsOUZA0cTDXVjSeJD-011eJU";

  static String get apiUrl =>
      "https://vision.googleapis.com/v1/images:annotate?key=$apiKey";

  /*──────────────── OCR ENTRY ────────────────*/

  static Future<String> extractText(File file) async {
    final processedImage = await _preprocessImage(file);

    final bytes = await processedImage.readAsBytes();

    final base64Image = base64Encode(bytes);

    final requestBody = jsonEncode({
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {"type": "DOCUMENT_TEXT_DETECTION"},
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw Exception("Vision API error ${response.statusCode}");
    }

    final data = jsonDecode(response.body);

    return data["responses"][0]["fullTextAnnotation"]?["text"] ?? "";
  }

  /*──────────────── IMAGE PREPROCESSING ────────────────*/

  static Future<File> _preprocessImage(File file) async {
    final bytes = await file.readAsBytes();

    // To prevent out of memory issues, decode only to check size if needed,
    // but the Vision API handles large files reasonably well if they are < 20MB.
    // For now, we will just send the raw image bytes to avoid quality loss.

    // Check if the image size is too large for base64 encoding (e.g. > 4MB)
    // Vision API limit is 20MB, but base64 inflates it.
    if (bytes.length > 5 * 1024 * 1024) {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // Only resize if it's huge
        final processed = img.copyResize(decoded, width: 2000);

        final newFile = File(
          "${file.parent.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );

        await newFile.writeAsBytes(img.encodeJpg(processed, quality: 85));
        return newFile;
      }
    }

    // Otherwise, return original file without quality loss
    return file;
  }

  /*──────────────── SMART AMOUNT DETECTOR ────────────────*/

  static double guessAmount(String text) {
    if (text.isEmpty) return 0;

    // Normalize spacing and newlines for easier scanning
    String normalizedText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // Ordered by highest confidence
    List<String> keywords = [
      "അടയ്ക്കേണ്ട തുക", // Malayalam
      "grand total",
      "total amount due",
      "amount due",
      "net amount",
      "payable",
      "total amount",
      "total",
      "balance",
      "amount",
    ];

    // Regex to find numbers: catches optional Rs/₹/INR prefix, optional spaces, commas, decimals.
    // E.g., captures "rs. 1,234.50" or "₹ 1234"
    // Negative lookahead (?!\s*%) explicitly ensures the number is NOT followed by a percentage sign.
    RegExp numberRegex = RegExp(
      r'(?:rs\.?|inr|₹)?\s*\b(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\b(?!\s*%)',
    );

    for (String keyword in keywords) {
      // Find all occurrences of the keyword
      int index = normalizedText.lastIndexOf(keyword);
      if (index != -1) {
        // Look ahead 50 characters, tightly bounding to the keyword
        String nearby = normalizedText.substring(
          index + keyword.length,
          (index + keyword.length + 50).clamp(0, normalizedText.length),
        );

        final match = numberRegex.firstMatch(nearby);
        if (match != null) {
          // match.group(1) is safely just the digits, ignoring 'rs' or '₹'
          String cleanNumber = match.group(1)!.replaceAll(",", "");
          double? value = double.tryParse(cleanNumber);

          // We return the very first valid amount found next to our highest priority keyword
          if (value != null && value > 0 && value < 100000) {
            return value;
          }
        }
      }
    }

    // Fallback: if no keywords worked, just find the largest monetary-looking number in the bottom half of the bill
    int halfLength = (normalizedText.length / 2).floor();
    String bottomHalf = normalizedText.substring(halfLength);

    final matches = numberRegex.allMatches(bottomHalf);

    List<double> allNumbers = [];
    for (final match in matches) {
      String cleanNumber = match.group(1)!.replaceAll(",", "");
      double? value = double.tryParse(cleanNumber);
      // More restrictive bound to avoid huge IDs or meter counts
      if (value != null && value > 10 && value < 50000) {
        allNumbers.add(value);
      }
    }

    if (allNumbers.isNotEmpty) {
      // Sort and take the absolute highest
      allNumbers.sort();
      return allNumbers.last;
    }

    return 0;
  }

  /*──────────────── DATE DETECTOR ────────────────*/

  static String? guessDate(String text) {
    if (text.isEmpty) return null;

    // Normalize spacing and newlines
    String normalizedText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    List<String> keywords = [
      "disconnection date",
      "disconnect date", // Disconnection date in Malayalam
      "വിച്ഛേദന ",
      "due date",
      "last date without fine",
      "last date",
      "pay by",
      "പിഴ  ",
      "due by",
      "payable before",
      "date",
    ];

    // Improved date regex: supports DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    // Also supports short years (DD/MM/YY) and Month names (DD MMM YYYY) roughly
    RegExp dateRegex = RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b');

    // Trying to find date near a due date keyword
    for (String keyword in keywords) {
      int index = normalizedText.lastIndexOf(keyword);
      if (index != -1) {
        // Broaden search radius
        String nearby = normalizedText.substring(
          index,
          (index + 80).clamp(0, normalizedText.length),
        );

        // Find ALL dates near keyword, to grab the LAST FINAL date, we take the last matched date near the last matched keyword.
        final matches = dateRegex.allMatches(nearby);
        if (matches.isNotEmpty) {
          return matches.last.group(0);
        }
      }
    }

    final matches = dateRegex.allMatches(normalizedText);

    if (matches.isEmpty) return null;

    // Usually the last date on a bill is the payment/due date, but occasionally it's generated date.
    return matches.last.group(0);
  }
}
