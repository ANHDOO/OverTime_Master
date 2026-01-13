import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/overtime_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/background_service.dart';

import 'package:intl/date_symbol_data_local.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  final navigatorKey = GlobalKey<NavigatorState>();
  // pass navigatorKey to NotificationService to handle notification taps
  NotificationService().setNavigatorKey(navigatorKey);
  // Ensure notification plugin initialized before providers schedule reminders
  await NotificationService().init();
  
  // Cleanup old files on first launch of new version
  await StorageService.performFirstLaunchCleanup();
  
  // Initialize background gold price monitoring
  await initializeBackgroundService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OvertimeProvider()..fetchEntries()),
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF1E88E5),
          secondary: const Color(0xFF0D47A1),
          surface: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: MaterialStatePropertyAll(const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          indicatorColor: const Color(0xFF1E88E5),
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 44.0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
