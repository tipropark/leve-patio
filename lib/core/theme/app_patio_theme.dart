import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_patio_colors.dart';

abstract final class AppPatioTheme {
  static const double buttonHeight  = 56.0;
  static const double inputHeight   = 56.0;
  static const double cardRadius    = 12.0;
  static const double buttonRadius  = 10.0;

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      displayLarge:  const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppPatioColors.onSurface),
      titleLarge:    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppPatioColors.onSurface),
      titleMedium:   const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppPatioColors.onSurface),
      bodyLarge:     const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppPatioColors.onSurface),
      bodyMedium:    const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppPatioColors.onSurfaceVariant),
      labelLarge:    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppPatioColors.onSurfaceVariant, letterSpacing: 0.08 * 12),
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary:              AppPatioColors.primary,
        onPrimary:            AppPatioColors.onPrimary,
        primaryContainer:     AppPatioColors.primaryContainer,
        onPrimaryContainer:   AppPatioColors.onPrimaryContainer,
        secondary:            AppPatioColors.secondary,
        onSecondary:          AppPatioColors.onSecondary,
        secondaryContainer:   AppPatioColors.secondaryContainer,
        surface:              AppPatioColors.surface,
        onSurface:            AppPatioColors.onSurface,
        surfaceContainerHigh: AppPatioColors.surfaceContainerHigh,
        onSurfaceVariant:     AppPatioColors.onSurfaceVariant,
        outline:              AppPatioColors.outline,
        outlineVariant:       AppPatioColors.outlineVariant,
        error:                AppPatioColors.error,
        onError:              AppPatioColors.onError,
      ),
      scaffoldBackgroundColor: AppPatioColors.background,
      textTheme: textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor:  Colors.transparent,
        foregroundColor:  AppPatioColors.secondary,
        elevation:        0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:      Colors.transparent,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color:      AppPatioColors.secondary,
          fontSize:   20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize:   const Size.fromHeight(buttonHeight),
          backgroundColor: AppPatioColors.secondary,
          foregroundColor: AppPatioColors.onSecondary,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize:   const Size.fromHeight(buttonHeight),
          foregroundColor: AppPatioColors.secondary,
          side: const BorderSide(color: AppPatioColors.secondary, width: 1.5),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPatioColors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppPatioColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppPatioColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppPatioColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppPatioColors.error),
        ),
        hintStyle: const TextStyle(color: AppPatioColors.outline),
        labelStyle: const TextStyle(color: AppPatioColors.onSurfaceVariant),
        prefixIconColor: AppPatioColors.onSurfaceVariant,
        suffixIconColor: AppPatioColors.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppPatioColors.glassFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppPatioColors.glassBorder),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppPatioColors.outlineVariant,
        thickness: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppPatioColors.secondary,
        unselectedItemColor: AppPatioColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
