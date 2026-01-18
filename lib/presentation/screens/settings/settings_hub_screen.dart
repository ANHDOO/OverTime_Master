import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/providers/theme_provider.dart';
import '../../../logic/providers/font_provider.dart';
import '../settings_screen.dart';
import 'backup_screen.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';
import 'update_screen.dart';
import 'google_sheets_screen.dart';
import '../../../data/services/update_service.dart';

/// 🎛️ Settings Hub Screen - Màn hình cài đặt tổng hợp
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 🎨 Section: Giao diện & Hiển thị
          _buildSectionTitle('Giao diện & Hiển thị', isDark),
          _buildCard([
            _buildThemeToggle(context, isDark),
            _buildDivider(isDark),
            _buildFontSelector(context, isDark),
          ], isDark),
          
          const SizedBox(height: 24),
          
          // 💼 Section: Công việc & Lương
          _buildSectionTitle('Công việc & Lương', isDark),
          _buildCard([
            _buildSettingItem(
              context,
              icon: Icons.payments_rounded,
              iconColor: AppColors.success,
              title: 'Cài đặt mức lương',
              subtitle: 'Lương cơ bản, phụ cấp, BHXH',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              isDark: isDark,
            ),
          ], isDark),
          
          const SizedBox(height: 24),
          
          // 🔄 Section: Dữ liệu & Đồng bộ
          _buildSectionTitle('Dữ liệu & Đồng bộ', isDark),
          _buildCard([
            _buildSettingItem(
              context,
              icon: Icons.cloud_upload_rounded,
              iconColor: AppColors.info,
              title: 'Sao lưu & Khôi phục',
              subtitle: 'Backup dữ liệu lên đám mây',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildSettingItem(
              context,
              icon: Icons.table_chart_rounded,
              iconColor: AppColors.success,
              title: 'Google Sheets',
              subtitle: 'Xuất dữ liệu ra bảng tính',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleSheetsScreen())),
              isDark: isDark,
            ),
          ], isDark),
          
          const SizedBox(height: 24),
          
          // 🔔 Section: Thông báo
          _buildSectionTitle('Thông báo', isDark),
          _buildCard([
            _buildSettingItem(
              context,
              icon: Icons.notifications_rounded,
              iconColor: AppColors.warning,
              title: 'Nhắc & Thông báo',
              subtitle: 'Cấu hình lịch nhắc nhở',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              isDark: isDark,
            ),
          ], isDark),
          
          const SizedBox(height: 24),
          
          // 🔐 Section: Bảo mật & Khác
          _buildSectionTitle('Bảo mật & Khác', isDark),
          _buildCard([
            _buildSettingItem(
              context,
              icon: Icons.security_rounded,
              iconColor: AppColors.danger,
              title: 'Bảo mật',
              subtitle: 'Khóa ứng dụng, vân tay',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
              isDark: isDark,
            ),
            _buildDivider(isDark),
            ListenableBuilder(
              listenable: UpdateService(),
              builder: (context, _) {
                final updateService = UpdateService();
                final hasUpdate = updateService.hasUpdate || updateService.status == DownloadStatus.readyToInstall;
                return _buildSettingItem(
                  context,
                  icon: Icons.system_update_rounded,
                  iconColor: AppColors.primary,
                  title: 'Kiểm tra cập nhật',
                  subtitle: hasUpdate ? 'Có bản cập nhật mới!' : 'Phiên bản mới nhất',
                  trailing: hasUpdate ? _buildUpdateBadge() : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateScreen())),
                  isDark: isDark,
                );
              },
            ),
          ], isDark),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? null : AppShadows.cardLight,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      indent: 56,
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chế độ hiển thị',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Đang dùng: Tối' : 'Đang dùng: Sáng',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          // Toggle buttons
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: AppRadius.borderFull,
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeButton(
                  icon: Icons.light_mode_rounded,
                  isSelected: themeProvider.themeMode == ThemeMode.light,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
                _buildThemeButton(
                  icon: Icons.dark_mode_rounded,
                  isSelected: themeProvider.themeMode == ThemeMode.dark,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
                _buildThemeButton(
                  icon: Icons.brightness_auto_rounded,
                  isSelected: themeProvider.themeMode == ThemeMode.system,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.borderFull,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildFontSelector(BuildContext context, bool isDark) {
    final fontProvider = context.watch<FontProvider>();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderMd,
            ),
            child: const Icon(Icons.text_fields_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font chữ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đang dùng: ${fontProvider.selectedFont.name}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            onPressed: () => _showFontPicker(context, isDark),
          ),
        ],
      ),
    );
  }

  void _showFontPicker(BuildContext context, bool isDark) {
    final fontProvider = context.read<FontProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24, 
          right: 24, 
          top: 24, 
          bottom: MediaQuery.of(context).padding.bottom + 24
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn Font chữ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...FontProvider.availableFonts.map((font) => _buildFontOption(
                      context,
                      font: font,
                      isSelected: fontProvider.selectedFontId == font.id,
                      isDark: isDark,
                      onTap: () {
                        fontProvider.setFont(font.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã đổi sang font ${font.name}. Khởi động lại app để áp dụng hoàn toàn.'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontOption(BuildContext context, {
    required FontOption font,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppColors.primary.withValues(alpha: 0.1) 
            : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
          borderRadius: AppRadius.borderMd,
          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    font.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    font.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: AppRadius.borderFull,
      ),
      child: const Text(
        'MỚI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
