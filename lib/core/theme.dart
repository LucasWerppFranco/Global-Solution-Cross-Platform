import 'package:flutter/material.dart';

/// Tokens de espaçamento usados em todas as telas.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double radius = 16;
  static const page = EdgeInsets.all(md);
}

/// Duração padrão das animações. Com "reduzir movimento" ativo no sistema,
/// tudo vira instantâneo.
abstract final class AppMotion {
  static const medium = Duration(milliseconds: 900);

  static Duration of(BuildContext context, [Duration d = medium]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Cores da identidade "Território Vivo".
/// As cores de severidade são sempre usadas como fundo com texto branco
/// (contraste ≥ 4,5:1 nos temas claro, escuro e alto contraste).
abstract final class AppColors {
  static const seed = Color(0xFF0B6E69); // verde-azulado "território"
  static const info = Color(0xFF1E4E8C);
  static const attention = Color(0xFF8A4B00);
  static const critical = Color(0xFFB3261E);
}

abstract final class AppTheme {
  static ThemeData build(Brightness brightness, {bool highContrast = false}) {
    var scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    if (highContrast) {
      final dark = brightness == Brightness.dark;
      scheme = scheme.copyWith(
        surface: dark ? Colors.black : Colors.white,
        onSurface: dark ? Colors.white : Colors.black,
      );
    }
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final t = base.textTheme;
    final text = t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: BorderSide(
            color: highContrast ? scheme.onSurface : scheme.outlineVariant,
            width: highContrast ? 2 : 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: shape,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      // Transição "para frente" (fade + deslize): comunica que o usuário está
      // descendo na hierarquia (visão geral → painel → indicador → alerta).
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
