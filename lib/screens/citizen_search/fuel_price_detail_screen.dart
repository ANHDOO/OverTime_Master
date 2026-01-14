import 'package:flutter/material.dart';
import '../../services/info_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class FuelPriceDetailScreen extends StatefulWidget {
  const FuelPriceDetailScreen({super.key});

  @override
  State<FuelPriceDetailScreen> createState() => _FuelPriceDetailScreenState();
}

class _FuelPriceDetailScreenState extends State<FuelPriceDetailScreen> {
  final InfoService _infoService = InfoService();
  List<Map<String, String>> _prices = [];
  bool _isLoading = true;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _infoService.getFuelPrices();
      if (mounted) setState(() { _prices = data; _isLoading = false; _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now()); });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Giá xăng dầu PVOIL'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                if (_lastUpdated != null) Padding(padding: const EdgeInsets.all(12), child: Text('Cập nhật lúc: $_lastUpdated', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _prices.length,
                    itemBuilder: (context, index) => _buildFuelCard(_prices[index], isDark),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFuelCard(Map<String, String> item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1), shape: BoxShape.circle),
          child: Icon(Icons.local_gas_station_rounded, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['type'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          const SizedBox(height: 4),
          Text('Giá niêm yết', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(gradient: AppGradients.heroBlue, borderRadius: AppRadius.borderMd),
          child: Text('${item['price']} đ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }
}
