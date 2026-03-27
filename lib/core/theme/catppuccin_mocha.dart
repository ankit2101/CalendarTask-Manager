import 'package:flutter/material.dart';

class CatppuccinMocha {
  static const rosewater = Color(0xFFF5E0DC);
  static const flamingo = Color(0xFFF2CDCD);
  static const pink = Color(0xFFF5C2E7);
  static const mauve = Color(0xFFCBA6F7);
  static const red = Color(0xFFF38BA8);
  static const maroon = Color(0xFFEBA0AC);
  static const peach = Color(0xFFFAB387);
  static const yellow = Color(0xFFF9E2AF);
  static const green = Color(0xFFA6E3A1);
  static const teal = Color(0xFF94E2D5);
  static const sky = Color(0xFF89DCEB);
  static const sapphire = Color(0xFF74C7EC);
  static const blue = Color(0xFF89B4FA);
  static const lavender = Color(0xFFB4BEFE);

  static const text = Color(0xFFCDD6F4);
  static const subtext1 = Color(0xFFBAC2DE);
  static const subtext0 = Color(0xFFA6ADC8);
  static const overlay2 = Color(0xFF9399B2);
  static const overlay1 = Color(0xFF7F849C);
  static const overlay0 = Color(0xFF6C7086);
  static const surface2 = Color(0xFF585B70);
  static const surface1 = Color(0xFF45475A);
  static const surface0 = Color(0xFF313244);
  static const base = Color(0xFF1E1E2E);
  static const mantle = Color(0xFF181825);
  static const crust = Color(0xFF11111B);
}

const accountPalette = [
  CatppuccinMocha.blue,
  CatppuccinMocha.mauve,
  CatppuccinMocha.green,
  CatppuccinMocha.peach,
  CatppuccinMocha.red,
  CatppuccinMocha.teal,
  CatppuccinMocha.yellow,
  CatppuccinMocha.sky,
  CatppuccinMocha.lavender,
  CatppuccinMocha.maroon,
];

Color accountColor(String accountId) {
  int hash = 0;
  for (int i = 0; i < accountId.length; i++) {
    hash = (hash * 31 + accountId.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return accountPalette[hash.abs() % accountPalette.length];
}
