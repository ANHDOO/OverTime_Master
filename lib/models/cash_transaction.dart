import 'package:flutter/material.dart';

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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
