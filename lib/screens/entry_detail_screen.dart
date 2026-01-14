import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/overtime_entry.dart';
import '../theme/app_theme.dart';

class EntryDetailScreen extends StatelessWidget {
  final OvertimeEntry entry;

  const EntryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final dateFormat = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết tăng ca')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context, dateFormat, currencyFormat, isDark),
            const SizedBox(height: 24),
            _buildSectionTitle('Thời gian làm việc', isDark),
            const SizedBox(height: 12),
            _buildTimeCard(context, isDark),
            const SizedBox(height: 24),
            _buildSectionTitle('Chi tiết tính lương', isDark),
            const SizedBox(height: 12),
            _buildOTBreakdown(context, currencyFormat, isDark),
            const SizedBox(height: 24),
            _buildSummaryCard(context, currencyFormat, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateFormat dateFormat, NumberFormat currencyFormat, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: entry.isSunday ? AppGradients.heroDanger : AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: entry.isSunday ? AppShadows.heroDangerLight : AppShadows.heroLight,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(entry.isSunday ? Icons.weekend_rounded : Icons.work_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            entry.isSunday ? 'Chủ nhật (x2.0)' : 'Ngày thường',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  dateFormat.format(entry.date),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormat.format(entry.totalPay),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? null : AppShadows.cardLight,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimeItem(
              context,
              'Bắt đầu',
              entry.startTime.format(context),
              Icons.play_circle_outline_rounded,
              AppColors.success,
              isDark,
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Expanded(
            child: _buildTimeItem(
              context,
              'Kết thúc',
              entry.endTime.format(context),
              Icons.stop_circle_outlined,
              AppColors.danger,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeItem(BuildContext context, String label, String time, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildOTBreakdown(BuildContext context, NumberFormat currencyFormat, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? null : AppShadows.cardLight,
      ),
      child: Column(
        children: [
          if (entry.hours15 > 0 && !entry.isSunday)
            _buildOTRow(
              'Tăng ca x1.5',
              '17:30 - 22:00',
              entry.hours15,
              entry.hours15 * entry.hourlyRate * 1.5,
              currencyFormat,
              AppColors.primary,
              isDark,
            ),
          if (entry.hours18 > 0 && !entry.isSunday)
            _buildOTRow(
              'Tăng ca x1.8',
              'Sau 22:00',
              entry.hours18,
              entry.hours18 * entry.hourlyRate * 1.8,
              currencyFormat,
              AppColors.accent,
              isDark,
            ),
          if (entry.isSunday)
            _buildOTRow(
              'Chủ nhật x2.0',
              'Cả ngày',
              entry.hours20,
              entry.hours20 * entry.hourlyRate * 2.0,
              currencyFormat,
              AppColors.danger,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildOTRow(String title, String timeRange, double hours, double pay, NumberFormat format, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: AppRadius.borderFull,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text(timeRange, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hours.toStringAsFixed(1)} giờ',
                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 4),
              Text(format.format(pay), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, NumberFormat currencyFormat, bool isDark) {
    final totalHours = entry.isSunday ? entry.hours20 : (entry.hours15 + entry.hours18);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(isDark ? 0.15 : 0.08),
            AppColors.successDark.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Tổng số giờ OT', '${totalHours.toStringAsFixed(1)} giờ', isDark),
          Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          _buildSummaryRow('Lương cơ bản/giờ', currencyFormat.format(entry.hourlyRate), isDark),
          Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: AppRadius.borderSm),
                    child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tổng thu nhập',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                currencyFormat.format(entry.totalPay),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ],
    );
  }
}
