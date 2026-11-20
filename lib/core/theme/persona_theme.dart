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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: persona.seed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
