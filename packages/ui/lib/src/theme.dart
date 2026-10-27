import 'package:flutter/material.dart';

/// Tema aplikacije: boje, font Inter i izgled zajedničkih komponenti.
abstract final class CarWashTheme {
  static const brandColor = Color(0xFF0B5CAD);

  /// Zaobljenja: mala (polja, čipovi), srednja (dugmad), velika (kartice) i najveća (hero, dijalozi).
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 22.0;
  static const radiusXl = 28.0;

  /// Razmak od ivice ekrana.
  static const gutter = 20.0;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B5CAD), Color(0xFF1C8BE8), Color(0xFF3FB6F0)],
  );

  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seeded = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return isDark
        ? seeded.copyWith(
            primary: const Color(0xFF6CB4FF),
            onPrimary: const Color(0xFF00213F),
            surface: const Color(0xFF0E1A26),
            onSurface: const Color(0xFFE7EEF6),
            onSurfaceVariant: const Color(0xFF95A6BA),
            surfaceContainerLowest: const Color(0xFF152333),
            surfaceContainerLow: const Color(0xFF152333),
            surfaceContainer: const Color(0xFF1B2C3F),
            surfaceContainerHigh: const Color(0xFF213449),
            surfaceContainerHighest: const Color(0xFF283D54),
            outlineVariant: const Color(0xFF243749),
          )
        : seeded.copyWith(
            primary: brandColor,
            onPrimary: Colors.white,
            surface: const Color(0xFFF4F8FC),
            onSurface: const Color(0xFF0F1B2A),
            onSurfaceVariant: const Color(0xFF5B6B7F),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Colors.white,
            surfaceContainer: const Color(0xFFEBF1F7),
            surfaceContainerHigh: const Color(0xFFE3EAF2),
            surfaceContainerHighest: const Color(0xFFDCE4EE),
            outlineVariant: const Color(0xFFE2E9F1),
          );
  }

  static TextTheme _text(TextTheme base, ColorScheme scheme) {
    TextStyle? tight(TextStyle? style, FontWeight weight, double spacing) =>
        style?.copyWith(fontWeight: weight, letterSpacing: spacing);
    return base
        .copyWith(
          displayMedium: tight(base.displayMedium, FontWeight.w700, -1.5),
          displaySmall: tight(base.displaySmall, FontWeight.w700, -1.2),
          headlineLarge: tight(base.headlineLarge, FontWeight.w700, -1),
          headlineMedium: tight(base.headlineMedium, FontWeight.w700, -0.8),
          headlineSmall: tight(base.headlineSmall, FontWeight.w700, -0.5),
          titleLarge: tight(base.titleLarge, FontWeight.w700, -0.3),
          titleMedium: tight(base.titleMedium, FontWeight.w600, -0.1),
          titleSmall: tight(base.titleSmall, FontWeight.w600, 0),
          labelLarge: tight(base.labelLarge, FontWeight.w600, 0),
          labelMedium: tight(base.labelMedium, FontWeight.w600, 0.1),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final text = _text(ThemeData(brightness: brightness, fontFamily: 'packages/ui/Inter').textTheme, scheme);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));
    final buttonText = text.labelLarge?.copyWith(fontSize: 16);
    OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'packages/ui/Inter',
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          // U tamnoj temi tanka ivica zamenjuje senku koja se ne vidi.
          side: isDark ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 56), shape: buttonShape, textStyle: buttonText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: text.labelLarge)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: field(scheme.outlineVariant),
        enabledBorder: field(scheme.outlineVariant),
        focusedBorder: field(scheme.primary, 2),
        errorBorder: field(scheme.error),
        focusedErrorBorder: field(scheme.error, 2),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        titleTextStyle: text.headlineSmall,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        insetPadding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    );
  }
}
