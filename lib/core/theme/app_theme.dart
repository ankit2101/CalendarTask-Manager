import 'package:flutter/material.dart';
import 'catppuccin_mocha.dart';

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: CatppuccinMocha.base,
  colorScheme: const ColorScheme.dark(
    primary: CatppuccinMocha.blue,
    secondary: CatppuccinMocha.mauve,
    surface: CatppuccinMocha.surface0,
    error: CatppuccinMocha.red,
    onPrimary: CatppuccinMocha.crust,
    onSecondary: CatppuccinMocha.crust,
    onSurface: CatppuccinMocha.text,
    onError: CatppuccinMocha.crust,
  ),
  cardTheme: const CardThemeData(
    color: CatppuccinMocha.surface0,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CatppuccinMocha.mantle,
    foregroundColor: CatppuccinMocha.text,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: CatppuccinMocha.surface0,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: CatppuccinMocha.surface1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: CatppuccinMocha.surface1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: CatppuccinMocha.blue),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: CatppuccinMocha.text, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(color: CatppuccinMocha.text, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(color: CatppuccinMocha.text, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: CatppuccinMocha.text),
    bodyLarge: TextStyle(color: CatppuccinMocha.text),
    bodyMedium: TextStyle(color: CatppuccinMocha.subtext1),
    bodySmall: TextStyle(color: CatppuccinMocha.overlay0),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: CatppuccinMocha.blue,
      foregroundColor: CatppuccinMocha.crust,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    indicatorColor: CatppuccinMocha.surface1,
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: CatppuccinMocha.mantle,
    indicatorColor: CatppuccinMocha.surface1,
    selectedIconTheme: IconThemeData(color: CatppuccinMocha.blue),
    unselectedIconTheme: IconThemeData(color: CatppuccinMocha.overlay0),
    selectedLabelTextStyle: TextStyle(color: CatppuccinMocha.blue, fontWeight: FontWeight.w600),
    unselectedLabelTextStyle: TextStyle(color: CatppuccinMocha.overlay0),
  ),
  dividerColor: CatppuccinMocha.surface1,
);
