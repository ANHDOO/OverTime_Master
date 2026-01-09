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
        _authenticateWithBiometric();
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 50,
                      color: colorScheme.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  const Text(
                    'OverTime',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Nhập PIN để mở khóa',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // PIN Input with shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * ((_shakeController.value < 0.5) ? 1 : -1), 0),
                        child: child,
                      );
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 16,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 16,
                          ),
                          border: InputBorder.none,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white, width: 2),
                          ),
                          errorText: _errorText,
                          errorStyle: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 14,
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _onPinChanged,
                        autofocus: !_isBiometricEnabled,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Fingerprint button
                  if (_isBiometricAvailable && _isBiometricEnabled)
                    Column(
                      children: [
                        Text(
                          'hoặc',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _isLoading ? null : _authenticateWithBiometric,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : const Icon(
                                    Icons.fingerprint,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vân tay',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
