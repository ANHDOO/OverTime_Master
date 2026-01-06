class DebtEntry {
  final int? id;
  final DateTime month; // Month of the unpaid salary
  final double amount; // Amount owed
  final DateTime createdAt;
  final bool isPaid; // Whether the debt has been paid
  final DateTime? paidAt; // When the debt was paid

  DebtEntry({
    this.id,
    required this.month,
    required this.amount,
    required this.createdAt,
    this.isPaid = false,
    this.paidAt,
  });

  DebtEntry copyWith({
    int? id,
    DateTime? month,
    double? amount,
    DateTime? createdAt,
    bool? isPaid,
    DateTime? paidAt,
  }) {
    return DebtEntry(
      id: id ?? this.id,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'month': month.toIso8601String(),
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
      'is_paid': isPaid ? 1 : 0,
      'paid_at': paidAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory DebtEntry.fromMap(Map<String, dynamic> map) {
    return DebtEntry(
      id: map['id'],
      month: DateTime.parse(map['month']),
      amount: map['amount'],
      createdAt: DateTime.parse(map['created_at']),
      isPaid: map['is_paid'] == 1,
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at']) : null,
    );
  }

  // Calculate interest in real-time
  Map<String, double> calculateInterest() {
    // Reference date for calculation: if paid, use paidAt; otherwise use now.
    final referenceDate = isPaid ? (paidAt ?? DateTime.now()) : DateTime.now();
    
    final dueDate = DateTime(month.year, month.month, 20);
    final interestStartDate = DateTime(month.year, month.month, 5);

    double baseInterest = 0;
    double extraInterest = 0;
    int daysLate = 0;

    // If reference date is after the 5th of the debt month
    if (referenceDate.isAfter(interestStartDate)) {
      baseInterest = amount * 0.015; // 1.5%
    }

    // If reference date is after the 20th
    if (referenceDate.isAfter(dueDate)) {
      daysLate = referenceDate.difference(dueDate).inDays;
      if (daysLate < 0) daysLate = 0;
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
