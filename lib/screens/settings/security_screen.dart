import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Screen for managing app lock settings (PIN/Biometric)
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final AuthService _authService = AuthService();

  bool _isLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lockEnabled = await _authService.isLockEnabled();
    final biometricEnabled = await _authService.isBiometricEnabled();
    final biometricAvailable = await _authService.isBiometricAvailable();

    if (mounted) {
      setState(() {
        _isLockEnabled = lockEnabled;
        _isBiometricEnabled = biometricEnabled;
        _isBiometricAvailable = biometricAvailable;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final pin = await _showSetPinDialog();
      if (!mounted) return;
      if (pin != null && pin.isNotEmpty) {
        await _authService.setPin(pin);
        await _authService.setLockEnabled(true);
        if (!mounted) return;
        setState(() => _isLockEnabled = true);
        _showSnackBar('Đã bật khóa ứng dụng 🔐', AppColors.success);
      }
    } else {
      final verified = await _verifyCurrentPin();
      if (!mounted || !verified) return;
      await _authService.setLockEnabled(false);
      if (!mounted) return;
      setState(() {
        _isLockEnabled = false;
        _isBiometricEnabled = false;
      });
      _showSnackBar('Đã tắt khóa ứng dụng', AppColors.danger);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      try {
        final success = await _authService.authenticateWithBiometric();
        if (!mounted) return;
        if (success) {
          await _authService.setBiometricEnabled(true);
          if (!mounted) return;
          setState(() => _isBiometricEnabled = true);
          _showSnackBar('Đã bật đăng nhập bằng vân tay 👆', AppColors.success);
        } else {
          _showSnackBar('Xác thực vân tay thất bại', AppColors.warning);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Lỗi: $e', AppColors.danger);
      }
    } else {
      await _authService.setBiometricEnabled(false);
      if (!mounted) return;
      setState(() => _isBiometricEnabled = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),
    );
  }

  Future<void> _changePin() async {
    final verified = await _verifyCurrentPin();
    if (!mounted || !verified) return;

    final newPin = await _showSetPinDialog(title: 'Đặt PIN mới');
    if (!mounted) return;
    if (newPin != null && newPin.isNotEmpty) {
      await _authService.setPin(newPin);
      if (!mounted) return;
      _showSnackBar('Đã đổi PIN thành công ✅', AppColors.success);
    }
  }

  Future<bool> _verifyCurrentPin() async {
    final pinController = TextEditingController();
    bool verified = false;
    String? errorMessage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
          title: Text('Xác nhận PIN', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Nhập PIN hiện tại',
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final valid = await _authService.verifyPin(pinController.text);
                if (dialogContext.mounted) {
                  if (valid) {
                    verified = true;
                    Navigator.pop(dialogContext);
                  } else {
                    setDialogState(() => errorMessage = 'PIN không đúng!');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                elevation: 0,
              ),
              child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    pinController.dispose();
    return verified;
  }

  Future<String?> _showSetPinDialog({String title = 'Đặt PIN mới'}) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? result;
    String? errorMessage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
          title: Text(title, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Nhập PIN (4-6 số)',
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Xác nhận PIN',
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = pinController.text;
                final confirm = confirmController.text;

                if (pin.length < 4) {
                  setDialogState(() => errorMessage = 'PIN phải có ít nhất 4 số');
                  return;
                }

                if (pin != confirm) {
                  setDialogState(() => errorMessage = 'PIN xác nhận không khớp!');
                  return;
                }

                result = pin;
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                elevation: 0,
              ),
              child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo mật'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Hero Section with Lock Icon
                _buildHeroSection(isDark),
                const SizedBox(height: 24),

                // Settings Group
                _buildSectionHeader('Cài đặt bảo mật', isDark),
                const SizedBox(height: 12),
                
                // Main lock toggle
                _buildMainToggle(isDark),
                const SizedBox(height: 12),

                if (_isLockEnabled) ...[
                  if (_isBiometricAvailable) ...[
                    _buildBiometricToggle(isDark),
                    const SizedBox(height: 12),
                  ],
                  _buildChangePinTile(isDark),
                  const SizedBox(height: 24),
                  
                  _buildInfoCard(isDark),
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
              gradient: _isLockEnabled ? AppGradients.heroBlue : null,
              color: _isLockEnabled ? null : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
              shape: BoxShape.circle,
              boxShadow: _isLockEnabled ? AppShadows.heroLight : null,
            ),
            child: Icon(
              _isLockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 36,
              color: _isLockEnabled ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isLockEnabled ? 'Ứng dụng đang được bảo vệ' : 'Bảo mật đang tắt',
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
              _isLockEnabled 
                  ? 'Dữ liệu của bạn đã được mã hóa và bảo vệ bằng mã PIN'
                  : 'Hãy bật khóa ứng dụng để bảo vệ dữ liệu tài chính của bạn',
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
          color: _isLockEnabled ? AppColors.primary.withOpacity(0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLockEnabled ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1) : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(
                Icons.security_rounded,
                color: _isLockEnabled ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Khóa ứng dụng',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Yêu cầu mật khẩu khi mở app',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isLockEnabled,
              onChanged: _toggleLock,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        boxShadow: isDark ? null : AppShadows.cardLight,
        border: Border.all(
          color: _isBiometricEnabled ? AppColors.success.withOpacity(0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBiometricEnabled ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1) : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: _isBiometricEnabled ? AppColors.success : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đăng nhập bằng vân tay',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sử dụng vân tay thay vì nhập PIN',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isBiometricEnabled,
              onChanged: _toggleBiometric,
              activeColor: AppColors.success,
              activeTrackColor: AppColors.success.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePinTile(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _changePin,
        borderRadius: AppRadius.borderLg,
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
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Icon(
                  Icons.password_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đổi PIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thay đổi mã PIN hiện tại',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withValues(alpha: isDark ? 0.15 : 0.08),
            AppColors.infoDark.withValues(alpha: isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(Icons.info_outline_rounded, color: AppColors.info, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Dữ liệu tài chính của bạn sẽ được bảo vệ. Mỗi khi mở app, bạn cần nhập PIN hoặc xác thực vân tay.',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
