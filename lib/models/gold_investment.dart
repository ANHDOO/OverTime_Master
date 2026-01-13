class GoldInvestment {
  final int? id;
  final String goldType;
  final double quantity;
  final double buyPrice;
  final String date;
  final String note;

  GoldInvestment({
    this.id,
    required this.goldType,
    required this.quantity,
    required this.buyPrice,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gold_type': goldType,
      'quantity': quantity,
      'buy_price': buyPrice,
      'date': date,
      'note': note,
    };
  }

  factory GoldInvestment.fromMap(Map<String, dynamic> map) {
    return GoldInvestment(
      id: map['id'],
      goldType: map['gold_type'],
      quantity: map['quantity'],
      buyPrice: map['buy_price'],
      date: map['date'],
      note: map['note'] ?? '',
    );
  }
}
