class ReceiptResult {
  final double? totalAmount;
  final String? merchantName;
  final DateTime? transactionDate;
  final String? suggestedCategory;
  final String rawText;
  final List<String> lines;
  final double confidenceScore;

  const ReceiptResult({
    this.totalAmount,
    this.merchantName,
    this.transactionDate,
    this.suggestedCategory,
    required this.rawText,
    required this.lines,
    this.confidenceScore = 1.0,
  });

  ReceiptResult copyWith({
    double? totalAmount,
    String? merchantName,
    DateTime? transactionDate,
    String? suggestedCategory,
    String? rawText,
    List<String>? lines,
    double? confidenceScore,
  }) {
    return ReceiptResult(
      totalAmount: totalAmount ?? this.totalAmount,
      merchantName: merchantName ?? this.merchantName,
      transactionDate: transactionDate ?? this.transactionDate,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      rawText: rawText ?? this.rawText,
      lines: lines ?? this.lines,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}
