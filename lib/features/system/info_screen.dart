import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/route_meta.dart';
import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

/// Dedicated static-info screens (About, Privacy, License, Notices, ...).
/// Clean-room copy — no text or assets from the studied app.
class InfoScreen extends StatelessWidget {
  final String route;
  const InfoScreen({super.key, required this.route});

  static const _copy = <String, String>{
    Routes.about:
        'ZaRa is a clean-room, voice-first assistant. Names, colours and assets '
        'are original. Version 0.1.0 · com.zaraai.app.\n\nBuilt with Flutter and '
        'an optional Python FastAPI backend.',
    Routes.privacy:
        'API keys are stored encrypted on this device. Chat history and memories '
        'live in the optional backend only when you configure one. No message is '
        'sent without a confirmation card. Face data and photos stay local.',
    Routes.license:
        'No licence gate or bypass is included. Any Gemini key or backend token '
        'you add is your own. Use of third-party models follows their own terms.',
    Routes.notices:
        'ZaRa uses open-source Flutter packages: provider, http, uuid, '
        'flutter_secure_storage, permission_handler, speech_to_text and '
        'flutter_tts. Their notices ship with each package.',
    Routes.selfieCoach:
        'Photo guidance runs locally. The camera is used only after you grant '
        'permission, and no image is uploaded by this screen.',
    Routes.photosOf:
        'People tags are kept on this device and grouped in Yaadein. Nothing is '
        'shared automatically.',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final info = RouteCatalog.find(route);
    final label = info?.label ?? route;
    final body = _copy[route] ??
        'This page belongs to the ZaRa route catalogue. All actions on this '
        'screen stay on your device.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: accent,
              child: Icon(info?.icon ?? Icons.info_outline, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.headlineMedium),
                  Text(info?.subtitle ?? '', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          color: accent.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(body, style: theme.textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: 20),
        if (route == Routes.about)
          FilledButton.tonalIcon(
            onPressed: () => state.navigate(Routes.notices),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open notices'),
          )
        else if (route == Routes.privacy)
          FilledButton.tonalIcon(
            onPressed: () => state.navigate(Routes.permissions),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Review permissions'),
          )
        else if (route == Routes.license)
          FilledButton.tonalIcon(
            onPressed: () => state.navigate(Routes.keySetup),
            icon: const Icon(Icons.key_outlined),
            label: const Text('Key setup'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => state.navigate(Routes.home),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Home'),
          ),
      ],
    );
  }
}
