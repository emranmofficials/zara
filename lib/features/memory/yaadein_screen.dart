import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/navigation/routes.dart';
import '../../core/services/backend_client.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class YaadeinScreen extends StatefulWidget {
  const YaadeinScreen({super.key});

  @override
  State<YaadeinScreen> createState() => _YaadeinScreenState();
}

class _YaadeinScreenState extends State<YaadeinScreen> {
  List<String> _facts = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final facts = await BackendClient.instance.fetchMemory();
    if (!mounted) return;
    setState(() {
      _facts = facts ?? const [];
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final grouped = _groupByDay(state.messages);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(Icons.photo_album_outlined, color: accent, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yaadein', style: theme.textTheme.headlineMedium),
                  Text('Memories, grouped by day', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () {
            state.setDraft('Remember: ');
            state.navigate(Routes.chat);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add a memory'),
        ),
        const SizedBox(height: 16),

        // Saved facts (from the optional backend memory store).
        if (_facts.isNotEmpty) ...[
          _DateHeader(label: 'Saved facts', count: _facts.length, accent: accent),
          ..._facts.map((fact) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accent.withOpacity(0.16),
                    child: Icon(Icons.lightbulb_outline, color: accent, size: 18),
                  ),
                  title: Text(fact),
                  subtitle: const Text('fact'),
                ),
              )),
          const SizedBox(height: 12),
        ] else if (_loaded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('No saved facts yet — backend memory is optional.',
                style: theme.textTheme.bodySmall),
          ),

        // Chat memories grouped by date, like the studied app's SimpleDateFormat list.
        if (dates.isEmpty && _facts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off, size: 36, color: accent),
                    const SizedBox(height: 8),
                    const Text('Koi yaad nahi mili. Chat karo, phir yahan dikhega.'),
                  ],
                ),
              ),
            ),
          )
        else
          for (final date in dates) ...[
            _DateHeader(label: date, count: grouped[date]!.length, accent: accent),
            ...grouped[date]!.map((message) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: message.isUser
                          ? accent.withOpacity(0.20)
                          : accent.withOpacity(0.08),
                      child: Icon(
                        message.isUser ? Icons.person_outline : Icons.auto_awesome_outlined,
                        color: accent,
                        size: 18,
                      ),
                    ),
                    title: Text(message.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${message.isUser ? 'you' : state.persona.label} · '
                      '${message.at.hour.toString().padLeft(2, '0')}:'
                      '${message.at.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                )),
          ],
      ],
    );
  }

  Map<String, List<ChatMessage>> _groupByDay(List<ChatMessage> messages) {
    final result = <String, List<ChatMessage>>{};
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (final message in messages) {
      final key = '${message.at.day} ${months[message.at.month - 1]} ${message.at.year}';
      result.putIfAbsent(key, () => <ChatMessage>[]).add(message);
    }
    return result;
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  const _DateHeader({required this.label, required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 8),
          Chip(label: Text('$count'), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}
