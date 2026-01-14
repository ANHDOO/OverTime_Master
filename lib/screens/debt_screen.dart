import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/debt_entry.dart';
import '../theme/app_theme.dart';

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        return Column(
          children: [
            _buildSummaryCard(context, provider, currencyFormat, isDark),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    'Danh sách nợ lương',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text(
                      '${provider.debtEntries.length} khoản',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.debtEntries.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: provider.debtEntries.length,
                      itemBuilder: (context, index) {
                        final debt = provider.debtEntries[index];
                        return _buildDebtCard(context, debt, provider, currencyFormat, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(isDark ? 0.1 : 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có khoản nợ lương nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút + để thêm khoản nợ mới',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, OvertimeProvider provider, NumberFormat format, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.heroOrange,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroOrangeLight,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Tổng tiền lãi tích lũy',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Realtime',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  format.format(provider.totalDebtInterest),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildMiniStat('Số khoản nợ', provider.debtEntries.length.toString(), Icons.receipt_long_rounded)),
                      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                      Expanded(child: _buildMiniStat('Tổng gốc', format.format(provider.totalDebtAmount), Icons.account_balance_wallet_rounded)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildDebtCard(BuildContext context, DebtEntry debt, OvertimeProvider provider, NumberFormat format, bool isDark) {
    final interest = debt.calculateInterest();
    final monthFormat = DateFormat('MM/yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: debt.isPaid 
            ? (isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: debt.isPaid
              ? (isDark ? AppColors.success.withOpacity(0.3) : AppColors.success.withOpacity(0.2))
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: debt.isPaid ? null : (isDark ? AppShadows.cardDark : AppShadows.cardLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: debt.isPaid,
                          onChanged: (value) => provider.toggleDebtPaid(debt),
                          activeColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: debt.isPaid 
                                ? AppColors.success.withOpacity(isDark ? 0.2 : 0.1)
                                : AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(
                            debt.isPaid ? 'Đã thanh toán' : 'Tháng ${monthFormat.format(debt.month)}',
                            style: TextStyle(
                              color: debt.isPaid ? AppColors.success : AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ),
                      if (!debt.isPaid && interest['daysLate']! > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(
                            'Quá ${interest['daysLate']!.toInt()} ngày',
                            style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  onPressed: () => _showDeleteDialog(context, provider, debt.id!, isDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gốc nợ', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      format.format(debt.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                        color: debt.isPaid 
                            ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Tiền lãi', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      format.format(interest['totalInterest']),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: debt.isPaid 
                            ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                            : AppColors.danger,
                        decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  debt.isPaid ? 'Tổng đã trả:' : 'Tổng phải trả:',
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                Text(
                  format.format(debt.amount + interest['totalInterest']!),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: debt.isPaid ? AppColors.primary : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, OvertimeProvider provider, int id, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Xóa khoản nợ?',
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa khoản nợ này không?',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteDebtEntry(id);
              Navigator.pop(context);
            },
            child: Text('Xóa', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
