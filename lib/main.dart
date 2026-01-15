import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/overtime_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

import 'package:intl/date_symbol_data_local.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  final navigatorKey = GlobalKey<NavigatorState>();
  
  // pass navigatorKey to NotificationService to handle notification taps
  NotificationService().setNavigatorKey(navigatorKey);
  // Ensure notification plugin initialized before providers schedule reminders
  // This also initializes the consolidated background service
  await NotificationService().init();
  
  // Cleanup old files on first launch of new version
  await StorageService.performFirstLaunchCleanup();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OvertimeProvider()..fetchEntries()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: OvertimeApp(navigatorKey: navigatorKey),
    ),
  );
}

class OvertimeApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const OvertimeApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Set system UI overlay style based on current theme
        final isDark = themeProvider.themeMode == ThemeMode.dark ||
            (themeProvider.themeMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        
        SystemChrome.setSystemUIOverlayStyle(
          isDark
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: AppColors.darkSurface,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: AppColors.lightSurface,
                ),
        );

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Sổ Tay Công Việc',
          debugShowCheckedModeBanner: false,
          locale: const Locale('vi', 'VN'),
          supportedLocales: const [
            Locale('vi', 'VN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // 🎨 New Theme System with Dark Mode Toggle
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
