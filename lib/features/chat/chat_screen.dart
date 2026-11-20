import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => context.read<AppState>().setDraft(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    _controller.clear();
    context.read<AppState>().send();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      children: [
        ListTile(
          title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('talking as ${state.persona.label}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: state.clearChat,
          ),
        ),
        if (state.offer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Chip(
              avatar: const Icon(Icons.reply, size: 18),
              label: Text('Replying to ${state.offer!.chat} in ${state.offer!.language}'),
            ),
          ),
        if (state.lastAction.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(state.lastAction,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        Expanded(
          child: state.messages.isEmpty
              ? const Center(child: Text('Say something to begin.'))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length,
                  itemBuilder: (context, i) => _Bubble(message: state.messages[i]),
                ),
        ),
        if (state.pending != null) _ReplyConfirmCard(pending: state.pending!),
        if (state.pendingTool != null) _ToolConfirmCard(pending: state.pendingTool!),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type or talk…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser
        ? state.persona.seed.withOpacity(0.18)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Text(message.text),
      ),
    );
  }
}

class _ReplyConfirmCard extends StatelessWidget {
  final PendingReply pending;
  const _ReplyConfirmCard({required this.pending});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reply target: ${pending.chat}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Original: ${pending.original}'),
            Text('Meaning: ${pending.language}'),
            const SizedBox(height: 8),
            Text(pending.reply),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => state.confirmPending(yes: false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => state.confirmPending(yes: true),
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolConfirmCard extends StatelessWidget {
  final PendingTool pending;
  const _ToolConfirmCard({required this.pending});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tool: ${pending.call.name}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(pending.description),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => state.confirmPending(yes: false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => state.confirmPending(yes: true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
