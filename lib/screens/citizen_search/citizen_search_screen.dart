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
import '../../theme/app_theme.dart';

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

  Future<void> _loadRealtimeInfo() async {}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(title: const Text('Ví giấy tờ & Tiện ích')),
      body: RefreshIndicator(
        onRefresh: _loadRealtimeInfo,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildWalletSection(context, isDark),
              const SizedBox(height: 24),
              _buildSectionHeader('Tra cứu thông tin', Icons.search_rounded, isDark),
              const SizedBox(height: 12),
              _buildActionGrid(context, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        ],
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context, bool isDark) {
    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        final profiles = provider.citizenProfiles;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 18)),
                    const SizedBox(width: 12),
                    Text('Ví giấy tờ cá nhân', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  ]),
                  Container(
                    decoration: BoxDecoration(gradient: AppGradients.heroBlue, borderRadius: AppRadius.borderFull),
                    child: IconButton(
                      onPressed: () => _showProfileDialog(context, isDark),
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (profiles.isEmpty)
              _buildEmptyWallet(isDark)
            else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) => _buildDocumentCard(context, profiles[index], isDark),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyWallet(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(isDark ? 0.15 : 0.08), shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet_rounded, size: 40, color: AppColors.accent.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text('Chưa có giấy tờ được lưu', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          const SizedBox(height: 6),
          Text('Lưu Mã số thuế, Biển số xe... để tra cứu 1 chạm', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, CitizenProfile profile, bool isDark) {
    final isTax = profile.taxId != null && profile.taxId!.isNotEmpty;
    final isPlate = profile.licensePlate != null && profile.licensePlate!.isNotEmpty;
    final isBhxh = profile.bhxhId != null && profile.bhxhId!.isNotEmpty;
    
    LinearGradient gradient;
    Color shadowColor;
    IconData typeIcon;
    String typeLabel;
    String displayValue;
    
    if (isPlate) {
      gradient = AppGradients.heroBlue;
      shadowColor = AppColors.primary;
      typeIcon = Icons.directions_car_rounded;
      typeLabel = 'Biển số xe';
      displayValue = profile.licensePlate ?? '';
    } else if (isTax) {
      gradient = AppGradients.heroDanger;
      shadowColor = AppColors.danger;
      typeIcon = Icons.account_balance_rounded;
      typeLabel = 'Mã số thuế';
      displayValue = profile.taxId ?? '';
    } else if (isBhxh) {
      gradient = AppGradients.heroGreen;
      shadowColor = AppColors.success;
      typeIcon = Icons.health_and_safety_rounded;
      typeLabel = 'Mã số BHXH';
      displayValue = profile.bhxhId ?? '';
    } else {
      gradient = AppGradients.heroTeal;
      shadowColor = AppColors.tealPrimary;
      typeIcon = Icons.badge_rounded;
      typeLabel = 'Số định danh';
      displayValue = profile.cccdId ?? '';
    }
    
    return InkWell(
      onTap: () {
        if (isPlate) Navigator.push(context, MaterialPageRoute(builder: (context) => TrafficFineSearchScreen(profile: profile)));
        else if (isTax) Navigator.push(context, MaterialPageRoute(builder: (context) => MstSearchScreen(profile: profile)));
        else if (isBhxh) Navigator.push(context, MaterialPageRoute(builder: (context) => BhxhSearchScreen(profile: profile)));
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadius.borderXl,
          boxShadow: [BoxShadow(color: shadowColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(right: -30, bottom: -30, child: Icon(Icons.shield_rounded, size: 140, color: Colors.white.withOpacity(0.08))),
            Positioned(left: -20, top: -20, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: AppRadius.borderFull),
                        child: Text(profile.label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                      Icon(typeIcon, color: Colors.white60, size: 20),
                    ],
                  ),
                  const Spacer(),
                  Text(displayValue, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(typeLabel, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('OverTime Wallet', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500)),
                      ]),
                      GestureDetector(
                        onTap: () => _showProfileDialog(context, isDark, profile: profile),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: AppRadius.borderFull),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
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

  Widget _buildActionGrid(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActionItem('Phạt nguội', 'Kiểm tra vi phạm giao thông', Icons.directions_car_rounded, AppColors.primary, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrafficFineSearchScreen()))),
          const SizedBox(height: 10),
          _buildActionItem('Tra cứu Mã số thuế', 'Xác thực thông tin người nộp thuế', Icons.account_balance_rounded, AppColors.danger, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MstSearchScreen()))),
          const SizedBox(height: 10),
          _buildActionItem('BHXH / BHYT', 'Tra cứu quá trình đóng & thẻ BHYT', Icons.health_and_safety_rounded, AppColors.success, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BhxhSearchScreen()))),
          const SizedBox(height: 10),
          _buildActionItem('Tỉ giá ngoại tệ', 'Xem tỉ giá từ Vietcombank', Icons.currency_exchange_rounded, AppColors.tealPrimary, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExchangeRateDetailScreen()))),
          const SizedBox(height: 10),
          _buildActionItem('Thông tin vàng / bạc', 'Theo dõi giá & đầu tư vàng', Icons.trending_up_rounded, AppColors.accent, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoldPriceDetailScreen()))),
          const SizedBox(height: 10),
          _buildActionItem('Giá xăng dầu', 'Cập nhật giá xăng dầu bán lẻ', Icons.local_gas_station_rounded, AppColors.indigoPrimary, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FuelPriceDetailScreen()))),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: AppRadius.borderLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderLg,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderMd),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, bool isDark, {CitizenProfile? profile}) {
    final nameController = TextEditingController(text: profile?.label);
    final taxController = TextEditingController(text: profile?.taxId);
    final plateController = TextEditingController(text: profile?.licensePlate);
    final cccdController = TextEditingController(text: profile?.cccdId);
    final bhxhController = TextEditingController(text: profile?.bhxhId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(profile == null ? Icons.add_rounded : Icons.edit_rounded, color: AppColors.primary, size: 18)),
          const SizedBox(width: 12),
          Text(profile == null ? 'Thêm hồ sơ mới' : 'Chỉnh sửa hồ sơ', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 17)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(nameController, 'Tên gợi nhớ (VD: Cá nhân, Vợ...)', Icons.label_rounded, isDark),
              const SizedBox(height: 12),
              _buildDialogTextField(taxController, 'Mã số thuế', Icons.account_balance_rounded, isDark),
              const SizedBox(height: 12),
              _buildDialogTextField(plateController, 'Biển số xe (VD: 30A12345)', Icons.directions_car_rounded, isDark),
              const SizedBox(height: 12),
              _buildDialogTextField(cccdController, 'Số CCCD', Icons.badge_rounded, isDark),
              const SizedBox(height: 12),
              _buildDialogTextField(bhxhController, 'Mã số BHXH', Icons.health_and_safety_rounded, isDark),
            ],
          ),
        ),
        actions: [
          if (profile != null)
            TextButton(onPressed: () { Provider.of<OvertimeProvider>(context, listen: false).deleteCitizenProfile(profile.id!); Navigator.pop(context); }, child: Text('Xóa', style: TextStyle(color: AppColors.danger))),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          Container(
            decoration: BoxDecoration(gradient: AppGradients.heroBlue, borderRadius: AppRadius.borderMd),
            child: TextButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                final newProfile = CitizenProfile(id: profile?.id, label: nameController.text, taxId: taxController.text, licensePlate: plateController.text, cccdId: cccdController.text, bhxhId: bhxhController.text);
                final provider = Provider.of<OvertimeProvider>(context, listen: false);
                if (profile == null) provider.addCitizenProfile(newProfile);
                else provider.updateCitizenProfile(newProfile);
                Navigator.pop(context);
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint, IconData icon, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.primary, width: 2)),
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
