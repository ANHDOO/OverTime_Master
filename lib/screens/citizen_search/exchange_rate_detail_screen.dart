import 'package:flutter/material.dart';
import '../../services/info_service.dart';
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
      if (mounted) {
        setState(() {
          _rates = data;
          _isLoading = false;
          _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tỷ giá ngoại tệ'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Cập nhật lúc: $_lastUpdated',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rates.length,
                    itemBuilder: (context, index) {
                      final item = _rates[index];
                      return _buildRateCard(item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRateCard(Map<String, String> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Text(
                  item['code'] ?? '',
                  style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Tỷ giá so với VND',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRateItem('MUA VÀO', item['buy'] ?? '0', Colors.blue),
              _buildRateItem('BÁN RA', item['sell'] ?? '0', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600], fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '$value đ',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
