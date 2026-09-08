enum DebtDirection { owedToMe, iOwe }

class DebtTransaction {
  final String id;
  final double amount;
  final String note;
  final DateTime createdAt;

  const DebtTransaction({
    required this.id,
    required this.amount,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DebtTransaction.fromJson(Map<String, dynamic> json) =>
      DebtTransaction(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Debt {
  final String id;
  final String personName;
  final DebtDirection direction;
  final String note;
  final DateTime createdAt;
  final List<DebtTransaction> transactions;

  const Debt({
    required this.id,
    required this.personName,
    required this.direction,
    this.note = '',
    required this.createdAt,
    required this.transactions,
  });

  double get balance => transactions.fold(0, (sum, item) => sum + item.amount);
  DateTime get updatedAt =>
      transactions.isEmpty ? createdAt : transactions.last.createdAt;

  Debt copyWith({List<DebtTransaction>? transactions}) => Debt(
    id: id,
    personName: personName,
    direction: direction,
    note: note,
    createdAt: createdAt,
    transactions: transactions ?? this.transactions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'personName': personName,
    'direction': direction.name,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'transactions': transactions.map((item) => item.toJson()).toList(),
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    id: json['id'] as String,
    personName: json['personName'] as String,
    direction:
        json['direction'] == DebtDirection.iOwe.name
            ? DebtDirection.iOwe
            : DebtDirection.owedToMe,
    note: json['note'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    transactions:
        (json['transactions'] as List<dynamic>? ?? [])
            .map(
              (item) => DebtTransaction.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
  );
}
