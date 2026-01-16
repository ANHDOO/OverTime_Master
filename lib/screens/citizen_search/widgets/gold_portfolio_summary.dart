import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../theme/app_theme.dart';
import '../../../providers/gold_provider.dart';
import 'package:provider/provider.dart';

class GoldPortfolioSummary extends StatelessWidget {
  final bool isDark;

  const GoldPortfolioSummary({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoldProvider>(context);
    final isProfit = provider.totalProfit >= 0;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppGradients.heroBlue,
            borderRadius: AppRadius.borderXl,
            boxShadow: AppShadows.heroLight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TỔNG VỐN ĐẦU TƯ',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text(
                      '${provider.totalQuantity.toStringAsFixed(2)} chỉ',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${NumberFormat('#,###').format(provider.totalInvested)} đ',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GIÁ TRỊ HIỆN TẠI', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(
                          '${NumberFormat('#,###').format(provider.totalCurrentValue)} đ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TỔNG LỜI / LỖ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              color: isProfit ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${isProfit ? '+' : ''}${provider.totalProfitPercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isProfit ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (provider.portfolioProfitHistory.length >= 2) _buildPortfolioChart(provider, isDark),
      ],
    );
  }

  Widget _buildPortfolioChart(GoldProvider provider, bool isDark) {
    final profits = provider.portfolioProfitHistory.map((e) => (e['profit'] as num).toDouble()).toList();
    final minProfit = profits.reduce(min);
    final maxProfit = profits.reduce(max);
    final range = maxProfit - minProfit;
    final padding = range == 0 ? 1000000.0 : range * 0.25;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XU HƯỚNG LỢI NHUẬN',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(Icons.auto_graph_rounded, size: 16, color: AppColors.primary.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: minProfit - padding,
                maxY: maxProfit + padding,
                lineBarsData: [
                  LineChartBarData(
                    spots: provider.portfolioProfitHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['profit'] as num).toDouble())).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withOpacity(0.25), AppColors.primary.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppColors.primary.withOpacity(0.9),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final record = provider.portfolioProfitHistory[spot.x.toInt()];
                        final dateStr = record['date'].split(' ')[0];
                        return LineTooltipItem(
                          '${NumberFormat('#,###').format(spot.y)} đ\n$dateStr',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
