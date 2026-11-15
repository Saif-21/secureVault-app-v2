import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'package:app/src/navigation/app_shell.dart';

void main() {
  runApp(const MyApp());
}

/// Root application widget configured with Electric Mint branding and balanced typography.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// Global notifier to switch between Light, Dark, and System themes.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Brand Primary Color: Electric Mint Green (#5CE65C) matching the navigation reference
  static const Color primaryGreen = Color(0xFF5CE65C);
  static const Color primaryGreenForeground = Color(0xFF0F1012);
  static const Color lightPrimaryGreen = Color(0xFF16A34A);

  static FThemeData _resolveTheme(Brightness brightness) {
    final isTouch =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    final FColors colors;
    if (brightness == Brightness.dark) {
      colors = FColors.neutralDark.copyWith(
        primary: primaryGreen,
        primaryForeground: primaryGreenForeground,
      );
    } else {
      colors = FColors.neutralLight.copyWith(
        primary: lightPrimaryGreen,
        primaryForeground: Colors.white,
      );
    }

    // Balanced typography: clean, legible, and comfortably proportioned
    final typography = FTypography.inherit(
      colors: colors,
      touch: isTouch,
    ).scale(sizeScalar: 0.96);

    return FThemeData(
      touch: isTouch,
      colors: colors,
      typography: typography,
    );
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final lightTheme = MyApp._resolveTheme(Brightness.light);
    final darkTheme = MyApp._resolveTheme(Brightness.dark);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MyApp.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Expense Tracker',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: FLocalizations.localizationsDelegates,
          supportedLocales: FLocalizations.supportedLocales,
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: MyApp.lightPrimaryGreen,
              primary: MyApp.lightPrimaryGreen,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: MyApp.primaryGreen,
              brightness: Brightness.dark,
              primary: MyApp.primaryGreen,
            ),
          ),
          themeMode: themeMode,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final fTheme = brightness == Brightness.dark ? darkTheme : lightTheme;
            return FTheme(
              data: fTheme,
              child: FToaster(
                child: FTooltipGroup(child: child!),
              ),
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}
