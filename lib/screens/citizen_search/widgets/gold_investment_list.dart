import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/gold_provider.dart';
import '../../../models/gold_investment.dart';
import 'package:provider/provider.dart';

class GoldInvestmentList extends StatelessWidget {
  final bool isDark;
  final Function(GoldInvestment?) onEdit;
  final Function(int) onDelete;

  const GoldInvestmentList({
    super.key, 
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoldProvider>(context);

    if (provider.investments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_edu_rounded, size: 56, color: AppColors.accent.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có giao dịch nào',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút + để thêm giao dịch mua vàng mới',
              style: TextStyle(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: provider.investments.length,
      itemBuilder: (context, index) {
        final inv = provider.investments[index];
        
        double currentShopBuyPrice = 0;
        if (inv.goldType.contains('610')) {
          final g610 = provider.miHongPrices.firstWhere((p) => p['type']?.contains('610') ?? false, orElse: () => <String, String>{});
          if (g610.isNotEmpty) currentShopBuyPrice = _parsePrice(g610['buy']);
        } else {
          final current = provider.maoThietPrices.firstWhere((p) => p['type'] == inv.goldType, orElse: () => <String, String>{});
          if (current.isNotEmpty) currentShopBuyPrice = _parsePrice(current['buy']);
        }

        final totalBuy = inv.buyPrice * inv.quantity;
        final totalCurrent = currentShopBuyPrice * inv.quantity;
        final profit = totalCurrent - totalBuy;
        final isProfit = profit >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderLg,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: (isProfit ? AppColors.success : AppColors.danger).withOpacity(0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          inv.goldType,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(
                          inv.date,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoColumn('SỐ LƯỢNG', '${inv.quantity} chỉ', isDark),
                          _buildInfoColumn('GIÁ MUA', '${NumberFormat('#,###').format(inv.buyPrice)} đ', isDark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isProfit ? AppColors.success : AppColors.danger).withOpacity(0.1),
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LỜI / LỖ HIỆN TẠI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: (isProfit ? AppColors.success : AppColors.danger).withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${isProfit ? '+' : ''}${NumberFormat('#,###').format(profit)} đ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isProfit ? AppColors.success : AppColors.danger,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (inv.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                inv.note,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionButton(Icons.edit_rounded, 'Sửa', AppColors.primary, () => onEdit(inv), isDark),
                          const SizedBox(width: 12),
                          _buildActionButton(Icons.delete_rounded, 'Xóa', AppColors.danger, () => onDelete(inv.id!), isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  double _parsePrice(String? priceStr) {
    if (priceStr == null) return 0;
    final digitsOnly = priceStr.replaceAll(RegExp(r'[^0-9]'), '');
    double val = double.tryParse(digitsOnly) ?? 0;
    if (val > 0 && val < 1000000) val *= 1000;
    return val;
  }
}
