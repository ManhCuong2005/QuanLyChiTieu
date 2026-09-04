import 'category.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String merchant;
  final String note;
  final String? receiptImagePath;
  final String? rawOcrText;
  final bool isOcrScanned;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.merchant = '',
    this.note = '',
    this.receiptImagePath,
    this.rawOcrText,
    this.isOcrScanned = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category.toJson(),
    'date': date.toIso8601String(),
    'merchant': merchant,
    'note': note,
    'receiptImagePath': receiptImagePath,
    'rawOcrText': rawOcrText,
    'isOcrScanned': isOcrScanned,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: ExpenseCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      date: DateTime.parse(json['date'] as String),
      merchant: json['merchant'] as String? ?? '',
      note: json['note'] as String? ?? '',
      receiptImagePath: json['receiptImagePath'] as String?,
      rawOcrText: json['rawOcrText'] as String?,
      isOcrScanned: json['isOcrScanned'] as bool? ?? false,
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : null,
    );
  }

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? merchant,
    String? note,
    String? receiptImagePath,
    String? rawOcrText,
    bool? isOcrScanned,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      isOcrScanned: isOcrScanned ?? this.isOcrScanned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
