import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF070B12),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF3D00),
        brightness: Brightness.dark,
      ),
      fontFamily: 'sans',
    );
  }
}
