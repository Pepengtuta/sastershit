import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/barangay/barangay_main_screen.dart';
import 'screens/pcf/pcf_main_screen.dart';
import 'screens/pho/pho_main_screen.dart';
import 'screens/superadmin/superadmin_main_screen.dart';
import 'services/auth_service.dart';
import 'services/offline_report_sync.dart';
import 'services/offline_sync_coordinator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SasterApp());
}


class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> restoreFuture;

  @override
  void initState() {
    super.initState();
    restoreFuture = AuthService.restoreSession().then((restored) {
      if (restored) {
        // Session restored: flush any reports queued before the app closed.
        OfflineReportSync.instance.syncForCurrentUser();
        // Global offline-first bootstrap for the restored session.
        OfflineSyncCoordinator.instance.refreshFromStore();
        OfflineSyncCoordinator.instance.syncNow();
      }
      return restored;
    });
  }

  Widget _screenForRole(String? role) {
    final normalizedRole = role?.toLowerCase() ?? '';

    if (normalizedRole == 'barangay' || normalizedRole == 'brgy') {
      return const BarangayMainScreen();
    }

    if (normalizedRole == 'pcf' || normalizedRole == 'pfc') {
      return const PcfMainScreen();
    }

    if (normalizedRole == 'pho') {
      return const PhoMainScreen();
    }

    if (normalizedRole == 'superadmin' || normalizedRole == 'admin') {
      return const SuperadminMainScreen();
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: restoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == true) {
          return _screenForRole(AuthService.currentRole);
        }

        return const LoginScreen();
      },
    );
  }
}

class SasterApp extends StatefulWidget {
  const SasterApp({super.key});

  @override
  State<SasterApp> createState() => _SasterAppState();
}

class _SasterAppState extends State<SasterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OfflineReportSync.instance.init();
    OfflineSyncCoordinator.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OfflineReportSync.instance.dispose();
    OfflineSyncCoordinator.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Connectivity may have returned while the app was backgrounded, so
      // flush queued reports and run ONE coordinated retry (health check
      // first, then offline-data sync) rather than a blind sync.
      OfflineReportSync.instance.syncForCurrentUser();
      OfflineSyncCoordinator.instance.handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ugyon',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SessionGate(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      brightness: Brightness.light,
      primary: AppColors.primaryRed,
      secondary: AppColors.primaryBlue,
      tertiary: AppColors.warningYellow,
      surface: AppColors.card,
      onSurface: AppColors.textDark,
      error: AppColors.primaryRed,
    );

    final scaffoldBackground = AppColors.background;
    final cardColor = AppColors.card;
    final borderColor = AppColors.border;
    final mutedText = AppColors.textMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardColor,
      dividerColor: borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.webSidebar,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.webSidebar,
        indicatorColor: Colors.white.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected) ? Colors.white : Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? Colors.white : Colors.white.withValues(alpha: 0.6),
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        bodySmall: TextStyle(color: mutedText),
        titleLarge: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        titleSmall: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: mutedText,
        subtitleTextStyle: TextStyle(color: mutedText),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primaryRed.withValues(alpha: 0.14),
        secondarySelectedColor: AppColors.primaryRed.withValues(alpha: 0.14),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSurface),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
    );
  }
}
