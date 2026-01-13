import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../screens/settings_screen.dart';
import '../screens/settings/google_sheets_screen.dart';
import '../screens/settings/backup_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/security_screen.dart';
import '../screens/settings/update_screen.dart';
import '../screens/citizen_search/citizen_search_screen.dart';
import '../services/update_service.dart';

typedef OnSelectTab = void Function(int index);

class SideMenu extends StatelessWidget {
  final OnSelectTab onSelectTab;
  final VoidCallback? onClose;
  final int selectedIndex;

  const SideMenu({super.key, required this.onSelectTab, this.onClose, this.selectedIndex = -1});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
          ),
          child: Column(
            children: [
              // Profile header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage('assets/images/avatar.jpg'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Anh Đô', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('anhdo1562@gmail.com', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildNavItem(context, icon: Icons.savings_outlined, label: 'Quỹ Dự Án', index: 0, onTap: () {
                      onSelectTab(0);
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, icon: Icons.access_time_outlined, label: 'Tăng ca', index: 1, onTap: () {
                      onSelectTab(1);
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, icon: Icons.account_balance_wallet_outlined, label: 'Lãi nợ', index: 2, onTap: () {
                      onSelectTab(2);
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, icon: Icons.calculate_outlined, label: 'Tính thuế TNCN', index: 3, onTap: () {
                      onSelectTab(3);
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, icon: Icons.person_search_outlined, label: 'Tra cứu công dân', onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CitizenSearchScreen()));
                    }),
                    const Divider(),
                    _buildNavItem(context, icon: Icons.settings, label: 'Cài đặt mức lương', onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    }),
                    _buildNavItem(context, icon: Icons.notifications, label: 'Nhắc & Thông báo', onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    }),
                    _buildNavItem(context, icon: Icons.backup, label: 'Sao lưu & Khôi phục', onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
                    }),
                    _buildNavItem(context, icon: Icons.cloud_sync, label: 'Google Sheets', onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleSheetsScreen()));
                    }),
                    _buildNavItem(context, icon: Icons.security, label: 'Bảo mật', onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
                    }),
                    AnimatedBuilder(
                      animation: UpdateService(),
                      builder: (context, _) {
                        final updateService = UpdateService();
                        return _buildNavItem(
                          context, 
                          icon: Icons.system_update, 
                          label: 'Cập nhật ứng dụng', 
                          trailing: (updateService.hasUpdate || updateService.status == DownloadStatus.readyToInstall)
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateScreen()));
                          }
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    String version = '';
                    if (snapshot.hasData) {
                      final info = snapshot.data!;
                      version = '${info.version}+${info.buildNumber}';
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phiên bản', style: TextStyle(color: Colors.grey.shade600)),
                        Text(version.isNotEmpty ? version : '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required String label, int index = -1, required VoidCallback onTap, Widget? trailing}) {
    final bool selected = index >= 0 && index == selectedIndex;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: selected ? Colors.white : Colors.grey.shade800),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Theme.of(context).colorScheme.primary : Colors.black)),
      trailing: trailing,
      tileColor: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
      onTap: onTap,
    );
  }
}
