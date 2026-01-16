import 'package:flutter/material.dart';
import '../../../data/services/info_service.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExchangeRateDetailScreen extends StatefulWidget {
  const ExchangeRateDetailScreen({super.key});

  @override
  State<ExchangeRateDetailScreen> createState() => _ExchangeRateDetailScreenState();
}

class _ExchangeRateDetailScreenState extends State<ExchangeRateDetailScreen> {
  final InfoService _infoService = InfoService();
  List<Map<String, String>> _rates = [];
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
      final data = await _infoService.getExchangeRates();
      if (mounted) setState(() { _rates = data; _isLoading = false; _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now()); });
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
        title: const Text('Tỷ giá ngoại tệ'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.success))
          : Column(
              children: [
                if (_lastUpdated != null) Padding(padding: const EdgeInsets.all(12), child: Text('Cập nhật lúc: $_lastUpdated', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _rates.length,
                    itemBuilder: (context, index) => _buildRateCard(_rates[index], isDark),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRateCard(Map<String, String> item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(isDark ? 0.2 : 0.1), shape: BoxShape.circle),
              child: Text(item['code'] ?? '', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 10)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              const SizedBox(height: 2),
              Text('Tỷ giá so với VND', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ])),
          ]),
          Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildRateItem('MUA VÀO', item['buy'] ?? '0', AppColors.primary, isDark),
            _buildRateItem('BÁN RA', item['sell'] ?? '0', AppColors.danger, isDark),
          ]),
        ],
      ),
    );
  }

  Widget _buildRateItem(String label, String value, Color color, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text('$value đ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}
