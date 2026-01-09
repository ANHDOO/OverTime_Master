import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app lock (PIN + Biometric authentication)
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // SharedPreferences keys
  static const String _keyLockEnabled = 'app_lock_enabled';
  static const String _keyPin = 'app_lock_pin';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Get biometrics error: $e');
      return [];
    }
  }

  // Authenticate with biometric (fingerprint/face) or device credentials
  Future<bool> authenticateWithBiometric() async {
    try {
      // First check what's available
      final biometrics = await getAvailableBiometrics();
      debugPrint('Available biometrics: $biometrics');
      
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực để mở OverTime',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern fallback if no fingerprint
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric auth general error: $e');
      return false;
    }
  }

  // === PIN Management ===

  // Check if app lock is enabled
  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLockEnabled) ?? false;
  }

  // Enable/Disable app lock
  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockEnabled, enabled);
    if (!enabled) {
      // Clear PIN when disabling
      await prefs.remove(_keyPin);
      await prefs.setBool(_keyBiometricEnabled, false);
    }
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPin) != null;
  }

  // Set PIN (4-6 digits)
  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
    return true;
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_keyPin);
    return savedPin == pin;
  }

  // Remove PIN
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPin);
  }

  // === Biometric Setting ===

  // Check if biometric unlock is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  // Enable/Disable biometric unlock
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  // === Full Authentication Flow ===

  // Perform authentication (try biometric first, then fall back to PIN)
  Future<AuthResult> authenticate() async {
    final isEnabled = await isLockEnabled();
    if (!isEnabled) {
      return AuthResult(success: true, method: AuthMethod.none);
    }

    final biometricEnabled = await isBiometricEnabled();
    final biometricAvailable = await isBiometricAvailable();

    // Try biometric first if enabled and available
    if (biometricEnabled && biometricAvailable) {
      final success = await authenticateWithBiometric();
      if (success) {
        return AuthResult(success: true, method: AuthMethod.biometric);
      }
    }

    // Fall back to PIN
    return AuthResult(success: false, method: AuthMethod.pin);
  }
}

enum AuthMethod { none, pin, biometric }

class AuthResult {
  final bool success;
  final AuthMethod method;
  
  AuthResult({required this.success, required this.method});
}
