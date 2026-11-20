import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/persona.dart';
import '../../shared/widgets/voice_orb.dart';
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

  void _showHistory(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          children: [
            Text('Chat history · ${state.messages.length}',
                style: Theme.of(context).textTheme.titleLarge),
            Expanded(
              child: state.messages.isEmpty
                  ? const Center(child: Text('এখনো কিছু নেই।'))
                  : ListView.builder(
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) {
                        final m = state.messages[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(m.isUser ? Icons.person_outline : Icons.auto_awesome_outlined),
                          title: Text(m.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${m.at.day}/${m.at.month} · ${m.at.hour}:${m.at.minute}'),
                          onTap: () {
                            state.setOldChat(true);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final showClear = state.messages.isNotEmpty || state.pending != null;
    final live = state.voiceStatus == VoiceStatus.listening ||
        state.voiceStatus == VoiceStatus.thinking;

    return Column(
      children: [
        // ---- Header (live dot, title, history, clear, old-chat close) ----
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          color: theme.colorScheme.surfaceContainerLowest,
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: live ? Colors.green : accent.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.oldChat ? 'Old chat · ${_firstDate(state)}' : (live ? 'LIVE' : 'Chat'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: live ? accent : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (state.messages.isNotEmpty)
                TextButton(
                  onPressed: () => _showHistory(context, state),
                  child: Text('History (${state.messages.length})'),
                ),
              if (showClear)
                TextButton(
                  onPressed: () => _confirmClear(context, state),
                  child: const Text('Clear'),
                ),
              if (state.oldChat)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close old chat',
                  onPressed: () => state.setOldChat(false),
                ),
            ],
          ),
        ),

        // ---- Reply target chip (tap to cancel) ----
        if (state.offer != null && state.pending == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: () => state.setOffer(null),
              borderRadius: BorderRadius.circular(18),
              child: Chip(
                avatar: const Icon(Icons.reply, size: 18),
                label: Text(
                  'Replying to ${state.offer!.chat} in ${state.offer!.language} — tap to cancel',
                ),
                side: BorderSide(color: accent.withOpacity(0.5)),
              ),
            ),
          ),

        // ---- Attachment chip ----
        if (state.attachment != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Chip(
              avatar: const Icon(Icons.attach_file, size: 18),
              label: Text('attachment · ${state.attachment}'),
              onDeleted: state.removeAttachment,
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          ),

        if (state.lastAction.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(state.lastAction, style: theme.textTheme.bodySmall),
          ),

        // ---- Message list ----
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VoiceOrb(
                        color: accent,
                        status: state.voiceStatus,
                        size: 120,
                        compact: true,
                        onTap: state.toggleListening,
                      ),
                      const SizedBox(height: 8),
                      const Text('যেকোনো কিছু জিজ্ঞেস করুন — বা মাইক টিপুন।'),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length,
                  itemBuilder: (context, i) => _Bubble(message: state.messages[i]),
                ),
        ),

        // ---- Pending voice reply replaces the composer ----
        if (state.pending != null) _ReplyConfirmCard(pending: state.pending!) else
        if (state.pendingTool != null) _ToolConfirmCard(pending: state.pendingTool!) else
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => state.attach('photo-${DateTime.now().millisecond}.jpg'),
                  tooltip: 'Attach an image',
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: state.offer != null
                          ? 'Reply to ${state.offer!.chat} in ${state.offer!.language}'
                          : 'Ask anything…',
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

  String _firstDate(AppState state) {
    if (state.messages.isEmpty) return 'today';
    final at = state.messages.first.at;
    return '${at.day}/${at.month}/${at.year}';
  }

  void _confirmClear(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all chat history?'),
        content: const Text('সংরক্ষিত স্মৃতি থাকবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              state.clearChat();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser
        ? state.persona.seed.withOpacity(0.18)
        : theme.colorScheme.surfaceContainerHighest;
    final (badge, icon) = switch (message.kind) {
      ChatMessageKind.voice => ('voice', Icons.mic_none),
      ChatMessageKind.tool => ('tool', Icons.build_outlined),
      ChatMessageKind.text => ('', Icons.chat_bubble_outline),
    };
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14),
                    const SizedBox(width: 4),
                    Text(badge.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            Text(message.text),
            const SizedBox(height: 2),
            Text(
              '${message.at.hour.toString().padLeft(2, '0')}:'
              '${message.at.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
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
    final accent = state.persona.seed;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      color: accent.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reply to ${pending.chat} in ${pending.language}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Meaning: ${pending.original}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(pending.reply, style: const TextStyle(fontSize: 16)),
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
