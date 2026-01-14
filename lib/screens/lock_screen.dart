import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Lock screen with PIN input and fingerprint authentication
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = false;
  int _maxPin = 4; // Dynamic PIN length
  String? _errorText;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final available = await _authService.isBiometricAvailable();
    final enabled = await _authService.isBiometricEnabled();
    final pinLength = await _authService.getPinLength();
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _isBiometricEnabled = enabled;
        _maxPin = pinLength;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() => _isLoading = true);
    
    final success = await _authService.authenticateWithBiometric();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onUnlocked();
      }
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text;
    if (pin.length < 4) {
      setState(() => _errorText = 'PIN phải có ít nhất 4 số');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final success = await _authService.verifyPin(pin);
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        widget.onUnlocked();
      } else {
        _shakeController.forward().then((_) => _shakeController.reset());
        setState(() => _errorText = 'PIN không đúng');
        _pinController.clear();
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _onPinChanged(String value) {
    setState(() {
      if (_errorText != null) {
        _errorText = null;
      }
    });
    
    if (value.length == _maxPin) {
      _verifyPin();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark 
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.darkBackground, AppColors.darkSurface],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.03),
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header
                  _buildHeader(isDark),
                  
                  // App Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: _buildAppLogo(isDark),
                  ),
                  
                  // Login Card
                  _buildLoginCard(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroBlue,
                  borderRadius: AppRadius.borderSm,
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'OverTime',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.danger, width: 2),
                ),
                child: const Text('🇻🇳', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.notifications_none_rounded,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogo(bool isDark) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: AppRadius.borderXl,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderXl,
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.heroBlue,
                  borderRadius: AppRadius.borderXl,
                ),
                child: const Icon(Icons.work_history_rounded, size: 48, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sổ Tay Công Việc',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quản lý OT & Tài chính cá nhân',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.borderXl,
        boxShadow: isDark ? null : AppShadows.cardLight,
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chúc bạn một ngày tốt lành 👋',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ANH ĐÔ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(height: 2),
                      Text(
                        'QR của tôi',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // Login Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppGradients.heroBlue,
                borderRadius: AppRadius.borderFull,
                boxShadow: AppShadows.heroLight,
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticateWithBiometric,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isBiometricAvailable && _isBiometricEnabled) ...[
                            const Icon(Icons.fingerprint_rounded, size: 24, color: Colors.white),
                            const SizedBox(width: 12),
                          ],
                          const Text(
                            'Đăng nhập',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // PIN Input
            Center(
              child: Column(
                children: [
                  Text(
                    'Hoặc nhập mã PIN',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * ((_shakeController.value < 0.5) ? 1 : -1), 0),
                        child: child,
                      );
                    },
                    child: _buildPinInput(isDark),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(Icons.security_rounded, 'Smart OTP', isDark),
                _buildQuickAction(Icons.qr_code_scanner_rounded, 'Quét QR', isDark),
                _buildQuickAction(Icons.notifications_active_rounded, 'Cảnh báo', isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinInput(bool isDark) {
    final pinLength = _pinController.text.length;
    
    return Column(
      children: [
        SizedBox(
          width: 40.0 * _maxPin + 8.0 * (_maxPin - 1),
          height: 50,
          child: Stack(
            children: [
              // Visual PIN boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_maxPin, (index) {
                  final isFilled = index < pinLength;
                  final isActive = index == pinLength && _pinFocusNode.hasFocus;
                  
                  return Container(
                    width: 40,
                    height: 48,
                    margin: EdgeInsets.only(right: index < _maxPin - 1 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? (isFilled ? AppColors.primary.withValues(alpha: 0.1) : AppColors.darkSurfaceVariant)
                          : (isFilled ? AppColors.primary.withValues(alpha: 0.05) : AppColors.lightSurfaceVariant),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: _errorText != null 
                            ? AppColors.danger
                            : (isActive 
                                ? AppColors.primary 
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: isFilled 
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: AppGradients.heroBlue,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
              ),
              // Hidden TextField
              Positioned.fill(
                child: TextField(
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  keyboardType: TextInputType.number,
                  autofocus: false,
                  maxLength: _maxPin,
                  showCursor: false,
                  cursorColor: Colors.transparent,
                  enableInteractiveSelection: false,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onPinChanged,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: AppRadius.borderMd,
          ),
          child: Icon(icon, color: AppColors.accent, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
