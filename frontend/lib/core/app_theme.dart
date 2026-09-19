import 'package:flutter/material.dart';

abstract final class AppColors {
  // 앱 전체 기본 배경색
  static const appBackground = Color(0xFFF1E8D7);
  static const forest = Color(0xFF254B42);
  static const forestLight = Color(0xFF37695D);
  static const sage = Color(0xFFDCE7DF);
  static const cream = Color(0xFFF1E8D7);
  static const paper = Color(0xFFF1E8D7);
  static const gold = Color(0xFFC79B52);
  static const goldLight = Color(0xFFE7D9BA);
  static const ink = Color(0xFF4A382C);
  static const muted = Color(0xFF7C7065);
  static const line = Color(0xFFE0CDA7);
  static const success = Color(0xFF58A17D);
  static const warning = Color(0xFFE3A958);
  static const danger = Color(0xFFD96B5F);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.light,
      primary: AppColors.forest,
      secondary: AppColors.gold,
      surface: AppColors.paper,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF1E8D7),
      fontFamily: 'MaruBuri',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: 'MaruBuri',
          color: AppColors.ink,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.18,
          letterSpacing: -1.4,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'MaruBuri',
          color: AppColors.ink,
          fontSize: 23,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
          fontFamily: 'MaruBuri',
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleMedium: TextStyle(
          fontFamily: 'MaruBuri',
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'WantedSans',
          color: AppColors.ink,
          fontSize: 15,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'WantedSans',
          color: AppColors.muted,
          fontSize: 13,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          fontFamily: 'WantedSans',
          color: AppColors.muted,
          fontSize: 11,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: 'WantedSans',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFBF3),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x14254B42)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: const Color(0xFFFFFDF8),
        hintStyle: const TextStyle(
          fontFamily: 'WantedSans',
          color: Color(0xFF9AA49F),
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0x14254B42)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(
            fontFamily: 'WantedSans',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: 'WantedSans',
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'WantedSans',
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFFFFFBF3),
        indicatorColor: AppColors.sage.withValues(alpha: 0.72),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: 'WantedSans',
            color: states.contains(WidgetState.selected)
                ? AppColors.forest
                : const Color(0xFF97A19D),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.forest
                : const Color(0xFF97A19D),
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'WantedSans',
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: AppColors.line,
    );
  }
}

BoxDecoration softCardDecoration({double radius = 22}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0x12254B42)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12233A31),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    );
