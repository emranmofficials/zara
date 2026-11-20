import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/services/language_policy.dart';
import '../../core/theme/persona.dart';
import '../../shared/widgets/voice_orb.dart';
import '../../state/app_state.dart';

const _moods = <(String, String)>[
  ('😊', 'happy'),
  ('🥰', 'loving'),
  ('😕', 'sulky'),
  ('😠', 'angry'),
];

const _quickActions = <(String, IconData)>[
  ('Reminder', Icons.alarm_outlined),
  ('Tasks', Icons.checklist_outlined),
  ('News', Icons.newspaper_outlined),
  ('Music', Icons.music_note_outlined),
  ('Gossip', Icons.forum_outlined),
  ('Journal', Icons.edit_note_outlined),
  ('Study', Icons.school_outlined),
  ('Focus', Icons.center_focus_strong_outlined),
  ('Roast', Icons.local_fire_department_outlined),
  ('Vent', Icons.bubble_chart_outlined),
  ('Smarthome', Icons.home_work_outlined),
  ('Automation', Icons.bolt_outlined),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still up';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  String _statusLine(AppState state) {
    if (state.voiceError.isNotEmpty) return 'মাইক বন্ধ — Settings-এ দেখুন';
    return switch (state.voiceStatus) {
      VoiceStatus.idle => 'আমি প্রস্তুত — কথা বলুন বা টিপুন',
      VoiceStatus.listening => 'শুনছি…',
      VoiceStatus.thinking => 'ভাবছি…',
      VoiceStatus.speaking => 'বলছি…',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---- Greeting header ----
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_greeting()}, ${state.persona.label}',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(state.persona.tagline, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: accent.withOpacity(0.18),
              child: Icon(Icons.auto_awesome, color: accent),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---- Hero: animated orb, the live focal point ----
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withOpacity(0.14),
                  theme.colorScheme.surface,
                  accent.withOpacity(0.06),
                ],
              ),
            ),
            child: Column(
              children: [
                VoiceOrb(
                  color: accent,
                  status: state.voiceStatus,
                  size: 180,
                  onTap: state.toggleListening,
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLine(state),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: accent, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text('${state.persona.label} · ${LanguagePolicy.name}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- Gemini setup entry: always visible until setup is complete ----
        if (!state.setupComplete)
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.55),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !state.geminiEngineInstalled
                              ? 'Gemini setup — প্রথমে install doc'
                              : 'Gemini key বা backend URL দিন',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          !state.geminiEngineInstalled
                              ? 'Doc দেখে না দেখেই engine install করা যাবে না।'
                              : 'Engine install হয়েছে — এখন key সেট করলেই চলবে।',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => state.navigate(!state.geminiEngineInstalled
                        ? Routes.settingsGeminiSetup
                        : Routes.keySetup),
                    child: const Text('Setup'),
                  ),
                ],
              ),
            ),
          ),

        // ---- Live state indicators ----
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LiveChip(status: state.voiceStatus, error: state.voiceError),
            Chip(
              avatar: const Icon(Icons.mood_outlined, size: 18),
              label: Text('mood: ${state.mood}'),
            ),
            Chip(
              avatar: const Icon(Icons.battery_full_outlined, size: 18),
              label: Text('energy: ${state.energy}%'),
            ),
            if (state.attachment != null)
              Chip(
                avatar: const Icon(Icons.attach_file, size: 18),
                label: Text('image: ${state.attachment}'),
                onDeleted: state.removeAttachment,
              ),
            if (state.voiceError.isNotEmpty)
              const Chip(
                avatar: Icon(Icons.mic_off, size: 18),
                label: Text('mic muted'),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ---- Voice note / pending action banner ----
        if (state.offer != null ||
            state.pending != null ||
            state.pendingTool != null)
          Card(
            color: accent.withOpacity(0.12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: accent),
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

        // ---- Mood cards ----
        Text('How do you feel?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: _moods.map((entry) {
            final (emoji, label) = entry;
            final selected = state.mood == label;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      Text(label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  selected: selected,
                  selectedColor: accent.withOpacity(0.25),
                  showCheckmark: false,
                  onSelected: (_) {
                    state.setMood(label);
                    state.setAction('Mood set to $label');
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ---- Energy meter ----
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Energy', style: theme.textTheme.titleMedium),
                    Text('${state.energy}%', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.energy / 100,
                    minHeight: 10,
                    color: accent,
                    backgroundColor: accent.withOpacity(0.14),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Adjust how much ${state.persona.label} speaks and acts.',
                    style: theme.textTheme.bodySmall),
                Slider(
                  value: state.energy.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${state.energy}%',
                  onChanged: (v) => state.setEnergy(v.round()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- Weather + Today cards ----
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Weather',
                value: _weather(),
                caption: 'Local, no network',
                accent: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                icon: Icons.today_outlined,
                title: 'Today',
                value: _today(),
                caption: state.lastAction.isEmpty ? 'All set' : state.lastAction,
                accent: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ---- 12 quick actions ----
        Text('Quick actions', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickActions.map((entry) {
            final (label, icon) = entry;
            return ActionChip(
              avatar: Icon(icon, size: 18, color: accent),
              label: Text(label),
              onPressed: () => state.startQuickAction(label),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        OutlinedButton.icon(
          onPressed: () => state.navigate(Routes.settings),
          icon: const Icon(Icons.tune),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  String _weather() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Cool · 22°';
    if (h < 12) return 'Clear · 26°';
    if (h < 18) return 'Warm · 30°';
    return 'Calm · 25°';
  }

  String _today() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${now.day} ${months[now.month - 1]}';
  }
}

class _LiveChip extends StatelessWidget {
  final VoiceStatus status;
  final String error;
  const _LiveChip({required this.status, required this.error});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = error.isNotEmpty
        ? ('error', Colors.red, Icons.mic_off)
        : switch (status) {
            VoiceStatus.idle => ('ready', Colors.grey, Icons.mic_none),
            VoiceStatus.listening => ('listening', Colors.green, Icons.graphic_eq),
            VoiceStatus.thinking => ('thinking', Colors.orange, Icons.hourglass_top),
            VoiceStatus.speaking => ('speaking', Colors.blue, Icons.volume_up),
          };
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text('state: $label'),
      side: BorderSide(color: color.withOpacity(0.5)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color accent;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 6),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(caption,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
