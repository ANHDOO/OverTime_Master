import 'package:flutter/material.dart';
import 'main_screen.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
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
        } else {
          debugPrint('Notification permission not granted!');
        }
      } catch (e) {
        debugPrint('Notification setup failed: $e');
      }
    });

    // Check for updates
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      try {
        final updateService = UpdateService();
        final result = await updateService.checkForUpdate();
        
        if (!mounted) return;
        
        if (result.hasUpdate && result.updateInfo != null) {
          final shouldUpdate = await updateService.showUpdateDialog(context, result.updateInfo!);
          if (shouldUpdate == true && mounted) {
            updateService.downloadInBackground();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đang tải bản cập nhật ngầm...')),
            );
          }
        } else if (result.error != null) {
          debugPrint('⚠️ Update check error: ${result.error}');
        }
      } catch (e) {
        debugPrint('❌ Update check failed: $e');
      }
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.access_time_filled,
                        size: 70,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Sổ Tay Công Việc',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Quản lý tăng ca thông minh',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
