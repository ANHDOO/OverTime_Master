import 'package:flutter/material.dart';
import '../../services/info_service.dart';
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
      if (mounted) {
        setState(() {
          _prices = data;
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
        title: const Text('Giá xăng dầu PVOIL'),
        backgroundColor: Colors.blue[800],
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
                    itemCount: _prices.length,
                    itemBuilder: (context, index) {
                      final item = _prices[index];
                      return _buildFuelCard(item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFuelCard(Map<String, String> item) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_gas_station, color: Colors.blue[800], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['type'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Giá niêm yết',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '${item['price']} đ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900]),
          ),
        ],
      ),
    );
  }
}
