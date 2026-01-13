import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/cash_transaction.dart';
import 'edit_transaction_screen.dart';

class CashFlowTab extends StatefulWidget {
  const CashFlowTab({super.key});

  @override
  State<CashFlowTab> createState() => _CashFlowTabState();
}

class _CashFlowTabState extends State<CashFlowTab> {
  String _selectedProject = 'Tất cả';

  List<String> _getProjects(List<CashTransaction> transactions) {
    final projects = transactions.map((t) => t.project).toSet().toList()..sort();
    return ['Tất cả', ...projects];
  }

  List<CashTransaction> _filterTransactions(List<CashTransaction> transactions) {
    if (_selectedProject == 'Tất cả') return transactions;
    return transactions.where((t) => t.project == _selectedProject).toList();
  }

  double _getFilteredIncome(List<CashTransaction> transactions) {
    return _filterTransactions(transactions)
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _getFilteredExpense(List<CashTransaction> transactions) {
    return _filterTransactions(transactions)
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = _getProjects(provider.cashTransactions);
        final filteredTransactions = _filterTransactions(provider.cashTransactions);
        final income = _getFilteredIncome(provider.cashTransactions);
        final expense = _getFilteredExpense(provider.cashTransactions);
        final balance = income - expense;

        return Column(
          children: [
            _buildSummaryCard(context, balance, income, expense, currencyFormat),
            
            // Project Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch sử giao dịch',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (projects.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButton<String>(
                        value: projects.contains(_selectedProject) ? _selectedProject : 'Tất cả',
                        underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        items: projects.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedProject = value);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có giao dịch nào',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = filteredTransactions[index];
                        return _buildTransactionCard(context, provider, transaction, currencyFormat);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, double balance, double income, double expense, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade800, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedProject == 'Tất cả' ? 'Số dư tổng' : 'Số dư: $_selectedProject',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('Realtime', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            format.format(balance),
            style: TextStyle(
              color: balance >= 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMiniStat('Tổng thu', format.format(income), Icons.arrow_downward, Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildMiniStat('Tổng chi', format.format(expense), Icons.arrow_upward, Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, OvertimeProvider provider, CashTransaction transaction, NumberFormat format) {
    final isIncome = transaction.type == TransactionType.income;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditTransactionScreen(transaction: transaction)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(DateFormat('dd/MM/yyyy').format(transaction.date), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        if (transaction.project != 'Mặc định') ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 100),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                transaction.project,
                                style: TextStyle(color: Colors.teal.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        if (transaction.imagePath != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.image, size: 12, color: Colors.blue.shade400),
                        ],
                        if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.note, size: 12, color: Colors.orange.shade400),
                        ],
                      ],
                    ),
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          transaction.note!,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount
              Text(
                '${isIncome ? '+' : '-'}${format.format(transaction.amount)}',
                style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
