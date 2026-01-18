
enum TransactionType {
  income,  // Đề xuất nhận vào
  expense, // Chi tiêu
}

class CashTransaction {
  final int? id;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime date;
  final String? imagePath;
  final String? note;
  final String project; // Tên dự án/quỹ
  final String paymentType; // Hình thức thanh toán: 'Hoá đơn giấy' hoặc 'Chụp hình chuyển khoản'
  final int taxRate; // Thuế suất: 0, 8, 10
  final bool isVatCollected; // Đã lấy hóa đơn VAT chưa
  final DateTime createdAt;

  CashTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.imagePath,
    this.note,
    this.project = 'Mặc định',
    this.paymentType = 'Hoá đơn giấy',
    this.taxRate = 0,
    this.isVatCollected = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Kiểm tra xem giao dịch này có cần nhắc lấy VAT không
  bool get needsVatReminder {
    if (taxRate == 0) return false; // Không có thuế
    if (isVatCollected) return false; // Đã lấy VAT
    // Chỉ nhắc trong 30 ngày kể từ ngày giao dịch
    final daysSinceTransaction = DateTime.now().difference(date).inDays;
    return daysSinceTransaction <= 30;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'note': note,
      'project': project,
      'payment_type': paymentType,
      'tax_rate': taxRate,
      'is_vat_collected': isVatCollected ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CashTransaction.fromMap(Map<String, dynamic> map) {
    return CashTransaction(
      id: map['id'],
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      amount: map['amount'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      imagePath: map['imagePath'],
      note: map['note'],
      project: map['project'] ?? 'Mặc định',
      paymentType: map['payment_type'] ?? 'Hoá đơn giấy',
      taxRate: map['tax_rate'] ?? 0,
      isVatCollected: (map['is_vat_collected'] ?? 0) == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  CashTransaction copyWith({
    int? id,
    TransactionType? type,
    double? amount,
    String? description,
    DateTime? date,
    String? imagePath,
    String? note,
    String? project,
    String? paymentType,
    int? taxRate,
    bool? isVatCollected,
    DateTime? createdAt,
  }) {
    return CashTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      note: note ?? this.note,
      project: project ?? this.project,
      paymentType: paymentType ?? this.paymentType,
      taxRate: taxRate ?? this.taxRate,
      isVatCollected: isVatCollected ?? this.isVatCollected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
