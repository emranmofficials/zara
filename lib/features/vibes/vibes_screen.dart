import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

const _vibes = <(String, String, IconData)>[
  ('Calm', 'slow down and breathe', Icons.self_improvement_outlined),
  ('Bright', 'energy up, lets go', Icons.wb_sunny_outlined),
  ('Focused', 'one thing at a time', Icons.center_focus_strong_outlined),
  ('Playful', 'thoda masti', Icons.sports_esports_outlined),
  ('Tender', 'soft and kind', Icons.favorite_outline),
  ('Restless', 'needs a change', Icons.air_outlined),
];

class VibesScreen extends StatelessWidget {
  const VibesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Vibes', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('Pick a feeling — ${state.persona.label} will match your pace.',
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 132,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _vibes.length,
          itemBuilder: (context, i) {
            final (label, caption, icon) = _vibes[i];
            final selected = state.mood.toLowerCase() == label.toLowerCase();
            return Card(
              color: selected ? accent.withOpacity(0.20) : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  state.setMood(label.toLowerCase());
                  state.setAction('Vibe: $label — $caption');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 30, color: accent),
                      const Spacer(),
                      Text(label, style: theme.textTheme.titleMedium),
                      Text(caption, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Energy', style: theme.textTheme.titleLarge),
        Slider(
          value: state.energy.toDouble(),
          min: 0,
          max: 100,
          divisions: 10,
          label: '${state.energy}%',
          onChanged: (v) => state.setEnergy(v.round()),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            state.startQuickAction('Vibe check: I feel ${state.mood}');
            state.navigate(Routes.chat);
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Talk about this vibe'),
        ),
      ],
    );
  }
}
