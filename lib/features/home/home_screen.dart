import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final cards = [
      ('Voice', Icons.mic_none, 'Tap the mic and just talk'),
      ('Chat', Icons.chat_bubble_outline, 'Messages & replies'),
      ('Tools', Icons.extension_outlined, '${state.persona.label} can use tools'),
      ('Settings', Icons.tune, 'Keys, voice, persona'),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(_greeting(), style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('I am ${state.persona.label} — ${state.persona.tagline}.',
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),

        // Live voice-note / activity banner.
        if (state.offer != null || state.pending != null || state.pendingTool != null)
          Card(
            color: state.persona.seed.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: state.persona.seed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.pending != null
                              ? 'Reply ready for ${state.pending!.chat}'
                              : state.pendingTool != null
                                  ? 'Tool needs confirmation'
                                  : 'Voice note from ${state.offer!.chat}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          state.lastAction.isNotEmpty
                              ? state.lastAction
                              : 'Open Chat to confirm.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => state.navigate(Routes.chat),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),

        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('status: ${state.voiceStatus.name}')),
            Chip(label: Text('persona: ${state.persona.label}')),
            const Chip(label: Text('mode: key / backend')),
          ],
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 140,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) {
            final (title, icon, subtitle) = cards[i];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => state.navigate(i == 1 ? Routes.chat : Routes.settings),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 30, color: state.persona.seed),
                      const Spacer(),
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
