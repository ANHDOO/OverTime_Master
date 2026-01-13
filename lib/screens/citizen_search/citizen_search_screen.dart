import 'package:flutter/material.dart';
import 'traffic_fine_search_screen.dart';
import 'mst_search_screen.dart';
import 'bhxh_search_screen.dart';
import 'exchange_rate_detail_screen.dart';
import 'gold_price_detail_screen.dart';
import 'fuel_price_detail_screen.dart';
import '../../services/info_service.dart';
import 'package:intl/intl.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import 'package:provider/provider.dart';

class CitizenSearchScreen extends StatefulWidget {
  const CitizenSearchScreen({super.key});

  @override
  State<CitizenSearchScreen> createState() => _CitizenSearchScreenState();
}

class _CitizenSearchScreenState extends State<CitizenSearchScreen> {
  final InfoService _infoService = InfoService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  CitizenProfile? _selectedProfile;
  
  bool _isLoadingInfo = false;

  @override
  void initState() {
    super.initState();
    _loadRealtimeInfo();
  }

  Future<void> _loadRealtimeInfo() async {
    // No longer needed for main screen UI, but kept as a stub for RefreshIndicator if needed
    // or we can just remove the RefreshIndicator's dependency on it.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ví giấy tờ & Tiện ích'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRealtimeInfo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildWalletSection(context, theme),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Tra cứu thông tin',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              _buildActionGrid(context, theme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context, ThemeData theme) {
    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        final profiles = provider.citizenProfiles;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ví giấy tờ cá nhân',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => _showProfileDialog(context),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                  ),
                ],
              ),
            ),
            if (profiles.isEmpty)
              _buildEmptyWallet(theme)
            else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return _buildDocumentCard(context, profile, theme);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyWallet(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('Chưa có giấy tờ được lưu', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Lưu Mã số thuế, Biển số xe... để tra cứu 1 chạm',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, CitizenProfile profile, ThemeData theme) {
    final isTax = profile.taxId != null && profile.taxId!.isNotEmpty;
    final isPlate = profile.licensePlate != null && profile.licensePlate!.isNotEmpty;
    
    final color = isPlate ? Colors.blue[800]! : (isTax ? Colors.red[800]! : Colors.teal[800]!);
    
    return InkWell(
      onTap: () {
        if (isPlate) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrafficFineSearchScreen(profile: profile),
            ),
          );
        } else if (isTax) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MstSearchScreen(profile: profile),
            ),
          );
        } else if (profile.bhxhId != null && profile.bhxhId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BhxhSearchScreen(profile: profile),
            ),
          );
        }
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.shield, size: 120, color: Colors.white.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      profile.label.toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const Icon(Icons.nfc, color: Colors.white54, size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  isPlate ? (profile.licensePlate ?? '') : (isTax ? (profile.taxId ?? '') : (profile.cccdId ?? '')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'Courier',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPlate ? 'Biển số xe' : (isTax ? 'Mã số thuế' : 'Số định danh'),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('OverTime Wallet', style: TextStyle(color: Colors.white38, fontSize: 9)),
                    InkWell(
                      onTap: () => _showProfileDialog(context, profile: profile),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildActionGrid(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActionItem(
            'Phạt nguội',
            'Kiểm tra vi phạm giao thông toàn quốc',
            Icons.directions_car,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrafficFineSearchScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            'Tra cứu Mã số thuế',
            'Xác thực thông tin người nộp thuế',
            Icons.account_balance,
            Colors.red,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MstSearchScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            'BHXH / BHYT',
            'Tra cứu quá trình đóng & thẻ BHYT',
            Icons.health_and_safety,
            Colors.green,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BhxhSearchScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            'Tỉ giá ngoại tệ',
            'Xem tỉ giá chuyển đổi từ Vietcombank',
            Icons.currency_exchange,
            Colors.green,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExchangeRateDetailScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            'Thông tin vàng / bạc',
            'Theo dõi giá & quản lý đầu tư vàng',
            Icons.trending_up,
            Colors.orange,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GoldPriceDetailScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            'Giá xăng dầu',
            'Cập nhật giá xăng dầu bán lẻ',
            Icons.local_gas_station,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FuelPriceDetailScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, ThemeData theme) {
    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        final profiles = provider.citizenProfiles;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hồ sơ của tôi',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => _showProfileDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm mới'),
                  ),
                ],
              ),
            ),
            if (profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Lưu MST, Biển số xe... để tra cứu nhanh hơn',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              )
            else
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isSelected = _selectedProfile?.id == profile.id;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedProfile = isSelected ? null : profile;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(
                                  profile.label,
                                  style: TextStyle(
                                    color: isSelected ? theme.primaryColor : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            VerticalDivider(width: 1, indent: 8, endIndent: 8, color: Colors.grey.shade300),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => _showProfileDialog(context, profile: profile),
                              color: isSelected ? theme.primaryColor : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            const Divider(),
          ],
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, {CitizenProfile? profile}) {
    final nameController = TextEditingController(text: profile?.label);
    final taxController = TextEditingController(text: profile?.taxId);
    final plateController = TextEditingController(text: profile?.licensePlate);
    final cccdController = TextEditingController(text: profile?.cccdId);
    final bhxhController = TextEditingController(text: profile?.bhxhId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(profile == null ? 'Thêm hồ sơ mới' : 'Chỉnh sửa hồ sơ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên gợi nhớ (VD: Cá nhân, Vợ...)'),
              ),
              TextField(
                controller: taxController,
                decoration: const InputDecoration(labelText: 'Mã số thuế'),
              ),
              TextField(
                controller: plateController,
                decoration: const InputDecoration(labelText: 'Biển số xe (VD: 30A12345)'),
              ),
              TextField(
                controller: cccdController,
                decoration: const InputDecoration(labelText: 'Số CCCD'),
              ),
              TextField(
                controller: bhxhController,
                decoration: const InputDecoration(labelText: 'Mã số BHXH'),
              ),
            ],
          ),
        ),
        actions: [
          if (profile != null)
            TextButton(
              onPressed: () {
                Provider.of<OvertimeProvider>(context, listen: false).deleteCitizenProfile(profile.id!);
                Navigator.pop(context);
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              
              final newProfile = CitizenProfile(
                id: profile?.id,
                label: nameController.text,
                taxId: taxController.text,
                licensePlate: plateController.text,
                cccdId: cccdController.text,
                bhxhId: bhxhController.text,
              );

              final provider = Provider.of<OvertimeProvider>(context, listen: false);
              if (profile == null) {
                provider.addCitizenProfile(newProfile);
              } else {
                provider.updateCitizenProfile(newProfile);
              }
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
