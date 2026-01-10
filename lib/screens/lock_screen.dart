import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

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
  
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = false;
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
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _isBiometricEnabled = enabled;
      });
      
      // Auto-trigger biometric on load
      if (available && enabled) {
        // Biometrics initialized, but we wait for user to press "Đăng nhập"
      }
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
        // Shake animation on wrong PIN
        _shakeController.forward().then((_) => _shakeController.reset());
        setState(() => _errorText = 'PIN không đúng');
        _pinController.clear();
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _onPinChanged(String value) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    // Auto-submit when 4-6 digits entered
    if (value.length >= 4 && value.length <= 6) {
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.05),
              colorScheme.primary.withOpacity(0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Logo and Icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_filled, color: colorScheme.primary, size: 32),
                        const SizedBox(width: 8),
                        Text(
                          'OverTime',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: const Text('🇻🇳', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.notifications_none, color: Colors.grey.shade700),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 1),
              
              // App Logo and Branding
              Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.work_history,
                          size: 60,
                          color: colorScheme.primary,
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
                      color: colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quản lý OT & Tài chính cá nhân',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 1),
              
              // Greeting Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chúc bạn một ngày tốt lành 👋',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'ANH ĐÔ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.qr_code_2, color: colorScheme.primary, size: 24),
                              const Text('QR của tôi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Main Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _authenticateWithBiometric,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isBiometricAvailable && _isBiometricEnabled) ...[
                            const Icon(Icons.fingerprint, size: 24),
                            const SizedBox(width: 12),
                          ],
                          const Text(
                            'Đăng nhập',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // PIN Input (Subtle)
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Focus PIN field if needed or show a dialog
                            },
                            child: Text(
                              'Hoặc nhập mã PIN',
                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
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
                            child: SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _pinController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                  color: colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '••••',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade300,
                                    letterSpacing: 8,
                                  ),
                                  border: InputBorder.none,
                                  errorText: _errorText,
                                  errorStyle: const TextStyle(fontSize: 12),
                                ),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: _onPinChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Quick Action Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickAction(Icons.security, 'Smart OTP', colorScheme.primary),
                        _buildQuickAction(Icons.qr_code_scanner, 'Quét QR', colorScheme.primary),
                        _buildQuickAction(Icons.notifications_active, 'Cảnh báo', colorScheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange.shade400, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBottomIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey.shade700, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
