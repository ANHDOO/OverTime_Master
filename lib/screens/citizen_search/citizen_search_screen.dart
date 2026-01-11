import 'package:flutter/material.dart';
import 'web_view_screen.dart';
import '../../services/info_service.dart';
import 'package:intl/intl.dart';

class CitizenSearchScreen extends StatefulWidget {
  const CitizenSearchScreen({super.key});

  @override
  State<CitizenSearchScreen> createState() => _CitizenSearchScreenState();
}

class _CitizenSearchScreenState extends State<CitizenSearchScreen> {
  final InfoService _infoService = InfoService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện ích công dân'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRealtimeInfo(theme),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Tra cứu hành chính',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _buildSearchGrid(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeInfo(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildInfoCard(
                  'Giá Vàng SJC',
                  '85.000.000',
                  Icons.auto_graph,
                  Colors.orange,
                ),
                _buildInfoCard(
                  'USD/VND',
                  '25.450',
                  Icons.currency_exchange,
                  Colors.green,
                ),
                _buildInfoCard(
                  'Xăng RON 95',
                  '22.700',
                  Icons.local_gas_station,
                  Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchGrid(BuildContext context) {
    final searchItems = [
      {
        'title': 'Tra cứu Thuế',
        'icon': Icons.account_balance,
        'color': Colors.red,
        'url': 'https://tracuunnt.gdt.gov.vn/tcnnt/mstcn.jsp',
        'subtitle': 'Mã số thuế cá nhân'
      },
      {
        'title': 'Phạt nguội',
        'icon': Icons.directions_car,
        'color': Colors.blue,
        'url': 'https://www.csgt.vn/tra-cuu-phat-nguoi-43.html',
        'subtitle': 'Tra cứu vi phạm GT'
      },
      {
        'title': 'BHXH/BHYT',
        'icon': Icons.health_and_safety,
        'color': Colors.green,
        'url': 'https://baohiemxahoi.gov.vn/tracuu/Pages/tra-cuu-ho-gia-dinh.aspx',
        'subtitle': 'Thông tin bảo hiểm'
      },
      {
        'title': 'Căn cước/ĐDDT',
        'icon': Icons.badge,
        'color': Colors.teal,
        'url': 'https://dichvucong.dancuquocgia.gov.vn/',
        'subtitle': 'Cổng dịch vụ công'
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: searchItems.length,
      itemBuilder: (context, index) {
        final item = searchItems[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CitizenWebViewScreen(
                  title: item['title'] as String,
                  url: item['url'] as String,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    item['subtitle'] as String,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
