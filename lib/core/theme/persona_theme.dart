import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'persona.dart';

abstract final class PersonaTheme {
  static ThemeData themeFor(Persona persona) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: persona.seed,
        brightness: persona.dark ? Brightness.dark : Brightness.light,
      ),
      brightness: persona.dark ? Brightness.dark : Brightness.light,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        systemOverlayStyle: persona.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      // Rounded, soft surfaces everywhere — keeps secondary screens visually
      // consistent with the Home orb/card language.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: persona.seed.withOpacity(0.14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: persona.seed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
