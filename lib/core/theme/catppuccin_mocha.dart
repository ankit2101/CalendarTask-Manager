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

/// Full Catppuccin Mocha accent palette exposed for colour pickers.
/// Each entry is (label, Color).
const calendarColorPalette = [
  ('Blue',      CatppuccinMocha.blue),
  ('Mauve',     CatppuccinMocha.mauve),
  ('Green',     CatppuccinMocha.green),
  ('Peach',     CatppuccinMocha.peach),
  ('Red',       CatppuccinMocha.red),
  ('Teal',      CatppuccinMocha.teal),
  ('Yellow',    CatppuccinMocha.yellow),
  ('Sky',       CatppuccinMocha.sky),
  ('Lavender',  CatppuccinMocha.lavender),
  ('Maroon',    CatppuccinMocha.maroon),
  ('Pink',      CatppuccinMocha.pink),
  ('Flamingo',  CatppuccinMocha.flamingo),
  ('Rosewater', CatppuccinMocha.rosewater),
  ('Sapphire',  CatppuccinMocha.sapphire),
];

// Keep a flat list of colours for the hash-based fallback.
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

/// Convert a hex string ('#RRGGBB' or '#AARRGGBB') to a [Color].
/// Returns null if the string is malformed.
Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return value != null ? Color(value) : null;
}

/// Convert a [Color] to a '#RRGGBB' hex string.
String colorToHex(Color color) {
  return '#${color.r.round().toRadixString(16).padLeft(2, '0')}'
      '${color.g.round().toRadixString(16).padLeft(2, '0')}'
      '${color.b.round().toRadixString(16).padLeft(2, '0')}';
}

/// Returns the display colour for an account.
/// Uses [customHex] if provided and valid; falls back to a palette colour
/// derived from [accountId].
Color accountColor(String accountId, {String? customHex}) {
  if (customHex != null) {
    final c = colorFromHex(customHex);
    if (c != null) return c;
  }
  int hash = 0;
  for (int i = 0; i < accountId.length; i++) {
    hash = (hash * 31 + accountId.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return accountPalette[hash.abs() % accountPalette.length];
}
