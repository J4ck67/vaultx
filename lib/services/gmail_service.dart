import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis/gmail/v1.dart';
import 'auth_service.dart';

class GmailService {
  Future<List<BillMetadata>> fetchRecentBills() async {
    final gmailApi = await AuthService.instance.getGmailApiClient();
    if (gmailApi == null) {
      print("❌ Gmail API Client is null. User might not be signed in.");
      return [];
    }

    // 🔍 STEP 1: Broaden the query for testing
    // We removed 'subject:(...)' to ensure we find ANY PDF first.
    String query = 'has:attachment filename:pdf newer_than:365d';

    List<BillMetadata> bills = [];

    try {
      print("🔍 Searching Gmail with query: $query");
      final response = await gmailApi.users.messages.list('me', q: query, maxResults: 10);

      if (response.messages == null || response.messages!.isEmpty) {
        print("⚠️ No messages matched the query.");
        return [];
      }

      print("✅ Found ${response.messages!.length} emails. Scanning for PDFs...");

      for (var msg in response.messages!) {
        final fullMessage = await gmailApi.users.messages.get('me', msg.id!);
        final billData = await _processMessage(gmailApi, fullMessage);

        if (billData != null) {
          bills.add(billData);
          print("📄 Added bill: ${billData.subject}");
        } else {
          print("⏭️ Skipped email: ID ${msg.id} (No valid PDF found in parts)");
        }
      }
    } catch (e) {
       print("❌ Gmail Fetch Error: $e");
    }

    return bills;
  }

  Future<BillMetadata?> _processMessage(GmailApi api, Message message) async {
    // 1. Get Subject and Date
    String subject = "Unknown Document";
    String dateStr = "";

    message.payload?.headers?.forEach((header) {
      if (header.name == 'Subject') subject = header.value ?? "No Subject";
      if (header.name == 'Date') dateStr = header.value ?? "";
    });

    // 2. Find PDF Part (Recursive)
    MessagePart? pdfPart = _findPdfPart(message.payload?.parts);

    // 3. Download if found
    if (pdfPart != null && pdfPart.body?.attachmentId != null) {
      try {
        MessagePartBody attachment = await api.users.messages.attachments.get(
            'me',
            message.id!,
            pdfPart.body!.attachmentId!
        );

        if (attachment.data != null) {
          return BillMetadata(
            id: message.id!,
            subject: subject,
            date: dateStr,
            filename: pdfPart.filename ?? "document.pdf",
            fileBytes: base64Url.decode(attachment.data!),
          );
        }
      } catch (e) {
        print("⚠️ Failed to download attachment for $subject: $e");
      }
    }
    return null;
  }

  // 🔄 RECURSIVE HELPER: Digs through layers to find PDF
  MessagePart? _findPdfPart(List<MessagePart>? parts) {
    if (parts == null) return null;

    for (var part in parts) {
      // Check if this part is a PDF
      if (part.mimeType == 'application/pdf' ||
          (part.filename != null && part.filename!.toLowerCase().endsWith('.pdf'))) {
        return part;
      }

      // If not, check if it has nested parts (Dig deeper)
      if (part.parts != null) {
        var foundNested = _findPdfPart(part.parts);
        if (foundNested != null) return foundNested;
      }
    }
    return null;
  }

  // ──────── 🟢 NEW: FETCH RAW EMAIL TEXT FOR ALERTS ────────
  Future<List<GmailTextAlert>> fetchTextAlerts() async {
    final gmailApi = await AuthService.instance.getGmailApiClient();
    if (gmailApi == null) return [];

    String query = 'recharge OR expiring OR reminder OR policy OR autopay newer_than:30d';
    List<GmailTextAlert> alerts = [];

    try {
      print("🔍 Searching Gmail Text Alerts with query: $query");
      final response = await gmailApi.users.messages.list('me', q: query, maxResults: 15);

      if (response.messages == null || response.messages!.isEmpty) return [];

      for (var msg in response.messages!) {
        final fullMessage = await gmailApi.users.messages.get('me', msg.id!);
        
        String subject = "Alert";
        fullMessage.payload?.headers?.forEach((header) {
          if (header.name == 'Subject') subject = header.value ?? "Alert";
        });

        String snippet = fullMessage.snippet ?? "";
        
        if (snippet.isNotEmpty && (snippet.toLowerCase().contains("recharge") || 
                                   snippet.toLowerCase().contains("due") || 
                                   snippet.toLowerCase().contains("policy"))) {
          
          // Basic Date Extractor
          final dateRegex = RegExp(r'\b(\d{1,2}[-/\s](?:[a-zA-Z]{3,4}|\d{1,2})[-/\s]\d{2,4})\b');
          final dateMatch = dateRegex.firstMatch(snippet);
          String? extractedDateStr = dateMatch?.group(1);

          alerts.add(GmailTextAlert(
            id: msg.id!,
            subject: subject,
            snippet: snippet,
            extractedDate: extractedDateStr,
          ));
        }
      }
    } catch (e) {
      print("❌ Gmail Text Fetch Error: $e");
    }

    return alerts;
  }
}

// 🟢 NEW: Class to hold raw text alerts
class GmailTextAlert {
  final String id;
  final String subject;
  final String snippet;
  final String? extractedDate;

  GmailTextAlert({
    required this.id,
    required this.subject,
    required this.snippet,
    this.extractedDate,
  });
}

class BillMetadata {
  final String id;
  final String subject;
  final String date;
  final String filename;
  final Uint8List fileBytes;

  BillMetadata({
    required this.id,
    required this.subject,
    required this.date,
    required this.filename,
    required this.fileBytes,
  });
}