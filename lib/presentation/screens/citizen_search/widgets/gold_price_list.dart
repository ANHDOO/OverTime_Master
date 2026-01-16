import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../logic/providers/gold_provider.dart';
import 'package:provider/provider.dart';

class GoldPriceList extends StatelessWidget {
  final bool isDark;

  const GoldPriceList({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoldProvider>(context);
    final maoThietOthers = provider.maoThietPrices.where((p) => !(p['type']?.contains('Vàng Nhẫn Trơn') ?? false)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maoThietOthers.isNotEmpty) ...[
          _buildSectionHeader('Bảng giá Tám Nhung', Icons.store_rounded, AppColors.accent, isDark),
          const SizedBox(height: 12),
          ...maoThietOthers.map((item) => _buildPriceCard(item, isDark)),
          const SizedBox(height: 24),
        ],
        if (provider.sjcPrices.isNotEmpty) ...[
          _buildSectionHeader('Vàng SJC (Niêm yết)', Icons.account_balance_rounded, AppColors.primary, isDark),
          const SizedBox(height: 12),
          ...provider.sjcPrices.map((item) => _buildPriceCard(item, isDark, isSjc: true)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.25 : 0.15),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(Map<String, String> item, bool isDark, {bool isSjc = false}) {
    double buyPrice = _parsePrice(item['buy']);
    double sellPrice = _parsePrice(item['sell']);
    if (isSjc) {
      buyPrice /= 10;
      sellPrice /= 10;
    }

    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['type'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSjc ? 'Giá niêm yết' : 'Giá tại cửa hàng',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildPriceBadge('MUA', buyPrice, AppColors.success, isDark),
          const SizedBox(width: 8),
          _buildPriceBadge('BÁN', sellPrice, AppColors.danger, isDark),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(String label, double price, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            NumberFormat('#,###').format(price),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
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
