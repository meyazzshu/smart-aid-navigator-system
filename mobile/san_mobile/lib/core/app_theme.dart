import 'package:flutter/material.dart';

class AppColors {
  static const Color darkAzure = Color(0xFF03466E);
  static const Color azure = Color(0xFF54AFE6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkGrey = Color(0xFF242424);
}

class AppTheme {
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkAzure,
      brightness: Brightness.light,
      primary: AppColors.darkAzure,
      secondary: AppColors.azure,
      surface: AppColors.white,
      background: AppColors.white,
      error: const Color(0xFFD32F2F),
    ).copyWith(
      onPrimary: AppColors.white,
      onSecondary: AppColors.darkAzure,
      onSurface: AppColors.darkGrey,
      onError: AppColors.white,
    );

    final base = ThemeData.light();
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.darkGrey,
      displayColor: AppColors.darkGrey,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkAzure,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.azure.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.azure.withOpacity(0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.azure.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkAzure, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.darkGrey),
        hintStyle: TextStyle(color: AppColors.darkGrey.withOpacity(0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkAzure,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkAzure,
          side: const BorderSide(color: AppColors.darkAzure),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.azure,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.azure,
        foregroundColor: AppColors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.azure.withOpacity(0.12),
        selectedColor: AppColors.darkAzure.withOpacity(0.18),
        labelStyle: const TextStyle(
          color: AppColors.darkGrey,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.darkAzure,
          fontWeight: FontWeight.w700,
        ),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.azure.withOpacity(0.35)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.darkAzure,
        unselectedItemColor: AppColors.darkGrey.withOpacity(0.6),
        showUnselectedLabels: true,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.azure.withOpacity(0.2),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.darkAzure,
        textColor: AppColors.darkGrey,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkGrey,
        contentTextStyle: const TextStyle(color: AppColors.white),
        actionTextColor: AppColors.azure,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
