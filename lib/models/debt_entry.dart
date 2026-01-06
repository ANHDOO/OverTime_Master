class DebtEntry {
  final int? id;
  final DateTime month; // Month of the unpaid salary
  final double amount; // Amount owed
  final DateTime createdAt;

  DebtEntry({
    this.id,
    required this.month,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month.toIso8601String(),
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DebtEntry.fromMap(Map<String, dynamic> map) {
    return DebtEntry(
      id: map['id'],
      month: DateTime.parse(map['month']),
      amount: map['amount'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Calculate interest in real-time
  Map<String, double> calculateInterest() {
    final now = DateTime.now();
    final dueDate = DateTime(month.year, month.month, 20);
    final interestStartDate = DateTime(month.year, month.month, 5);

    double baseInterest = 0;
    double extraInterest = 0;
    int daysLate = 0;

    // If current date is after the 5th of the debt month
    if (now.isAfter(interestStartDate)) {
      baseInterest = amount * 0.015; // 1.5%
    }

    // If current date is after the 20th
    if (now.isAfter(dueDate)) {
      daysLate = now.difference(dueDate).inDays;
      extraInterest = amount * 0.001 * daysLate; // 0.1% per day
    }

    return {
      'baseInterest': baseInterest,
      'extraInterest': extraInterest,
      'totalInterest': baseInterest + extraInterest,
      'daysLate': daysLate.toDouble(),
    };
  }
}
