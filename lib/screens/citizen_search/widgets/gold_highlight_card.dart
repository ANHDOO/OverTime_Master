import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../../../theme/app_theme.dart';
import '../../../providers/gold_provider.dart';
import 'package:provider/provider.dart';

class GoldHighlightCard extends StatelessWidget {
  final bool isDark;

  const GoldHighlightCard({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoldProvider>(context);
    final selectedName = provider.goldTypeNames[provider.selectedHistoryKey] ?? '';
    
    Map<String, String> currentPriceData = {};
    if (provider.selectedHistoryKey == 'GOLD_610') {
      currentPriceData = provider.miHongPrices.firstWhere(
        (p) => p['type']?.contains('610') ?? false,
        orElse: () => <String, String>{},
      );
    } else {
      currentPriceData = provider.maoThietPrices.firstWhere(
        (p) => p['type']?.contains(selectedName.replaceAll('Vàng ', '')) ?? false,
        orElse: () => <String, String>{},
      );
    }

    double buyPrice = _parsePrice(currentPriceData['buy']);
    double sellPrice = _parsePrice(currentPriceData['sell']);
    if (sellPrice == 0 && provider.priceHistory.isNotEmpty) {
      buyPrice = provider.priceHistory.last['buy_price'];
      sellPrice = provider.priceHistory.last['sell_price'];
    }
    final isUp = provider.priceChangePercent > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.heroOrange,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroOrangeLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.selectedHistoryKey,
                      dropdownColor: AppColors.accent,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          provider.selectedHistoryKey = newValue;
                        }
                      },
                      items: provider.goldTypeNames.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(sellPrice)} đ',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                ],
              ),
              _buildTrendIndicator(provider, isUp),
            ],
          ),
          const SizedBox(height: 24),
          _buildChart(provider),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPriceInfo('MUA VÀO', buyPrice, Colors.white),
              _buildPriceInfo('BÁN RA', sellPrice, Colors.white.withOpacity(0.8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(GoldProvider provider, bool isUp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isUp 
            ? AppColors.successLight.withOpacity(0.2) 
            : (provider.priceChangePercent < 0 ? AppColors.dangerLight.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.priceChangePercent != 0) ...[
            Icon(
              isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isUp ? AppColors.successLight : AppColors.dangerLight,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '${provider.priceChangePercent.abs().toStringAsFixed(3)}%',
              style: TextStyle(
                color: isUp ? AppColors.successLight : AppColors.dangerLight,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ] else
            const Text(
              '0.000%',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          
          if (provider.recentTrend != 0) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: Colors.white24),
            const SizedBox(width: 8),
            Icon(
              provider.recentTrend > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: provider.recentTrend > 0 ? AppColors.successLight : AppColors.dangerLight,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(GoldProvider provider) {
    if (provider.priceHistory.length < 2) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('Đang thu thập dữ liệu biểu đồ...', style: TextStyle(color: Colors.white54, fontSize: 12))),
      );
    }

    final minPrice = provider.priceHistory.map((e) => (e['buy_price'] as num).toDouble()).reduce(min);
    final maxPrice = provider.priceHistory.map((e) => (e['sell_price'] as num).toDouble()).reduce(max);
    final range = maxPrice - minPrice;
    final padding = range == 0 ? 100000.0 : range * 0.15;

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: max(1, (provider.priceHistory.length / 5).floor().toDouble()),
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < provider.priceHistory.length) {
                    final dateStr = provider.priceHistory[value.toInt()]['date'];
                    try {
                      final date = DateFormat('yyyy-MM-dd HH:mm').parse(dateStr);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
                      );
                    } catch (_) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(dateStr.split(' ')[0].substring(5), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
                      );
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: (minPrice - padding) / 10000,
          maxY: (maxPrice + padding) / 10000,
          lineBarsData: [
            LineChartBarData(
              spots: provider.priceHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['sell_price'] as num).toDouble() / 10000)).toList(),
              isCurved: true,
              color: Colors.white,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isLast = index == barData.spots.length - 1;
                  if (isLast) {
                    return LabelDotPainter(
                      circlePainter: FlDotCirclePainter(radius: 5, color: Colors.white, strokeWidth: 2, strokeColor: AppColors.accent),
                      text: NumberFormat('#,###').format(spot.y * 10000),
                      isAbove: true,
                    );
                  }
                  return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            LineChartBarData(
              spots: provider.priceHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['buy_price'] as num).toDouble() / 10000)).toList(),
              isCurved: true,
              color: Colors.white60,
              barWidth: 1.5,
              dashArray: [6, 4],
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isLast = index == barData.spots.length - 1;
                  if (isLast) {
                    return LabelDotPainter(
                      circlePainter: FlDotCirclePainter(radius: 4, color: Colors.white60, strokeWidth: 1.5, strokeColor: AppColors.accent),
                      text: NumberFormat('#,###').format(spot.y * 10000),
                      isAbove: false,
                    );
                  }
                  return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                },
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppColors.accent.withOpacity(0.9),
              tooltipRoundedRadius: 12,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                if (touchedSpots.isEmpty) return [];
                
                final xIndex = touchedSpots[0].x.toInt();
                final record = provider.priceHistory[xIndex];
                final buyPrice = (record['buy_price'] as num).toDouble();
                final sellPrice = (record['sell_price'] as num).toDouble();
                final spread = sellPrice - buyPrice;
                final timeStr = record['date'].split(' ').length > 1 ? record['date'].split(' ')[1] : '';
                
                return touchedSpots.map((spot) {
                  final isSell = spot.barIndex == 0;
                  final priceLabel = isSell ? 'BÁN: ' : 'MUA: ';
                  final priceValue = NumberFormat('#,###').format(spot.y * 10000);
                  
                  String tooltipText = '$priceLabel$priceValue\n$timeStr';
                  if (isSell) {
                    tooltipText += '\nCHÊNH: ${NumberFormat('#,###').format(spread)}';
                  }
                  
                  return LineTooltipItem(
                    tooltipText,
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Bán ra', Colors.white, isDashed: false),
        const SizedBox(width: 24),
        _buildLegendItem('Mua vào', Colors.white70, isDashed: true),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool isDashed}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed 
              ? Row(children: List.generate(3, (i) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), color: color)))) 
              : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPriceInfo(String label, double price, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(
          '${NumberFormat('#,###').format(price)} đ',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
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

class LabelDotPainter extends FlDotPainter {
  final FlDotCirclePainter circlePainter;
  final String text;
  final bool isAbove;

  LabelDotPainter({required this.circlePainter, required this.text, required this.isAbove});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    circlePainter.draw(canvas, spot, offsetInCanvas);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 1))],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    
    final yOffset = isAbove ? -22.0 : 12.0;
    
    // Draw background for label
    final rect = Rect.fromCenter(
      center: offsetInCanvas + Offset(0, yOffset + textPainter.height / 2),
      width: textPainter.width + 12,
      height: textPainter.height + 4,
    );
    final paint = Paint()..color = Colors.black.withOpacity(0.6)..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
    
    textPainter.paint(canvas, offsetInCanvas + Offset(-textPainter.width / 2, yOffset));
  }

  @override
  Size getSize(FlSpot spot) => circlePainter.getSize(spot);
  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;
  @override
  Color get mainColor => circlePainter.color;
  @override
  List<Object?> get props => [circlePainter, text, isAbove];
}
