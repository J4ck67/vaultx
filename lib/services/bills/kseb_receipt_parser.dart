class KsebReceiptParser {
  static Map<String, dynamic> parse(String text) {
    final clean = text.replaceAll("\n", " ");

    final dates = _extractAllDates(clean);

    return {
      "consumerNumber": _extractConsumerNumber(clean),
      "billNumber": _extractBillNumber(clean),
      "billDate": dates.isNotEmpty ? dates[0] : null,
      "dueDate": dates.length > 1 ? dates[1] : null,
      "disconnectDate": dates.length > 2 ? dates[2] : null,
      "amount": _extractFinalAmount(clean),
    };
  }

  static String? _extractConsumerNumber(String text) {
    final match = RegExp(r'C[#:\s]*([A-Z]?\d{8,15})',
        caseSensitive: false).firstMatch(text);
    return match?.group(1);
  }

  static String? _extractBillNumber(String text) {
    final match = RegExp(r'\b\d{10,14}\b').firstMatch(text);
    return match?.group(0);
  }

  static List<DateTime> _extractAllDates(String text) {
    final matches = RegExp(r'\b\d{2}-\d{2}-\d{4}\b')
        .allMatches(text);

    return matches.map((m) {
      final parts = m.group(0)!.split("-");
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }).toList();
  }

  static double? _extractFinalAmount(String text) {
    final matches = RegExp(r'\b\d+\.\d{2}\b')
        .allMatches(text)
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();

    if (matches.isEmpty) return null;

    return matches.last;
  }
}
