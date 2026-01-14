import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_time_picker.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isEnabled = true;
  int _selectedHour = 22;
  int _selectedMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnabled = prefs.getBool('notification_enabled') ?? true;
      _selectedHour = prefs.getInt('notification_hour') ?? 22;
      _selectedMinute = prefs.getInt('notification_minute') ?? 0;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', value);
    setState(() => _isEnabled = value);
    
    if (value) {
      final service = NotificationService();
      await service.scheduleDailyNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Đã bật nhắc nhở lúc $_selectedHour:${_selectedMinute.toString().padLeft(2, '0')} 💪'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
        );
      }
    } else {
      await NotificationService().cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_off_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Đã tắt nhắc nhở hằng ngày'),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await CustomTimePicker.show(
      context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
      title: 'Giờ nhắc nhở',
      secondaryButtonText: 'Hủy',
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_hour', picked.hour);
      await prefs.setInt('notification_minute', picked.minute);
      setState(() {
        _selectedHour = picked.hour;
        _selectedMinute = picked.minute;
      });
      
      if (_isEnabled) {
        final service = NotificationService();
        await service.scheduleDailyNotification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Đã cập nhật: ${picked.hour}:${picked.minute.toString().padLeft(2, '0')} 🕐'),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            ),
          );
        }
      }
    }
  }

  Future<void> _scheduleTestNotification() async {
    final service = NotificationService();
    await service.scheduleDailyNotification(testMode: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Nhắc nhở sẽ xuất hiện sau 10 giây 🚀'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
    }
  }

  String _getTimeUntilNext() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, _selectedHour, _selectedMinute);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    final diff = next.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return 'Còn $hours giờ $minutes phút nữa';
    return 'Còn $minutes phút nữa';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắc nhở'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Section
          _buildHeroSection(isDark),
          const SizedBox(height: 24),

          // Settings Group
          _buildSectionHeader('Cài đặt nhắc nhở', isDark),
          const SizedBox(height: 12),
          
          // Main toggle
          _buildMainToggle(isDark),
          const SizedBox(height: 12),
          
          if (_isEnabled) ...[
            _buildTimePicker(isDark),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Xem trước', isDark),
            const SizedBox(height: 12),
            _buildPreviewCard(isDark),
            const SizedBox(height: 20),
            
            _buildTestButton(isDark),
            const SizedBox(height: 24),
            
            _buildWarningCard(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderXl,
        boxShadow: isDark ? null : AppShadows.cardLight,
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: _isEnabled ? AppGradients.heroBlue : null,
              color: _isEnabled ? null : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
              shape: BoxShape.circle,
              boxShadow: _isEnabled ? AppShadows.heroLight : null,
            ),
            child: Icon(
              _isEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              size: 36,
              color: _isEnabled ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isEnabled ? 'Nhắc nhở đang hoạt động' : 'Nhắc nhở đang tắt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _isEnabled 
                  ? 'Bạn sẽ nhận được thông báo ghi chép vào lúc $_selectedHour:${_selectedMinute.toString().padLeft(2, '0')}'
                  : 'Hãy bật nhắc nhở để không bỏ lỡ việc ghi chép chi tiêu hằng ngày',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        boxShadow: isDark ? null : AppShadows.cardLight,
        border: Border.all(
          color: _isEnabled ? AppColors.primary.withValues(alpha: 0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEnabled ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1) : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: _isEnabled ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhắc nhở hằng ngày',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isEnabled ? 'Đang bật' : 'Đã tắt',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isEnabled ? AppColors.success : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isEnabled,
              onChanged: _toggleNotification,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(bool isDark) {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: AppRadius.borderLg,
          boxShadow: isDark ? null : AppShadows.cardLight,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(Icons.schedule_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giờ nhắc nhở',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeUntilNext(),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppGradients.heroBlue,
                borderRadius: AppRadius.borderMd,
                boxShadow: AppShadows.heroLight,
              ),
              child: Text(
                '$_selectedHour:${_selectedMinute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        boxShadow: isDark ? null : AppShadows.cardLight,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: AppRadius.borderMd,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.heroBlue,
                    borderRadius: AppRadius.borderSm,
                    boxShadow: AppShadows.heroLight,
                  ),
                  child: const Icon(Icons.work_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anh Đô ơi! 💼',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hôm nay làm OT không? Nhớ ghi lại chi tiêu nha! 📝',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderMd,
        boxShadow: AppShadows.heroLight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _scheduleTestNotification,
          borderRadius: AppRadius.borderMd,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Text(
                  'Thử nghiệm nhắc nhở (sau 10s)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
            AppColors.warningDark.withValues(alpha: isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Lưu ý cho Xiaomi/MIUI',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Để thông báo hoạt động đúng, vui lòng:\n'
            '• Vào Cài đặt > Ứng dụng > OverTime\n'
            '• Tắt "Tiết kiệm pin" cho app\n'
            '• Bật "Tự khởi động"',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
