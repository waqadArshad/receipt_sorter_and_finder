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
    if (text.trim().length < 10) return false; // Too short to be a receipt
    final lower = text.toLowerCase();
    
    int score = 0;
    bool hasPriceLikePattern = RegExp(r'\d+[.,]\d{2}').hasMatch(text);

    // 1. Keyword Check (Max 4 points)
    // Primary Keywords (Strong indicators)
    if (lower.contains('total') || lower.contains('amount') || lower.contains('balance') || lower.contains('due')) {
      score += 3;
    }
    
    // Secondary Keywords (Context)
    int secondaryMatches = 0;
    for (final kw in _requiredKeywords) {
       if (lower.contains(kw) && !['total', 'amount', 'balance', 'due'].contains(kw)) {
         secondaryMatches++;
       }
    }
    // Cap secondary points at 2
    score += (secondaryMatches > 0 ? 1 : 0) + (secondaryMatches > 2 ? 1 : 0);

    // 2. Date Pattern Check (Max 2 points)
    bool hasDate = false;
    for (final pattern in _datePatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        hasDate = true;
        break;
      }
    }
    if (hasDate) score += 2;

    // 3. Currency Check (Max 2 points)
    bool hasCurrency = false;
    for (final pattern in _currencySymbols) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        hasCurrency = true;
        break;
      }
    }
    if (hasCurrency) score += 2;

    // 4. Price Pattern (Critical for Receipts)
    if (hasPriceLikePattern) score += 2;

    // 5. Numeric Density Check
    final numCount = RegExp(r'\d').allMatches(text).length;
    if (numCount > 5) score += 1;

    // Minimum score threshold
    // Needs at least: (Strong Keyword + Price/Currency) OR (Date + Currency + Price)
    return score >= 5;
  }
}
