import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const primaryColor = Color.fromARGB(255, 3, 128, 44);
  static const onPrimaryColor = Color(0xFF032014);
  static const backgroundColor = Color(0xFF060B14);

  static const colors = AppColors(
    action: Color.fromARGB(255, 3, 128, 44),
    onAction: Color.fromARGB(255, 252, 252, 252),
    selection: Color.fromARGB(255, 13, 168, 73),
    onSelection: Color(0xFF031A22),
    mutedIcon: Color.fromARGB(255, 11, 99, 40),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x24FFFFFF),
    navFill: Color(0xA80D1726),
    activeNavFill: Color(0x1FB8C2C0),
    shadow: Color(0x38000000),
    star: Color(0xFFFFD86B),
    backgroundGradient: [Color(0xFF111B2A), backgroundColor, Color(0xFF02050B)],
    ambientGlows: [Color(0x38586F9A), Color(0x8C17233A), Color(0x3D263A5A)],
    stadiumGradients: [
      [Color(0xFF1C2835), Color(0xFF34495D)],
      [Color(0xFF172131), Color(0xFF2E3E55)],
      [Color(0xFF202235), Color(0xFF3E435F)],
    ],
  );

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        secondary: const Color.fromARGB(255, 36, 15, 7),
        surface: const Color(0xFF11151C),
      ),
      fontFamily: 'Roboto',
      extensions: const [colors],
    );
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.action,
    required this.onAction,
    required this.selection,
    required this.onSelection,
    required this.mutedIcon,
    required this.glassFill,
    required this.glassBorder,
    required this.navFill,
    required this.activeNavFill,
    required this.shadow,
    required this.star,
    required this.backgroundGradient,
    required this.ambientGlows,
    required this.stadiumGradients,
  });

  final Color action;
  final Color onAction;
  final Color selection;
  final Color onSelection;
  final Color mutedIcon;
  final Color glassFill;
  final Color glassBorder;
  final Color navFill;
  final Color activeNavFill;
  final Color shadow;
  final Color star;
  final List<Color> backgroundGradient;
  final List<Color> ambientGlows;
  final List<List<Color>> stadiumGradients;

  @override
  AppColors copyWith({
    Color? action,
    Color? onAction,
    Color? selection,
    Color? onSelection,
    Color? mutedIcon,
    Color? glassFill,
    Color? glassBorder,
    Color? navFill,
    Color? activeNavFill,
    Color? shadow,
    Color? star,
    List<Color>? backgroundGradient,
    List<Color>? ambientGlows,
    List<List<Color>>? stadiumGradients,
  }) {
    return AppColors(
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      selection: selection ?? this.selection,
      onSelection: onSelection ?? this.onSelection,
      mutedIcon: mutedIcon ?? this.mutedIcon,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      navFill: navFill ?? this.navFill,
      activeNavFill: activeNavFill ?? this.activeNavFill,
      shadow: shadow ?? this.shadow,
      star: star ?? this.star,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      ambientGlows: ambientGlows ?? this.ambientGlows,
      stadiumGradients: stadiumGradients ?? this.stadiumGradients,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }

    return AppColors(
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      onSelection: Color.lerp(onSelection, other.onSelection, t)!,
      mutedIcon: Color.lerp(mutedIcon, other.mutedIcon, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      navFill: Color.lerp(navFill, other.navFill, t)!,
      activeNavFill: Color.lerp(activeNavFill, other.activeNavFill, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      star: Color.lerp(star, other.star, t)!,
      backgroundGradient: backgroundGradient,
      ambientGlows: ambientGlows,
      stadiumGradients: stadiumGradients,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppTheme.colors;
}
