import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/route_meta.dart';
import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class SettingSpec {
  final List<String> toggles;
  final List<String> actions;
  final String info;

  const SettingSpec({
    this.toggles = const [],
    this.actions = const ['Open related settings', 'Ask ZaRa'],
    this.info = '',
  });
}

/// One small spec per settings route — the Flutter equivalent of the shared
/// toggle/list composable family in the studied app.
abstract final class SettingSpecs {
  static const _specs = <String, SettingSpec>{
    Routes.settingsPersonal: SettingSpec(
      toggles: ['Show profile on Home', 'Use nickname', 'Sync contact name'],
      actions: ['Edit profile', 'Privacy'],
      info: 'Personal details stay on this device unless you enable sync.',
    ),
    Routes.settingsZara: SettingSpec(
      toggles: ['Proactive greetings', 'Speak names', 'Use humour'],
      actions: ['Behaviour', 'Voice engine'],
      info: 'Controls how your assistant talks and when it speaks first.',
    ),
    Routes.settingsSecret: SettingSpec(
      toggles: ['Hide secret pages', 'Require confirm', 'Mask notifications'],
      actions: ['Face lock', 'Lock credentials'],
      info: 'Secret pages are hidden from the drawer search when enabled.',
    ),
    Routes.settingsSubagents: SettingSpec(
      toggles: ['Allow subagents', 'Parallel tasks', 'Report results'],
      actions: ['Create subagent', 'Skill list'],
      info: 'Subagents are helper personas with a narrow tool budget.',
    ),
    Routes.settingsOptional: SettingSpec(
      toggles: ['Markets', 'Marketing', 'Whiteboard', 'Terminal'],
      actions: ['Reset optional features'],
      info: 'Turn a module off to remove it from Home quick actions.',
    ),
    Routes.settingsBattery: SettingSpec(
      toggles: ['Reduce wake checks', 'Batch background work', 'Pause at 15%'],
      actions: ['Battery report'],
      info: 'Lower background activity trades responsiveness for battery life.',
    ),
    Routes.settingsSocial: SettingSpec(
      toggles: ['Show social cards', 'Friend shortcuts', 'Status broadcasts'],
      actions: ['Group chats', 'Connectors'],
      info: 'No social account is connected by default.',
    ),
    Routes.settingsConnectors: SettingSpec(
      toggles: ['Backend proxy', 'Local tools', 'Calendar bridge'],
      actions: ['Backend settings', 'Test connection'],
      info: 'Connectors are opt-in; nothing leaves the device by default.',
    ),
    Routes.settingsSkills: SettingSpec(
      toggles: ['Reminders', 'Journal', 'Study', 'Automation'],
      actions: ['Browse skills'],
      info: 'Skills map to the tool registry and its tier budget.',
    ),
    Routes.settingsEmail: SettingSpec(
      toggles: ['Read summaries', 'Draft replies', 'Confirm before send'],
      actions: ['Compose a draft'],
      info: 'Mail replies always require a confirmation card.',
    ),
    Routes.settingsWhatsappGroups: SettingSpec(
      toggles: ['Listen in groups', 'Mention-only replies', 'Quiet group hours'],
      actions: ['Permission setup'],
      info: 'Notification access is used only for the supported chat whitelist.',
    ),
    Routes.settingsTheme: SettingSpec(
      toggles: ['Follow persona', 'Dark mode', 'High contrast'],
      actions: ['Appearance', 'Preview theme'],
      info: 'Colours are generated from the active persona seed.',
    ),
    Routes.settingsAppearance: SettingSpec(
      toggles: ['Large text', 'Compact cards', 'Reduce motion'],
      actions: ['Theme'],
      info: 'Appearance changes are applied immediately by Material 3.',
    ),
    Routes.settingsBehaviour: SettingSpec(
      toggles: ['Confirm external actions', 'Read replies aloud', 'Remember facts'],
      actions: ['Rules', 'Assistant settings'],
      info: 'External actions are never sent without confirmation.',
    ),
    Routes.settingsTyping: SettingSpec(
      toggles: ['Autocorrect', 'Hinglish suggestions', 'Enter to send'],
      actions: ['Keyboard settings'],
      info: 'The composer follows the recognition locale.',
    ),
    Routes.settingsGuardian: SettingSpec(
      toggles: ['Guardian mode', 'Strict confirm', 'Hide previews'],
      actions: ['SOS', 'Screen lock'],
      info: 'Guardian mode adds a second check before sensitive actions.',
    ),
    Routes.settingsFaces: SettingSpec(
      toggles: ['Detect faces', 'Show names', 'Tag in Yaadein'],
      actions: ['Capture face', 'Face lock'],
      info: 'Face data is stored locally. Nothing is uploaded.',
    ),
    Routes.settingsFacesCapture: SettingSpec(
      toggles: ['Use front camera', 'Ask before capture'],
      actions: ['Face list'],
      info: 'Capture requires camera permission and your consent.',
    ),
    Routes.settingsFaceLock: SettingSpec(
      toggles: ['Unlock with face', 'Fallback to PIN', 'Require blink'],
      actions: ['Face attempts', 'Lock credentials'],
      info: 'Face lock protects the app UI, not the Android device.',
    ),
    Routes.settingsFaceAttempts: SettingSpec(
      toggles: ['Limit attempts', 'Cool-down timer', 'Alert on failure'],
      actions: ['Face lock'],
      info: 'Too many failed attempts triggers a cool-down.',
    ),
    Routes.settingsSos: SettingSpec(
      toggles: ['SOS gesture', 'Loud alarm', 'Share location'],
      actions: ['Guardian', 'Permissions'],
      info: 'SOS is a local shortcut; emergency services are not called automatically.',
    ),
    Routes.settingsTouchGuard: SettingSpec(
      toggles: ['Ignore accidental taps', 'Confirm quick actions', 'Long-press to send'],
      actions: ['Behaviour'],
      info: 'Useful when the assistant is used one-handed.',
    ),
    Routes.settingsAwareness: SettingSpec(
      toggles: ['Time awareness', 'Battery awareness', 'Quiet hours', 'Focus mode'],
      actions: ['Event triggers'],
      info: 'Awareness feeds contextual suggestions on Home.',
    ),
    Routes.settingsScreenLock: SettingSpec(
      toggles: ['Lock on background', 'Lock after 5 min', 'Blur previews'],
      actions: ['Lock credentials', 'Face lock'],
      info: 'Screen lock protects chat and memory screens.',
    ),
    Routes.settingsLockCredentials: SettingSpec(
      toggles: ['PIN required', 'Biometric fallback', 'Hide typed PIN'],
      actions: ['Key setup'],
      info: 'Credentials never leave the device.',
    ),
    Routes.settingsAutoreply: SettingSpec(
      toggles: ['Auto reply enabled', 'Only known chats', 'Confirm first reply'],
      actions: ['Notification access', 'Behaviour'],
      info: 'Every reply still goes through a confirmation card the first time.',
    ),
    Routes.settingsAccessibility: SettingSpec(
      toggles: ['Screen reader labels', 'Large text', 'Reduce motion', 'Haptic cues'],
      actions: ['Appearance'],
      info: 'Accessibility options follow Android system settings where possible.',
    ),
    Routes.advanced: SettingSpec(
      toggles: ['Developer logs', 'Verbose state', 'Show route names'],
      actions: ['Terminal', 'Export diagnostics'],
      info: 'Developer options are off by default.',
    ),
  };

