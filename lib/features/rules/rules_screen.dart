import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class RulesScreen extends StatefulWidget {
  final bool triggers;
  const RulesScreen({super.key, this.triggers = false});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final List<String> _rules = <String>[];
  final _controller = TextEditingController();

  List<String> get _seed => widget.triggers
      ? const ['At 7am — morning briefing', 'On charge — backup', 'On arrival — mark task done']
      : const [
          'Always confirm before sending',
          'Speak replies aloud',
          'Remember useful facts',
          'Respect quiet hours',
        ];

  @override
  void initState() {
    super.initState();
    _rules.addAll(_seed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _rules.add(text));
    _controller.clear();
    context.read<AppState>().setAction('Rule added: $text');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final title = widget.triggers ? 'Event triggers' : 'Rules';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(widget.triggers ? Icons.bolt_outlined : Icons.gavel_outlined,
                color: accent, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.headlineMedium)),
          ],
        ),
        const SizedBox(height: 6),
        Text(widget.triggers
            ? 'Let events kick off an assistant action.'
            : 'Protocols ${state.persona.label} follows.',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'When this happens → do that',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _add,
                  tooltip: 'Add rule',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._rules.map((rule) {
          final key = 'rule:${widget.triggers ? 'trigger' : 'rule'}:$rule';
          return Card(
            child: SwitchListTile(
              secondary: CircleAvatar(
                backgroundColor: accent.withOpacity(0.16),
                child: Icon(widget.triggers ? Icons.bolt : Icons.rule,
                    color: accent, size: 18),
              ),
              title: Text(rule),
              subtitle: Text(state.flag(key, fallback: true) ? 'Active' : 'Paused',
                  style: theme.textTheme.bodySmall),
              value: state.flag(key, fallback: true),
              onChanged: (v) {
                state.setFlag(key, v);
                state.setAction('$rule ${v ? 'active' : 'paused'}');
              },
            ),
          );
        }),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            state.setDraft('Rule: ');
            state.navigate(Routes.chat);
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Create a rule with voice'),
        ),
      ],
    );
  }
}
