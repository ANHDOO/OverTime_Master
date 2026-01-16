import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../logic/providers/cash_transaction_provider.dart';
import '../../data/models/cash_transaction.dart';
import '../../core/theme/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CashTransactionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator(color: AppColors.tealPrimary));
        }

        final projects = _getProjects(provider.cashTransactions);
        final filteredTransactions = _filterTransactions(provider.cashTransactions);
        final income = _getFilteredIncome(provider.cashTransactions);
        final expense = _getFilteredExpense(provider.cashTransactions);
        final balance = income - expense;

        return Column(
          children: [
            _buildHeroCard(context, balance, income, expense, currencyFormat, isDark),
            
            // Section Header with Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lịch sử giao dịch',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (projects.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.tealPrimary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.borderFull,
                        border: Border.all(color: AppColors.tealPrimary.withValues(alpha: 0.2)),
                      ),
                      child: DropdownButton<String>(
                        value: projects.contains(_selectedProject) ? _selectedProject : 'Tất cả',
                        underline: const SizedBox(),
                        isDense: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.tealPrimary),
                        items: projects.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedProject = value);
                        },
                      ),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: filteredTransactions.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = filteredTransactions[index];
                        return _buildTransactionCard(context, provider, transaction, currencyFormat, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, double balance, double income, double expense, NumberFormat format, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.heroTeal,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroTealLight,
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedProject == 'Tất cả' ? 'Số dư tổng quỹ' : 'Quỹ: $_selectedProject',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: AppRadius.borderFull,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80), // Vibrant Green
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Realtime',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  format.format(balance),
                  style: TextStyle(
                    color: balance >= 0 ? Colors.white : Colors.redAccent.shade100,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildMiniStat('Tổng thu', format.format(income), Icons.south_rounded, AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMiniStat('Tổng chi', format.format(expense), Icons.north_rounded, AppColors.danger)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.3),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, CashTransactionProvider provider, CashTransaction transaction, NumberFormat format, bool isDark) {
    final isIncome = transaction.type == TransactionType.income;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final accentColor = isIncome ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          isDark ? AppShadows.cardDark[0] : AppShadows.cardLight[0],
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderLg,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent Line
              Container(
                width: 5,
                color: accentColor,
              ),
              
              // Main Content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EditTransactionScreen(transaction: transaction)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description
                              Expanded(
                                child: Text(
                                  transaction.description,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Amount
                              Text(
                                '${isIncome ? '+' : '-'}${format.format(transaction.amount)}',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Badges & Icons
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (transaction.project != 'Mặc định')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.tealPrimary.withValues(alpha: 0.1),
                                          borderRadius: AppRadius.borderFull,
                                        ),
                                        child: Text(
                                          transaction.project,
                                          style: TextStyle(color: AppColors.tealPrimary, fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    if (transaction.taxRate > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: AppRadius.borderFull,
                                        ),
                                        child: Text(
                                          'VAT ${transaction.taxRate}%',
                                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    if (transaction.imagePath != null)
                                      Icon(Icons.image_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    if (transaction.note != null && transaction.note!.isNotEmpty)
                                      Icon(Icons.sticky_note_2_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  ],
                                ),
                              ),
                              // Date
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(transaction.date),
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (transaction.note != null && transaction.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                                  borderRadius: AppRadius.borderMd,
                                  border: Border(
                                    left: BorderSide(color: AppColors.warning.withValues(alpha: 0.5), width: 2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.store_rounded, size: 14, color: AppColors.warning.withValues(alpha: 0.8)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        transaction.note!,
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.savings_outlined,
              size: 40,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có giao dịch nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm giao dịch đầu tiên của bạn',
            style: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
