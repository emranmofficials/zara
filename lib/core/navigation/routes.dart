import 'package:flutter/material.dart';

import '../../features/chat/chat_screen.dart';
import '../../features/common/secondary_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/vibes/vibes_screen.dart';
import '../../features/memory/yaadein_screen.dart';
import 'route_meta.dart';
import 'routes.g.dart';

/// Every route address used by the app. The generated file is the single
/// source of truth (tools/routes.json -> tools/generate_routes.py).
abstract final class Routes {
  static const home = GeneratedRoutes.HOME;
  static const vibes = GeneratedRoutes.VIBES;
  static const yaadein = GeneratedRoutes.YAADEIN;
  static const chat = GeneratedRoutes.CHAT;
  static const scanner = GeneratedRoutes.SCANNER;
  static const zaraHome = GeneratedRoutes.ZARA_HOME;
  static const zaraRules = GeneratedRoutes.ZARA_RULES;
  static const qrScan = GeneratedRoutes.QR_SCAN;
  static const whiteboard = GeneratedRoutes.WHITEBOARD;

  static const pcHub = GeneratedRoutes.PC_HUB;
  static const markets = GeneratedRoutes.MARKETS;
  static const marketing = GeneratedRoutes.MARKETING;
  static const codeProjects = GeneratedRoutes.CODE_PROJECTS;
  static const documents = GeneratedRoutes.DOCUMENTS;
  static const myPictures = GeneratedRoutes.MY_PICTURES;
  static const terminal = GeneratedRoutes.TERMINAL;

  static const settings = GeneratedRoutes.SETTINGS;
  static const settingsPersonal = GeneratedRoutes.SETTINGS_PERSONAL;
  static const settingsZara = GeneratedRoutes.SETTINGS_ZARA;
  static const settingsSecret = GeneratedRoutes.SETTINGS_SECRET;
  static const settingsSubagents = GeneratedRoutes.SETTINGS_SUBAGENTS;
  static const settingsOptional = GeneratedRoutes.SETTINGS_OPTIONAL;
  static const settingsBattery = GeneratedRoutes.SETTINGS_BATTERY;
  static const settingsVoiceEngine = GeneratedRoutes.SETTINGS_VOICE_ENGINE;
  static const settingsSocial = GeneratedRoutes.SETTINGS_SOCIAL;
  static const settingsConnectors = GeneratedRoutes.SETTINGS_CONNECTORS;
  static const settingsBackup = GeneratedRoutes.SETTINGS_BACKUP;
  static const settingsSkills = GeneratedRoutes.SETTINGS_SKILLS;
  static const settingsEmail = GeneratedRoutes.SETTINGS_EMAIL;
  static const settingsWhatsappGroups = GeneratedRoutes.SETTINGS_WHATSAPP_GROUPS;
  static const settingsTheme = GeneratedRoutes.SETTINGS_THEME;
  static const settingsAppearance = GeneratedRoutes.SETTINGS_APPEARANCE;
  static const settingsBehaviour = GeneratedRoutes.SETTINGS_BEHAVIOUR;
  static const settingsTyping = GeneratedRoutes.SETTINGS_TYPING;
  static const settingsGuardian = GeneratedRoutes.SETTINGS_GUARDIAN;
  static const settingsFaces = GeneratedRoutes.SETTINGS_FACES;
  static const settingsFacesCapture = GeneratedRoutes.SETTINGS_FACES_CAPTURE;
  static const settingsFaceLock = GeneratedRoutes.SETTINGS_FACE_LOCK;
  static const settingsFaceAttempts = GeneratedRoutes.SETTINGS_FACE_ATTEMPTS;
  static const settingsSos = GeneratedRoutes.SETTINGS_SOS;
  static const settingsTouchGuard = GeneratedRoutes.SETTINGS_TOUCH_GUARD;
  static const settingsAwareness = GeneratedRoutes.SETTINGS_AWARENESS;
  static const settingsScreenLock = GeneratedRoutes.SETTINGS_SCREEN_LOCK;
  static const settingsLockCredentials = GeneratedRoutes.SETTINGS_LOCK_CREDENTIALS;
  static const settingsAutoreply = GeneratedRoutes.SETTINGS_AUTOREPLY;
  static const settingsAccessibility = GeneratedRoutes.SETTINGS_ACCESSIBILITY;
  static const keySetup = GeneratedRoutes.KEY_SETUP;
  static const advanced = GeneratedRoutes.ADVANCED;
  static const eventTriggers = GeneratedRoutes.EVENT_TRIGGERS;

