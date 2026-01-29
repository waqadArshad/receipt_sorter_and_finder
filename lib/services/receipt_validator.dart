class ReceiptValidator {
  static const List<String> _requiredKeywords = [
    'total', 'subtotal', 'amount', 'balance', 'due', 'tax', 'vat', 'gst',
    'invoice', 'receipt', 'bill', 'payment', 'paid', 'cash', 'card', 'change',
    'transaction', 'date', 'ref', 'order'
  ];

  static const List<String> _datePatterns = [
    r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', // 12/12/2024 or 12-12-2024
    r'\d{2,4}[/-]\d{1,2}[/-]\d{1,2}', // 2024-12-12
    r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)', // Month names
  ];

  static const List<String> _currencySymbols = [
    r'\$', '€', '£', '¥', '₹', 'rs\.', 'rs', 'eur', 'usd', 'pkr'
  ];

  /// Returns true if the text looks like a receipt/invoice
  static bool isValidReceipt(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    
    int score = 0;

    // 1. Keyword Check (Strong Signal)
    for (final kw in _requiredKeywords) {
      if (lower.contains(kw)) {
        score += 2;
      }
    }

    // 2. Date Pattern Check
    for (final pattern in _datePatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        score += 3;
      }
    }

    // 3. Currency Check
    for (final pattern in _currencySymbols) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        score += 3;
      }
    }

    // 4. Numeric Density Check (Receipts usually have many numbers)
    final numCount = RegExp(r'\d').allMatches(text).length;
    if (numCount > 5) score += 1;
    if (numCount > 10) score += 1;

    // Minimum score threshold
    // e.g. "Total: $50" -> Total(2) + $(3) + Num(1) = 6 (Pass)
    // "Happy Birthday!" -> 0 (Fail)
    return score >= 4;
  }
}
