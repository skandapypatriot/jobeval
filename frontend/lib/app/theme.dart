import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class JobEvalTheme {
  // Brand colors
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color primaryBlueLight = Color(0xFF3B82F6);
  static const Color primaryBlueDark = Color(0xFF1E3A8A);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentOrangeLight = Color(0xFFFB923C);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color surfaceGray = Color(0xFFF8FAFC);
  static const Color borderGray = Color(0xFFE2E8F0);

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      secondary: accentOrange,
      tertiary: successGreen,
      error: errorRed,
      surface: Colors.white,
      surfaceContainerHighest: surfaceGray,
      outline: borderGray,
    ),
    fontFamily: 'Inter',
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1E293B),
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderGray, width: 1),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: primaryBlue, width: 1.5),
        textStyle: _textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryBlue,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFF64748B)),
      hintStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFF94A3B8)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: borderGray),
      labelStyle: _textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    dividerTheme: DividerThemeData(
      color: borderGray,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: _textTheme.titleMedium,
      subtitleTextStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFF64748B)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.white,
      indicatorColor: primaryBlue.withValues(alpha: 0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryBlue,
          );
        }
        return _textTheme.labelSmall?.copyWith(color: Color(0xFF64748B));
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: primaryBlue.withValues(alpha: 0.1),
      selectedIconTheme: IconThemeData(color: primaryBlue, size: 24),
      unselectedIconTheme: IconThemeData(color: Color(0xFF64748B), size: 24),
      selectedLabelTextStyle: _textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryBlue,
      ),
      unselectedLabelTextStyle: _textTheme.labelSmall?.copyWith(color: Color(0xFF64748B)),
      labelType: NavigationRailLabelType.all,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      modalBackgroundColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: _textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      contentTextStyle: _textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: _textTheme.bodyMedium?.copyWith(color: Colors.white),
      backgroundColor: Color(0xFF1E293B),
      actionTextColor: accentOrangeLight,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: _textTheme.bodySmall?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryBlue,
      linearTrackColor: borderGray,
      circularTrackColor: borderGray,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryBlue,
      inactiveTrackColor: borderGray,
      thumbColor: primaryBlue,
      overlayColor: primaryBlue.withValues(alpha: 0.1),
      valueIndicatorColor: primaryBlue,
      valueIndicatorTextStyle: _textTheme.labelSmall?.copyWith(color: Colors.white),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primaryBlue,
      unselectedLabelColor: Color(0xFF64748B),
      indicatorColor: primaryBlue,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: _textTheme.labelLarge,
      dividerColor: Colors.transparent,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textColor: Color(0xFF1E293B),
      iconColor: Color(0xFF64748B),
      collapsedTextColor: Color(0xFF1E293B),
      collapsedIconColor: Color(0xFF64748B),
    ),
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: primaryBlueLight,
      secondary: accentOrangeLight,
      tertiary: Color(0xFF34D399),
      error: Color(0xFFF87171),
      surface: Color(0xFF0F172A),
      surfaceContainerHighest: Color(0xFF1E293B),
      outline: Color(0xFF334155),
    ),
    fontFamily: 'Inter',
    textTheme: _textTheme.apply(
      bodyColor: Color(0xFFF1F5F9),
      displayColor: Color(0xFFF1F5F9),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Color(0xFFF1F5F9),
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Color(0xFFF1F5F9),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(0xFF334155), width: 1),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Color(0xFF1E293B),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: primaryBlueLight,
        foregroundColor: Colors.white,
        textStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: primaryBlueLight, width: 1.5),
        textStyle: _textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryBlueLight,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryBlueLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFFF87171)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFF94A3B8)),
      hintStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFF64748B)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: Color(0xFF334155)),
      labelStyle: _textTheme.labelMedium?.copyWith(color: Color(0xFFF1F5F9)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      backgroundColor: Color(0xFF1E293B),
    ),
    dividerTheme: DividerThemeData(
      color: Color(0xFF334155),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: _textTheme.titleMedium?.copyWith(color: Color(0xFFF1F5F9)),
      subtitleTextStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFF94A3B8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Color(0xFF0F172A),
      indicatorColor: primaryBlueLight.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryBlueLight,
          );
        }
        return _textTheme.labelSmall?.copyWith(color: Color(0xFF94A3B8));
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: Color(0xFF0F172A),
      indicatorColor: primaryBlueLight.withValues(alpha: 0.2),
      selectedIconTheme: IconThemeData(color: primaryBlueLight, size: 24),
      unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8), size: 24),
      selectedLabelTextStyle: _textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryBlueLight,
      ),
      unselectedLabelTextStyle: _textTheme.labelSmall?.copyWith(color: Color(0xFF94A3B8)),
      labelType: NavigationRailLabelType.all,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      modalBackgroundColor: Color(0xFF1E293B),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: _textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Color(0xFFF1F5F9),
      ),
      contentTextStyle: _textTheme.bodyMedium?.copyWith(color: Color(0xFFF1F5F9)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: _textTheme.bodyMedium?.copyWith(color: Colors.white),
      backgroundColor: Color(0xFF334155),
      actionTextColor: accentOrangeLight,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Color(0xFF334155),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: _textTheme.bodySmall?.copyWith(color: Color(0xFFF1F5F9)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryBlueLight,
      linearTrackColor: Color(0xFF334155),
      circularTrackColor: Color(0xFF334155),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryBlueLight,
      inactiveTrackColor: Color(0xFF334155),
      thumbColor: primaryBlueLight,
      overlayColor: primaryBlueLight.withValues(alpha: 0.2),
      valueIndicatorColor: primaryBlueLight,
      valueIndicatorTextStyle: _textTheme.labelSmall?.copyWith(color: Colors.white),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primaryBlueLight,
      unselectedLabelColor: Color(0xFF94A3B8),
      indicatorColor: primaryBlueLight,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: _textTheme.labelLarge,
      dividerColor: Colors.transparent,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textColor: Color(0xFFF1F5F9),
      iconColor: Color(0xFF94A3B8),
      collapsedTextColor: Color(0xFFF1F5F9),
      collapsedIconColor: Color(0xFF94A3B8),
    ),
  );

  // Shared text theme
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.16,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.22,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.29,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.33,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.27,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.50,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.50,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.33,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.45,
    ),
  );
}