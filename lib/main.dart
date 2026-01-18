import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'logic/providers/overtime_provider.dart';
import 'logic/providers/debt_provider.dart';
import 'logic/providers/cash_transaction_provider.dart';
import 'logic/providers/citizen_profile_provider.dart';
import 'logic/providers/gold_provider.dart';
import 'logic/providers/theme_provider.dart';
import 'logic/providers/font_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'data/services/notification_service.dart';
import 'data/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/add_transaction_screen.dart';
import 'presentation/screens/edit_transaction_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

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
        ChangeNotifierProvider(create: (_) => DebtProvider()..fetchDebtEntries()),
        ChangeNotifierProvider(create: (_) => CashTransactionProvider()..fetchCashTransactions()),
        // Lazy load: không fetch khi khởi động để giảm lag
        ChangeNotifierProvider(create: (_) => CitizenProfileProvider()),
        ChangeNotifierProvider(create: (_) => GoldProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()..loadFont()),
      ],
      child: OvertimeApp(navigatorKey: navigatorKey),
    ),
  );
}

class OvertimeApp extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const OvertimeApp({super.key, this.navigatorKey});

  @override
  State<OvertimeApp> createState() => _OvertimeAppState();
}

class _OvertimeAppState extends State<OvertimeApp> {
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();

    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final imagePath = files.first.path;
    
    // Set the pending path in the provider
    final context = widget.navigatorKey?.currentContext;
    if (context != null) {
      Provider.of<CashTransactionProvider>(context, listen: false)
          .setPendingSharedImagePath(imagePath);
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, FontProvider>(
      builder: (context, themeProvider, fontProvider, child) {
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

        // Lấy font option từ FontProvider
        final selectedFont = fontProvider.selectedFont;

        return MaterialApp(
          navigatorKey: widget.navigatorKey,
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
          // 🎨 Theme với font động từ FontProvider
          theme: AppTheme.lightWithFont(selectedFont),
          darkTheme: AppTheme.darkWithFont(selectedFont),
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            // Xử lý route từ notification
            if (settings.name == '/edit_transaction') {
              final transactionId = settings.arguments as int?;
              if (transactionId != null) {
                // Lấy transaction từ provider
                final transaction = Provider.of<CashTransactionProvider>(
                  widget.navigatorKey!.currentContext!,
                  listen: false,
                ).getTransactionById(transactionId);
                
                if (transaction != null) {
                  return MaterialPageRoute(
                    builder: (context) => EditTransactionScreen(transaction: transaction),
                  );
                }
              }
            }
            return null;
          },
        );
      },
    );
  }
}
