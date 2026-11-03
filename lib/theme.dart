import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const ink = Color(0xFF14171F);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE8EAEE);
  static const field = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFF2447D8);
  static const accentSoft = Color(0xFFEEF1FD);
  static const success = Color(0xFF0F8A45);
  static const error = Color(0xFFC62F2F);
  static const errorSoft = Color(0xFFFDF1F1);
}

const appRadius = 16.0;

const appOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.surface,
  systemNavigationBarIconBrightness: Brightness.dark,
);

ThemeData buildAppTheme() {
  final radius = BorderRadius.circular(appRadius - 2);
  // ขอบแบบ underline ทำให้ป้ายชื่อลอยอยู่ในพื้นช่อง ไม่ตัดผ่านขอบเหมือน outline
  final fieldBorder = UnderlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide.none,
  );

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
      primary: AppColors.accent,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surface: AppColors.surface,
      surfaceTint: Colors.transparent,
      outlineVariant: AppColors.line,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 25,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: AppColors.ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: appOverlayStyle,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.error)) return AppColors.errorSoft;
        if (states.contains(WidgetState.focused)) return AppColors.accentSoft;
        return AppColors.field;
      }),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return const TextStyle(color: AppColors.error);
        }
        return TextStyle(
          color: states.contains(WidgetState.focused)
              ? AppColors.accent
              : AppColors.muted,
        );
      }),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder,
      errorBorder: fieldBorder,
      focusedErrorBorder: fieldBorder,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.muted, width: 1.5),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SoftPageTransitionsBuilder(),
        // iOS ใช้แบบเดิมของระบบ เพื่อให้ปัดย้อนกลับได้
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final enter = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    final exit = secondaryAnimation.drive(
      Tween(begin: Offset.zero, end: const Offset(-0.04, 0))
          .chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    return SlideTransition(
      position: exit,
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: enter
              .drive(Tween(begin: const Offset(0.06, 0), end: Offset.zero)),
          child: child,
        ),
      ),
    );
  }
}
