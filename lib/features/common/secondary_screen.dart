import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/route_meta.dart';
import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

/// Shared screen for the 50+ secondary routes. Mirrors the "shared composable
/// families" pattern: one small set of widgets renders a large route table.
class SecondaryScreen extends StatefulWidget {
  final String route;
  const SecondaryScreen({super.key, required this.route});

  @override
  State<SecondaryScreen> createState() => _SecondaryScreenState();
}

class _SecondaryScreenState extends State<SecondaryScreen> {
  final Map<String, bool> _toggles = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final info = RouteCatalog.find(widget.route);
    final theme = Theme.of(context);
    final label = info?.label ?? widget.route.replaceAll('_', ' ');
    final subtitle = info?.subtitle ?? 'A ZaRa destination';
    final icon = info?.icon ?? Icons.widgets_outlined;
    final group = info?.group ?? RouteGroup.core;
    final rows = _rowsFor(widget.route, group);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: state.persona.seed.withOpacity(0.10),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: state.persona.seed,
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Text('${group.label} · ${widget.route}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => state.navigate(Routes.home),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Home'),
        ),
        const Divider(height: 28),

        if (group == RouteGroup.legal)
          ..._legalBody(widget.route, theme)
        else ...[
          Text('Options', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          ...rows.map((row) => _row(context, state, row, group)),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () {
              state.setDraft('Tell me about $label');
              state.navigate(Routes.chat);
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text('Ask ${state.persona.label} about $label'),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, AppState state, String label, RouteGroup group) {
    final theme = Theme.of(context);
    final enabled = _toggles.putIfAbsent(label, () => label.contains('On') || label.contains('Enable'));
    if (group == RouteGroup.settings || group == RouteGroup.legal) {
      return SwitchListTile(
        title: Text(label),
        subtitle: Text(enabled ? 'On' : 'Off', style: theme.textTheme.bodySmall),
        value: enabled,
        onChanged: (value) {
          setState(() => _toggles[label] = value);
          state.setAction('$label ${value ? 'on' : 'off'}');
        },
      );
    }
    return ListTile(
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: state.persona.seed.withOpacity(0.18),
        child: const Icon(Icons.chevron_right, size: 16),
      ),
      title: Text(label),
      onTap: () {
        state.setDraft('$label — kya karun?');
        state.navigate(Routes.chat);
      },
    );
  }

  List<Widget> _legalBody(String route, ThemeData theme) {
    final Map<String, String> copy = {
      Routes.about:
          'ZaRa is a clean-room, voice-first assistant. It uses original names, '
          'themes and assets. Version 0.1.0 · com.zaraai.app.',
      Routes.privacy:
          'Keys are stored encrypted on this device. Chat history and memories live '
          'in the optional Python backend only when you configure one. No message is '
          'sent without your confirmation card.',
      Routes.license:
          'No licence check or bypass is included. Any API key you add is your own.',
      Routes.notices:
          'Built with Flutter and open-source packages. Third-party notices ship with '
          'their respective packages.',
      Routes.permissions:
          'Microphone, camera and notification-access permissions are requested only '
          'when the corresponding feature is used.',
      Routes.selfieCoach:
          'Photo guidance runs on-device. Nothing is uploaded by this screen.',
      Routes.photosOf:
          'People tags are stored locally and never leave the device automatically.',
    };
    final text = copy[route] ??
        'This screen is part of the ZaRa route catalogue. Its behaviour is provided '
        'by the shared secondary-screen family.';
    return [
      Text(text, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 16),
      const Icon(Icons.verified_user_outlined, size: 36),
    ];
  }

  List<String> _rowsFor(String route, RouteGroup group) {
    switch (route) {
      case Routes.settingsVoiceEngine:
        return ['Wake word on', 'Partial transcripts', 'Echo cancellation', 'Offline TTS'];
      case Routes.settingsTheme:
        return ['System theme', 'Persona colours', 'High contrast', 'Amoled background'];
      case Routes.settingsBackup:
        return ['Auto backup', 'Include memories', 'Include history', 'Encrypt export'];
      case Routes.settingsSos:
        return ['SOS on', 'Loud alarm', 'Notify contacts', 'Location sharing'];
      case Routes.settingsAccessibility:
        return ['Screen reader labels', 'Large text', 'Reduce motion', 'Haptic cues'];
      case Routes.settingsAwareness:
        return ['Battery awareness', 'Time awareness', 'Location awareness', 'Quiet hours'];
      case Routes.zaraRules:
        return ['Always confirm before sending', 'Speak replies', 'Remember facts', 'Respect quiet hours'];
      case Routes.zaraHome:
        return ['Paired devices', 'Sync status', 'Rules', 'Activity log'];
      case Routes.terminal:
        return ['Recent commands', 'Saved snippets', 'Backend health', 'Clear output'];
      case Routes.documents:
        return ['Recent files', 'Starred', 'Shared with ZaRa', 'Storage usage'];
      case Routes.myPictures:
        return ['Recent', 'Favourites', 'Albums', 'Attached to chat'];
      case Routes.whiteboard:
        return ['New sketch', 'Open last', 'Export image', 'Clear board'];
      default:
        if (group == RouteGroup.settings) {
          return ['Enable', 'Remember choice', 'Notifications', 'Advanced options'];
        }
        if (group == RouteGroup.tools) {
          return ['Overview', 'Recent activity', 'Settings', 'Ask ZaRa'];
        }
        return ['Overview', 'Start', 'History', 'Settings'];
    }
  }
}
