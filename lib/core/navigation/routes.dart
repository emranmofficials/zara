import 'package:flutter/material.dart';

import '../../features/chat/chat_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Route names. Mirrors the "route registry" pattern: a String -> Widget map.
abstract final class Routes {
  static const home = 'home';
  static const chat = 'chat';
  static const settings = 'settings';
  static const permissions = 'permissions';
}

abstract final class RouteRegistry {
  static const _known = <String>{
    Routes.home,
    Routes.chat,
    Routes.settings,
    Routes.permissions,
  };

  static const _order = <String>[Routes.home, Routes.chat, Routes.settings];

  static bool has(String route) => _known.contains(route);

  static int indexFor(String route) =>
      _order.contains(route) ? _order.indexOf(route) : 0;

  static String routeFor(int index) =>
      index >= 0 && index < _order.length ? _order[index] : Routes.home;

  /// A voice phrase -> route resolver (simple keyword map, clean-room).
  static String? resolveFromPhrase(String phrase) {
    final p = phrase.toLowerCase();
    if (p.contains('home') || p.contains('start')) return Routes.home;
    if (p.contains('chat') || p.contains('reply') || p.contains('جواب')) {
      return Routes.chat;
    }
    if (p.contains('setting') || p.contains('config')) return Routes.settings;
    return null;
  }
}

/// Widget-free resolver for use inside build methods.
abstract final class RoutePage {
  static Widget forRoute(String route) => switch (route) {
        Routes.home => const HomeScreen(),
        Routes.chat => const ChatScreen(),
        Routes.settings => const SettingsScreen(),
        _ => const HomeScreen(),
      };
}
