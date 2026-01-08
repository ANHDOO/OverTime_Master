import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/overtime_provider.dart';
import '../screens/settings_screen.dart';
import '../screens/settings/google_sheets_screen.dart';
import '../screens/settings/backup_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/smart_notifications_screen.dart';
import '../services/update_service.dart';
import 'package:provider/provider.dart';

typedef OnSelectTab = void Function(int index);

class SideMenu extends StatelessWidget {
  final OnSelectTab onSelectTab;
  final VoidCallback? onClose;
  final int selectedIndex;

  const SideMenu({super.key, required this.onSelectTab, this.onClose, this.selectedIndex = -1});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

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
                    radius: 28,
                    // Placeholder avatar; app can replace with user image if available
                    backgroundImage: AssetImage('assets/images/app_icon.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Anh Đô', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        // Show version and app info under the name
                        FutureBuilder(
                          future: DefaultAssetBundle.of(context).loadString('pubspec.yaml'),
                          builder: (context, snapshot) {
                            String version = '';
                            try {
                              final content = snapshot.data as String?;
                              if (content != null) {
                                final match = RegExp(r'^version:\\s*(.+)\$', multiLine: true).firstMatch(content);
                                if (match != null) version = match.group(1) ?? '';
                              }
                            } catch (_) {}
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ứng dụng quản lý OT & Tài chính', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('Liên hệ: anhdo1562@gmail.com', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            );
                          },
                        ),
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
                  const Divider(),
                  _buildNavItem(context, icon: Icons.settings, label: 'Cài đặt ứng dụng', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  }),
                  _buildNavItem(context, icon: Icons.cloud_sync, label: 'Google Sheets', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleSheetsScreen()));
                  }),
                  _buildNavItem(context, icon: Icons.smart_toy, label: 'Nhắc nhở thông minh', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartNotificationsScreen()));
                  }),
                  Consumer<OvertimeProvider>(
                    builder: (context, provider, child) {
                      return _buildNavItem(
                        context, 
                        icon: Icons.system_update, 
                        label: 'Kiểm tra cập nhật', 
                        trailing: provider.hasUpdate 
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          
                          // Nếu đã có thông tin update từ trước (check ngầm), hiển thị luôn
                          if (provider.hasUpdate && provider.updateInfo != null) {
                            navigator.pop(); // Đóng drawer
                            final updateService = UpdateService();
                            final shouldUpdate = await updateService.showUpdateDialog(navigator.context, provider.updateInfo!);
                            if (shouldUpdate == true && navigator.context.mounted) {
                              await updateService.downloadAndInstall(provider.updateInfo!.downloadUrl, navigator.context);
                            }
                            return;
                          }

                          navigator.pop(); // Close drawer

                          // Show loading dialog
                          showDialog(
                            context: navigator.context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 16),
                                  Text('Đang kiểm tra cập nhật...'),
                                ],
                              ),
                            ),
                          );

                          try {
                            debugPrint('🔄 Starting update check...');
                            final updateService = UpdateService();
                            final result = await updateService.checkForUpdate();

                            debugPrint('🔍 Update check result: hasUpdate=${result.hasUpdate}, error=${result.error}');

                            // Close loading dialog
                            navigator.pop();

                            if (result.hasUpdate && result.updateInfo != null) {
                              debugPrint('📦 Update available: ${result.updateInfo!.versionName}');
                              if (navigator.context.mounted) {
                                final shouldUpdate = await updateService.showUpdateDialog(navigator.context, result.updateInfo!);
                                if (shouldUpdate == true) {
                                  await updateService.downloadAndInstall(result.updateInfo!.downloadUrl, navigator.context);
                                }
                              }
                            } else if (result.error != null) {
                              debugPrint('❌ Update check error: ${result.error}');
                              if (navigator.context.mounted) {
                                ScaffoldMessenger.of(navigator.context).showSnackBar(
                                  SnackBar(content: Text('Lỗi kiểm tra cập nhật: ${result.error}'), backgroundColor: Colors.red),
                                );
                              }
                            } else {
                              debugPrint('✅ App is up to date');
                              if (navigator.context.mounted) {
                                ScaffoldMessenger.of(navigator.context).showSnackBar(
                                  const SnackBar(content: Text('Bạn đang sử dụng phiên bản mới nhất!'), backgroundColor: Colors.green),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('💥 Exception in update check: $e');
                            // Try to close loading dialog if it's still there
                            try { navigator.pop(); } catch (_) {}
                            
                            if (navigator.context.mounted) {
                              ScaffoldMessenger.of(navigator.context).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      );
                    },
                  ),
                  _buildNavItem(context, icon: Icons.backup, label: 'Sao lưu & Khôi phục', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
                  }),
                  _buildNavItem(context, icon: Icons.notifications, label: 'Nhắc & Thông báo', onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  }),
                ],
              ),
            ),

            // Footer: show version at bottom using PackageInfo
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


