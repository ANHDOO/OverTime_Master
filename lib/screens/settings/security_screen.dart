import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';

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
      // Enable lock - need to set PIN first
      final pin = await _showSetPinDialog();
      if (!mounted) return;
      if (pin != null && pin.isNotEmpty) {
        await _authService.setPin(pin);
        await _authService.setLockEnabled(true);
        if (!mounted) return;
        setState(() {
          _isLockEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã bật khóa ứng dụng 🔐')),
        );
      }
    } else {
      // Disable lock - verify current PIN first
      final verified = await _verifyCurrentPin();
      if (!mounted) return;
      if (verified) {
        await _authService.setLockEnabled(false);
        if (!mounted) return;
        setState(() {
          _isLockEnabled = false;
          _isBiometricEnabled = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã tắt khóa ứng dụng')));
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Test biometric first
      try {
        final success = await _authService.authenticateWithBiometric();
        if (!mounted) return;
        if (success) {
          await _authService.setBiometricEnabled(true);
          if (!mounted) return;
          setState(() => _isBiometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã bật đăng nhập bằng vân tay 👆')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác thực vân tay thất bại. Vui lòng thử lại.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Biometric toggle error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      await _authService.setBiometricEnabled(false);
      if (!mounted) return;
      setState(() => _isBiometricEnabled = false);
    }
  }

  Future<void> _changePin() async {
    // Verify current PIN first
    final verified = await _verifyCurrentPin();
    if (!mounted || !verified) return;

    // Set new PIN
    final newPin = await _showSetPinDialog(title: 'Đặt PIN mới');
    if (!mounted) return;
    if (newPin != null && newPin.isNotEmpty) {
      await _authService.setPin(newPin);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã đổi PIN thành công ✅')));
    }
  }

  Future<bool> _verifyCurrentPin() async {
    final pinController = TextEditingController();
    bool verified = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Xác nhận PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nhập PIN hiện tại',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
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
              child: const Text('Xác nhận'),
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

    // Capture parent context before showing dialog

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nhập PIN (4-6 số)',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận PIN',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = pinController.text;
                final confirm = confirmController.text;

                if (pin.length < 4) {
                  setDialogState(
                    () => errorMessage = 'PIN phải có ít nhất 4 số',
                  );
                  return;
                }

                if (pin != confirm) {
                  setDialogState(
                    () => errorMessage = 'PIN xác nhận không khớp!',
                  );
                  return;
                }

                result = pin;
                Navigator.pop(dialogContext);
              },
              child: const Text('Lưu'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Bảo mật'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Lock icon
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Icon(
                    _isLockEnabled ? Icons.lock : Icons.lock_open,
                    size: 64,
                    color: _isLockEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),

                // Main lock toggle
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Khóa ứng dụng',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Yêu cầu mật khẩu khi mở app'),
                    secondary: const Icon(Icons.lock_outline),
                    value: _isLockEnabled,
                    onChanged: _toggleLock,
                  ),
                ),

                const SizedBox(height: 16),

                // Options when lock is enabled
                if (_isLockEnabled) ...[
                  // Biometric toggle
                  if (_isBiometricAvailable)
                    Card(
                      child: SwitchListTile(
                        title: const Text('Đăng nhập bằng vân tay'),
                        subtitle: const Text(
                          'Sử dụng vân tay thay vì nhập PIN',
                        ),
                        secondary: const Icon(Icons.fingerprint),
                        value: _isBiometricEnabled,
                        onChanged: _toggleBiometric,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Change PIN
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.pin),
                      title: const Text('Đổi PIN'),
                      subtitle: const Text('Thay đổi mã PIN hiện tại'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePin,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dữ liệu tài chính của bạn sẽ được bảo vệ. '
                            'Mỗi khi mở app, bạn cần nhập PIN hoặc xác thực vân tay.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