  static const about = GeneratedRoutes.ABOUT;
  static const privacy = GeneratedRoutes.PRIVACY;
  static const license = GeneratedRoutes.LICENSE;
  static const notices = GeneratedRoutes.NOTICES;
  static const permissions = GeneratedRoutes.PERMISSIONS;
  static const selfieCoach = GeneratedRoutes.SELFIE_COACH;
  static const photosOf = GeneratedRoutes.PHOTOS_OF;

  /// All route addresses, in catalogue order.
  static const List<String> all = <String>[
    home, vibes, yaadein, chat, scanner, zaraHome, zaraRules, qrScan, whiteboard,
    pcHub, markets, marketing, codeProjects, documents, myPictures, terminal,
    settings, settingsPersonal, settingsZara, settingsSecret, settingsSubagents,
    settingsOptional, settingsBattery, settingsVoiceEngine, settingsSocial,
    settingsConnectors, settingsBackup, settingsSkills, settingsEmail,
    settingsWhatsappGroups, settingsTheme, settingsAppearance, settingsBehaviour,
    settingsTyping, settingsGuardian, settingsFaces, settingsFacesCapture,
    settingsFaceLock, settingsFaceAttempts, settingsSos, settingsTouchGuard,
    settingsAwareness, settingsScreenLock, settingsLockCredentials,
    settingsAutoreply, settingsAccessibility, keySetup, advanced, eventTriggers,
    about, privacy, license, notices, permissions, selfieCoach, photosOf,
  ];
}

abstract final class RouteRegistry {
  /// Bottom navigation destinations (the remaining routes live in the drawer).
  static const _order = <String>[
    Routes.home,
    Routes.chat,
    Routes.yaadein,
    Routes.scanner,
    Routes.settings,
  ];

  static bool has(String route) => Routes.all.contains(route);

  static int indexFor(String route) =>
      _order.contains(route) ? _order.indexOf(route) : 0;

  static String routeFor(int index) =>
      index >= 0 && index < _order.length ? _order[index] : Routes.home;

  static List<String> get destinations => _order;

  /// Voice phrase -> route. Longest aliases win, so "zara home" is not
  /// swallowed by the shorter "home" alias.
  static String? resolveFromPhrase(String phrase) {
    final p = phrase.toLowerCase().trim();
    if (p.isEmpty) return null;
    final matches = generatedPhrases.entries.expand((entry) {
      return entry.value.where((alias) => p.contains(alias.toLowerCase())).map((_) => entry.key);
    }).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => _longestAlias(b) - _longestAlias(a));
    return matches.first;
  }

  static int _longestAlias(String route) {
    final aliases = generatedPhrases[route] ?? const <String>[];
    var best = 0;
    for (final alias in aliases) {
      if (alias.length > best) best = alias.length;
    }
    return best;
  }

  /// Routes whose label or subtitle matches a search term (drawer search).
  static List<RouteInfo> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return RouteCatalog.all;
    return RouteCatalog.all
        .where((info) =>
            info.label.toLowerCase().contains(q) ||
            info.route.contains(q) ||
            info.subtitle.toLowerCase().contains(q))
        .toList(growable: false);
  }
}

/// Widget resolver used by the shell. Principal screens have dedicated
/// implementations; secondary routes share the catalog-driven screen so each
/// address still has a real, navigable destination.
abstract final class RoutePage {
  static Widget forRoute(String route) => switch (route) {
        Routes.home => const HomeScreen(),
        Routes.vibes => const VibesScreen(),
        Routes.yaadein => const YaadeinScreen(),
        Routes.chat => const ChatScreen(),
        Routes.scanner => const ScannerScreen(),
        Routes.settings => const SettingsScreen(),
        _ => SecondaryScreen(route: route),
      };
}
