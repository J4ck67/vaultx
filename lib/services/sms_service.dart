import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsReminder {
  final int id; // 🟢 NEW: Unique ID to track dismissed messages
  final String sender;
  final String message;
  final DateTime? receivedDate;
  final double? amount;
  final String? extractedDate;
  final bool isRecharge;

  SmsReminder({
    required this.id, // 🟢 NEW
    required this.sender,
    required this.message,
    this.receivedDate,
    this.amount,
    this.extractedDate,
    this.isRecharge = false,
  });
}

class SmsService {
  static final SmsQuery _query = SmsQuery();

  static Future<List<SmsReminder>> fetchFinancialSms() async {
    var permission = await Permission.sms.status;
    if (permission.isDenied) {
      permission = await Permission.sms.request();
    }

    if (permission.isGranted) {
      try {
        List<SmsMessage> messages = await _query.querySms(
          kinds: [SmsQueryKind.inbox],
          count: 150,
        );

        List<SmsReminder> financialMessages = [];

        for (var msg in messages) {
          String body = msg.body?.toLowerCase() ?? "";
          String rawBody = msg.body ?? "";

          bool isRecharge = body.contains('recharge') || body.contains('pack') || body.contains('plan') || body.contains('expire');
          bool isBill = body.contains('due') || body.contains('bill') || body.contains('payment');

          if (isRecharge || isBill) {

            // ──────── 1. SMART AMOUNT EXTRACTION ────────
            // Looks for: Rs 499, Rs.499, INR 1200, ₹500
            final amountRegex = RegExp(r'(?:rs\.?|inr|₹|amount)\s*[:=-]?\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false);
            final amountMatch = amountRegex.firstMatch(rawBody);
            double? extractedAmount;
            if (amountMatch != null && amountMatch.group(1) != null) {
              extractedAmount = double.tryParse(amountMatch.group(1)!);
            }

            // ──────── 2. SMART DATE EXTRACTION ────────
            // Looks for: 24/10/2023, 24-Oct-2023, 24 Oct 23
            final dateRegex = RegExp(r'\b(\d{1,2}[-/\s](?:[a-zA-Z]{3,4}|\d{1,2})[-/\s]\d{2,4})\b');
            final dateMatch = dateRegex.firstMatch(rawBody);
            String? extractedDateStr = dateMatch?.group(1);

            financialMessages.add(SmsReminder(
              id: msg.id ?? 0, // 🟢 FIXED: Grab the real SMS ID from Android!
              sender: msg.address ?? "Unknown",
              message: rawBody,
              receivedDate: msg.date,
              amount: extractedAmount,
              extractedDate: extractedDateStr,
              isRecharge: isRecharge,
            ));
          }
        }

        debugPrint("📱 Found ${financialMessages.length} smart SMS alerts.");
        return financialMessages;

      } catch (e) {
        debugPrint("❌ SMS Read Error: $e");
        return [];
      }
    } else {
      debugPrint("🚫 SMS Permission Denied");
      return [];
    }
  }
}