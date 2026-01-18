import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main_screen.dart';
import 'lock_screen.dart';
import '../../logic/providers/cash_transaction_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/update_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/backup_service.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.splash,
    );

    // Pulse animation for the icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.forward();

    // Initialize notifications after a short delay (UI loaded first)
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final notificationService = NotificationService();
        await notificationService.init();
        debugPrint('Notification Service Initialized');
        
        final granted = await notificationService.requestPermissions();
        debugPrint('Notification Permission Granted: $granted');
        
        if (granted == true) {
          // PRODUCTION: Schedule notification lúc 23h
          await notificationService.scheduleDailyNotification(testMode: false);
          
          // Lên lịch nhắc VAT cho các giao dịch cần lấy hóa đơn
          if (mounted) {
            // Đảm bảo dữ liệu đã được load trước khi quét
            final provider = Provider.of<CashTransactionProvider>(context, listen: false);
            if (provider.cashTransactions.isEmpty) {
              await provider.fetchCashTransactions();
            }
            _scheduleVatReminders(notificationService);
          }
        } else {
          debugPrint('Notification permission not granted!');
        }
      } catch (e) {
        debugPrint('Notification setup failed: $e');
      }
    });

    // Check for updates (delay 5s để app load xong rồi mới hiện dialog)
    Future.delayed(const Duration(milliseconds: 5000), () async {
      if (!mounted) return;
      try {
        final updateService = UpdateService();
        final notificationService = NotificationService();
        final result = await updateService.checkForUpdate();
        
        if (!mounted) return;
        
        if (result.hasUpdate && result.updateInfo != null) {
          // Hiển thị notification trên thanh thông báo
          await notificationService.showUpdateAvailableNotification(result.updateInfo!.versionName);
          
          final shouldUpdate = await updateService.showUpdateDialog(context, result.updateInfo!);
          if (shouldUpdate == true && mounted) {
            // Thêm listener để theo dõi khi tải xong
            void onUpdateStatusChanged() {
              if (updateService.status == DownloadStatus.readyToInstall) {
                updateService.removeListener(onUpdateStatusChanged);
                // Thông báo trên thanh notification bar
                notificationService.showUpdateDownloadedNotification(result.updateInfo!.versionName);
              } else if (updateService.status == DownloadStatus.error) {
                updateService.removeListener(onUpdateStatusChanged);
                // Thông báo lỗi trên thanh notification bar
                notificationService.showUpdateErrorNotification(updateService.error ?? 'Không thể tải bản cập nhật');
              }
            }
            
            updateService.addListener(onUpdateStatusChanged);
            updateService.downloadInBackground();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang tải bản cập nhật ngầm...')),
              );
            }
          }
        } else if (result.error != null) {
          debugPrint('⚠️ Update check error: ${result.error}');
        }
      } catch (e) {
        debugPrint('❌ Update check failed: $e');
      }
    });

    // Silent Sign-In Google Drive (Global)
    Future.delayed(const Duration(milliseconds: 1000), () async {
      try {
        final backupService = BackupService();
        await backupService.initializeGoogleSignIn();
        final success = await backupService.signInSilently();
        debugPrint('Global Silent Sign-In: $success');
        // Không cần gọi autoRestoreMissingImages() ở đây
        // vì nó đã được gọi trong backup_screen.dart khi Khôi phục
      } catch (e) {
        debugPrint('Global Silent Sign-In error: $e');
      }
    });

    // Navigate after splash animation - check for app lock
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      
      final authService = AuthService();
      final isLockEnabled = await authService.isLockEnabled();
      
      if (!mounted) return;
      
      if (isLockEnabled) {
        // Show lock screen first
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreen(
              onUnlocked: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: AppDurations.slow,
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // Go directly to main screen
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: AppDurations.slow,
          ),
        );
      }
    });
  }

  /// Lên lịch nhắc lấy VAT cho các giao dịch cần thiết
  void _scheduleVatReminders(NotificationService notificationService) {
    try {
      final provider = Provider.of<CashTransactionProvider>(context, listen: false);
      final pendingTransactions = provider.getPendingVatTransactions();
      
      debugPrint('📋 Found ${pendingTransactions.length} transactions needing VAT reminder');
      
      for (final transaction in pendingTransactions) {
        if (transaction.id == null) continue;
        
        // Format số tiền
        final amountStr = '${transaction.amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}đ';
        
        notificationService.scheduleVatReminder(
          transactionId: transaction.id!,
          description: transaction.description,
          amount: amountStr,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling VAT reminders: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AppGradients.heroBlueDark : AppGradients.heroBlue,
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -100,
              right: -100,
              child: _buildDecorativeCircle(250, 0.08),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: _buildDecorativeCircle(200, 0.06),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: -50,
              child: _buildDecorativeCircle(100, 0.04),
            ),
            
            // Main content
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon with pulse effect
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(36),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 60,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Inner gradient decoration
                                      Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(28),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withOpacity(0.05),
                                              AppColors.primary.withOpacity(0.02),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                      ),
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [AppColors.primary, AppColors.primaryDark],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds),
                                        child: const Icon(
                                          Icons.access_time_filled_rounded,
                                          size: 70,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // App Title
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFE2E8F0)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(bounds),
                                child: const Text(
                                  'Sổ Tay Công Việc',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Quản lý tăng ca thông minh',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                      
                      // Loading indicator
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