  static SettingSpec forRoute(String route) =>
      _specs[route] ??
      const SettingSpec(
        toggles: ['Enable', 'Remember choice'],
        actions: ['Ask ZaRa about this'],
        info: 'This page belongs to the settings family.',
      );
}

class SettingsDetailScreen extends StatelessWidget {
  final String route;
  const SettingsDetailScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final info = RouteCatalog.find(route);
    final spec = SettingSpecs.forRoute(route);
    final label = info?.label ?? route;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: accent,
              child: Icon(info?.icon ?? Icons.tune, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.headlineMedium),
                  Text(info?.subtitle ?? 'Settings', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (spec.info.isNotEmpty)
          Card(
            color: accent.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(spec.info),
            ),
          ),
        const SizedBox(height: 8),
        Text('Toggles', style: theme.textTheme.titleMedium),
        ...spec.toggles.map((key) {
          final value = state.flag('$route:$key');
          return SwitchListTile(
            title: Text(key),
            value: value,
            subtitle: Text(value ? 'On' : 'Off', style: theme.textTheme.bodySmall),
            onChanged: (v) {
              state.setFlag('$route:$key', v);
              state.setAction('$label · $key ${v ? 'on' : 'off'}');
            },
          );
        }),
        const Divider(height: 28),
        Text('Actions', style: theme.textTheme.titleMedium),
        ...spec.actions.map((action) => ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: accent.withOpacity(0.16),
                child: const Icon(Icons.chevron_right, size: 16),
              ),
              title: Text(action),
              onTap: () => _runAction(context, state, action),
            )),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => state.navigate(Routes.settings),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('All settings'),
        ),
      ],
    );
  }

  void _runAction(BuildContext context, AppState state, String action) {
    final lower = action.toLowerCase();
    if (lower.contains('voice')) {
      state.navigate(Routes.settingsVoiceEngine);
    } else if (lower.contains('key') || lower.contains('backend') || lower.contains('connection')) {
      state.navigate(Routes.settings);
    } else if (lower.contains('face')) {
      state.navigate(Routes.settingsFaces);
    } else if (lower.contains('permission')) {
      state.navigate(Routes.permissions);
    } else if (lower.contains('rules') || lower.contains('trigger')) {
      state.navigate(Routes.zaraRules);
    } else if (lower.contains('theme') || lower.contains('appearance')) {
      state.navigate(Routes.settingsTheme);
    } else if (lower.contains('terminal')) {
      state.navigate(Routes.terminal);
    } else {
      state.setDraft('$action — ${RouteCatalog.find(route)?.label ?? route}');
      state.navigate(Routes.chat);
    }
  }
}
