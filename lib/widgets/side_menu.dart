import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../screens/settings_screen.dart';
import '../screens/settings/google_sheets_screen.dart';
import '../screens/settings/backup_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/security_screen.dart';
import '../screens/settings/update_screen.dart';
import '../screens/citizen_search/citizen_search_screen.dart';
import '../services/update_service.dart';
import '../services/google_sheets_service.dart';

typedef OnSelectTab = void Function(int index);

class SideMenu extends StatefulWidget {
  final OnSelectTab onSelectTab;
  final VoidCallback? onClose;
  final int selectedIndex;

  const SideMenu({super.key, required this.onSelectTab, this.onClose, this.selectedIndex = -1});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isSignedIn = false;
  bool _isSigningIn = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _checkGoogleSignInStatus();
  }

  Future<void> _checkGoogleSignInStatus() async {
    final service = GoogleSheetsService();
    final isSignedIn = await service.isSignedInWithGoogle();
    if (mounted) {
      setState(() {
        _isSignedIn = isSignedIn;
        _userEmail = service.currentUserEmail;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;
    
    final service = GoogleSheetsService();
    
    if (_isSignedIn) {
      setState(() => _isSigningIn = true);
      await service.signOutGoogle();
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _isSignedIn = false;
          _userEmail = null;
        });
      }
    } else {
      setState(() => _isSigningIn = true);
      final token = await service.signInWithGoogle();
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _isSignedIn = token != null;
          _userEmail = service.currentUserEmail;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    
    return SafeArea(
      child: Drawer(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: menuBg,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 30,
                offset: const Offset(10, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Profile Header with Gradient
              _buildProfileHeader(context, isDark),

              // Google Account Section
              _buildGoogleAccountSection(isDark),

              const SizedBox(height: 4),

              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildSectionLabel('Chức năng chính', isDark),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      icon: Icons.savings_rounded,
                      label: 'Quỹ Dự Án',
                      index: 0,
                      gradientColors: [AppColors.tealPrimary, AppColors.tealDark],
                      onTap: () {
                        widget.onSelectTab(0);
                        Navigator.pop(context);
                      },
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.schedule_rounded,
                      label: 'Tăng ca',
                      index: 1,
                      gradientColors: [AppColors.primary, AppColors.primaryDark],
                      onTap: () {
                        widget.onSelectTab(1);
                        Navigator.pop(context);
                      },
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Lãi nợ lương',
                      index: 2,
                      gradientColors: [AppColors.accent, AppColors.accentDark],
                      onTap: () {
                        widget.onSelectTab(2);
                        Navigator.pop(context);
                      },
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.calculate_rounded,
                      label: 'Tính thuế TNCN',
                      index: 3,
                      gradientColors: [AppColors.indigoPrimary, AppColors.indigoDark],
                      onTap: () {
                        widget.onSelectTab(3);
                        Navigator.pop(context);
                      },
                      isDark: isDark,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.person_search_rounded,
                      label: 'Tra cứu công dân',
                      gradientColors: [AppColors.info, AppColors.infoDark],
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CitizenSearchScreen()));
                      },
                      isDark: isDark,
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: borderColor, thickness: 1),
                    ),
                    
                    _buildSectionLabel('Cài đặt', isDark),
                    const SizedBox(height: 4),
                    
                    // 🌙 Theme Toggle
                    _buildThemeToggle(context, isDark),
                    const SizedBox(height: 4),
                    
                    _buildSettingsItem(
                      context,
                      icon: Icons.payments_rounded,
                      label: 'Cài đặt mức lương',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.notifications_rounded,
                      label: 'Nhắc & Thông báo',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.cloud_upload_rounded,
                      label: 'Sao lưu & Khôi phục',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.table_chart_rounded,
                      label: 'Google Sheets',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleSheetsScreen()));
                      },
                      isDark: isDark,
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.security_rounded,
                      label: 'Bảo mật',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
                      },
                      isDark: isDark,
                    ),
                    ListenableBuilder(
                      listenable: UpdateService(),
                      builder: (context, _) {
                        final updateService = UpdateService();
                        final hasUpdate = updateService.hasUpdate || updateService.status == DownloadStatus.readyToInstall;
                        return _buildSettingsItem(
                          context,
                          icon: Icons.system_update_rounded,
                          label: 'Cập nhật ứng dụng',
                          trailing: hasUpdate
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.danger.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateScreen()));
                          },
                          isDark: isDark,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    String version = '';
                    if (snapshot.hasData) {
                      final info = snapshot.data!;
                      version = 'v${info.version}+${info.buildNumber}';
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: AppGradients.heroBlue,
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'OT Master',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.1),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(
                            version.isNotEmpty ? version : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
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

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.heroBlueDark : AppGradients.heroBlue,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/avatar.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anh Đô',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text(
                        'anhdo1562@gmail.com',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleAccountSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isSignedIn ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isSignedIn ? Icons.check_circle : Icons.account_circle,
              color: _isSignedIn ? Colors.green : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSignedIn ? 'Tài khoản Google' : 'Đăng nhập Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_isSignedIn && _userEmail != null)
                  Text(
                    _userEmail!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Để đồng bộ Sheets & Backup',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isSigningIn
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                )
              : InkWell(
                  onTap: _handleGoogleSignIn,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSignedIn ? Colors.grey.withOpacity(0.2) : Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isSignedIn ? 'Đăng xuất' : 'Đăng nhập',
                      style: TextStyle(
                        color: _isSignedIn ? (isDark ? Colors.white70 : Colors.black54) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// 🌙 Theme Toggle Widget
  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.08),
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppGradients.heroBlue,
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(themeProvider.currentModeIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giao diện',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      themeProvider.currentModeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Theme toggle buttons
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: AppRadius.borderFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeButton(
                      context,
                      icon: Icons.light_mode_rounded,
                      isSelected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                      tooltip: 'Sáng',
                    ),
                    const SizedBox(width: 4),
                    _buildThemeButton(
                      context,
                      icon: Icons.brightness_auto_rounded,
                      isSelected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                      tooltip: 'Tự động',
                    ),
                    const SizedBox(width: 4),
                    _buildThemeButton(
                      context,
                      icon: Icons.dark_mode_rounded,
                      isSelected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                      tooltip: 'Tối',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeButton(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: isSelected ? AppGradients.heroBlue : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: AppRadius.borderFull,
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    int index = -1,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final bool selected = index >= 0 && index == widget.selectedIndex;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderMd,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected 
                  ? (isDark ? gradientColors[0].withValues(alpha: 0.15) : gradientColors[0].withValues(alpha: 0.1))
                  : Colors.transparent,
              borderRadius: AppRadius.borderMd,
              border: selected 
                  ? Border.all(color: gradientColors[0].withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: selected 
                        ? LinearGradient(colors: gradientColors)
                        : null,
                    color: selected ? null : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                      color: selected 
                          ? gradientColors[0]
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: AppRadius.borderFull,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
