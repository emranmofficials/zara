import 'package:flutter/material.dart';

/// Groups mirror the four top-level route families of the studied app.
enum RouteGroup { core, tools, settings, legal }

extension RouteGroupX on RouteGroup {
  String get label => switch (this) {
        RouteGroup.core => 'Core',
        RouteGroup.tools => 'Tools',
        RouteGroup.settings => 'Settings',
        RouteGroup.legal => 'Legal & system',
      };
}

/// Presentation metadata for a route. Kept separate from routing so that the
/// drawer, voice resolver and secondary screens all agree on names and icons.
class RouteInfo {
  final String route;
  final String label;
  final String subtitle;
  final IconData icon;
  final RouteGroup group;

  const RouteInfo({
    required this.route,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.group,
  });
}

abstract final class RouteCatalog {
  static const all = <RouteInfo>[
    // ---- Core ----
    RouteInfo(route: 'home', label: 'Home', subtitle: 'Your day at a glance',
        icon: Icons.home_outlined, group: RouteGroup.core),
    RouteInfo(route: 'vibes', label: 'Vibes', subtitle: 'How are you feeling?',
        icon: Icons.mood_outlined, group: RouteGroup.core),
    RouteInfo(route: 'yaadein', label: 'Yaadein', subtitle: 'Memories, grouped by day',
        icon: Icons.photo_album_outlined, group: RouteGroup.core),
    RouteInfo(route: 'chat', label: 'Chat', subtitle: 'Talk and reply',
        icon: Icons.chat_bubble_outline, group: RouteGroup.core),
    RouteInfo(route: 'scanner', label: 'Scanner', subtitle: 'Read the world around you',
        icon: Icons.document_scanner_outlined, group: RouteGroup.core),
    RouteInfo(route: 'zara_home', label: 'Assistant home', subtitle: 'Paired device hub',
        icon: Icons.devices_other_outlined, group: RouteGroup.core),
    RouteInfo(route: 'zara_rules', label: 'Rules', subtitle: 'Your assistant protocols',
        icon: Icons.gavel_outlined, group: RouteGroup.core),
    RouteInfo(route: 'qr_scan', label: 'QR scan', subtitle: 'Point at a code',
        icon: Icons.qr_code_scanner_outlined, group: RouteGroup.core),
    RouteInfo(route: 'whiteboard', label: 'Whiteboard', subtitle: 'Sketch an idea',
        icon: Icons.draw_outlined, group: RouteGroup.core),

    // ---- Tools ----
    RouteInfo(route: 'pc_hub', label: 'PC hub', subtitle: 'Connected computers',
        icon: Icons.computer_outlined, group: RouteGroup.tools),
    RouteInfo(route: 'markets', label: 'Markets', subtitle: 'Watchlists and quotes',
        icon: Icons.show_chart_outlined, group: RouteGroup.tools),
    RouteInfo(route: 'marketing', label: 'Marketing', subtitle: 'Campaign drafts',
        icon: Icons.campaign_outlined, group: RouteGroup.tools),
    RouteInfo(route: 'code_projects', label: 'Code projects', subtitle: 'Repos and tasks',
        icon: Icons.code_outlined, group: RouteGroup.tools),
    RouteInfo(route: 'documents', label: 'Documents', subtitle: 'Files you asked to keep',
        icon: Icons.folder_open_outlined, group: RouteGroup.tools),
    RouteInfo(route: 'my_pictures', label: 'My pictures', subtitle: 'Saved images',
        icon: Icons.image_outlined, group: RouteGroup.tools),
    RouteInfo(route: 'terminal', label: 'Terminal', subtitle: 'Command shortcuts',
        icon: Icons.terminal_outlined, group: RouteGroup.tools),

    // ---- Settings ----
    RouteInfo(route: 'settings', label: 'Settings', subtitle: 'Everything configurable',
        icon: Icons.settings_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_personal', label: 'Personal', subtitle: 'Profile and details',
        icon: Icons.person_outline, group: RouteGroup.settings),
    RouteInfo(route: 'settings_zara', label: 'Assistant', subtitle: 'How ZaRa behaves',
        icon: Icons.auto_awesome_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_secret', label: 'Secret', subtitle: 'Hidden preferences',
        icon: Icons.lock_outline, group: RouteGroup.settings),
    RouteInfo(route: 'settings_subagents', label: 'Subagents', subtitle: 'Helper personas',
        icon: Icons.hub_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_optional', label: 'Optional features', subtitle: 'Turn modules on/off',
        icon: Icons.tune_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_battery', label: 'Battery', subtitle: 'Background activity',
        icon: Icons.battery_saver_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_voice_engine', label: 'Voice engine', subtitle: 'ASR and TTS',
        icon: Icons.record_voice_over_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_social', label: 'Social', subtitle: 'Connected accounts',
        icon: Icons.groups_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_connectors', label: 'Connectors', subtitle: 'External services',
        icon: Icons.cable_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_backup', label: 'Backup', subtitle: 'Export and restore',
        icon: Icons.backup_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_skills', label: 'Skills', subtitle: 'Installed abilities',
        icon: Icons.extension_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_email', label: 'Email', subtitle: 'Mail preferences',
        icon: Icons.mail_outline, group: RouteGroup.settings),
    RouteInfo(route: 'settings_whatsapp_groups', label: 'Group chats', subtitle: 'Monitored groups',
        icon: Icons.forum_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_theme', label: 'Theme', subtitle: 'Colour and contrast',
        icon: Icons.palette_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_appearance', label: 'Appearance', subtitle: 'Look and typography',
        icon: Icons.visibility_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_behaviour', label: 'Behaviour', subtitle: 'Replies and tone',
        icon: Icons.psychology_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_typing', label: 'Typing', subtitle: 'Keyboard behaviour',
        icon: Icons.keyboard_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_guardian', label: 'Guardian', subtitle: 'Safety defaults',
        icon: Icons.shield_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_faces', label: 'Faces', subtitle: 'Known faces',
        icon: Icons.face_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_faces_capture', label: 'Capture face', subtitle: 'Add a face',
        icon: Icons.face_retouching_natural_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_face_lock', label: 'Face lock', subtitle: 'Unlock with a face',
        icon: Icons.face_6_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_face_attempts', label: 'Face attempts', subtitle: 'Retry limits',
        icon: Icons.repeat_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_sos', label: 'SOS', subtitle: 'Emergency shortcuts',
        icon: Icons.sos_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_touch_guard', label: 'Touch guard', subtitle: 'Accidental-tap protection',
        icon: Icons.touch_app_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_awareness', label: 'Awareness', subtitle: 'Context sensing',
        icon: Icons.sensors_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_screen_lock', label: 'Screen lock', subtitle: 'Device lock settings',
        icon: Icons.screen_lock_rotation_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_lock_credentials', label: 'Lock credentials', subtitle: 'PIN and password',
        icon: Icons.password_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_autoreply', label: 'Auto reply', subtitle: 'Hands-free replies',
        icon: Icons.reply_all_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'settings_accessibility', label: 'Accessibility', subtitle: 'Assistive options',
        icon: Icons.accessibility_new_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'key_setup', label: 'Key setup', subtitle: 'API keys and permissions',
        icon: Icons.key_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'advanced', label: 'Advanced', subtitle: 'Developer options',
        icon: Icons.build_outlined, group: RouteGroup.settings),
    RouteInfo(route: 'event_triggers', label: 'Event triggers', subtitle: 'Automations',
        icon: Icons.bolt_outlined, group: RouteGroup.settings),

    // ---- Legal / system ----
    RouteInfo(route: 'about', label: 'About', subtitle: 'Version and credits',
        icon: Icons.info_outline, group: RouteGroup.legal),
    RouteInfo(route: 'privacy', label: 'Privacy', subtitle: 'What stays on your device',
        icon: Icons.privacy_tip_outlined, group: RouteGroup.legal),
    RouteInfo(route: 'license', label: 'License', subtitle: 'Activation status',
        icon: Icons.gavel_outlined, group: RouteGroup.legal),
    RouteInfo(route: 'notices', label: 'Notices', subtitle: 'Open-source notices',
        icon: Icons.description_outlined, group: RouteGroup.legal),
    RouteInfo(route: 'permissions', label: 'Permissions', subtitle: 'Mic, camera, notifications',
        icon: Icons.verified_user_outlined, group: RouteGroup.legal),
    RouteInfo(route: 'selfie_coach', label: 'Selfie coach', subtitle: 'Photo guidance',
        icon: Icons.photo_camera_front_outlined, group: RouteGroup.legal),
    RouteInfo(route: 'photos_of', label: 'Photos of', subtitle: 'Tagged people',
        icon: Icons.people_outline, group: RouteGroup.legal),
  ];

  static RouteInfo? find(String route) {
    for (final info in all) {
      if (info.route == route) return info;
    }
    return null;
  }

  static String label(String route) => find(route)?.label ?? route;
  static IconData icon(String route) => find(route)?.icon ?? Icons.widgets_outlined;
  static String subtitle(String route) => find(route)?.subtitle ?? '';
  static List<RouteInfo> inGroup(RouteGroup group) =>
      all.where((info) => info.group == group).toList(growable: false);
}
