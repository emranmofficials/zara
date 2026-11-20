import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

Widget _header(BuildContext context, IconData icon, String title, String subtitle) {
  final accent = context.watch<AppState>().persona.seed;
  return Row(
    children: [
      Icon(icon, color: accent, size: 30),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  );
}

void _askZara(BuildContext context, String text) {
  final state = context.read<AppState>();
  state.setDraft(text);
  state.navigate(Routes.chat);
}

// ---------------- Markets ----------------
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final _symbols = <(String, String)>[
    ('NIFTY', '+0.84%'),
    ('SENSEX', '+0.61%'),
    ('USD/INR', '83.42'),
  ];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim().toUpperCase();
    if (value.isEmpty) return;
    setState(() => _symbols.add((value, '—')));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.persona.seed;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.show_chart_outlined, 'Markets', 'Watchlists and quotes'),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('1D')),
            Chip(label: Text('1W')),
            Chip(label: Text('1M')),
          ],
        ),
        const SizedBox(height: 12),
        ..._symbols.map((entry) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withOpacity(0.15),
                  child: Text(entry.$1.substring(0, 1),
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                ),
                title: Text(entry.$1),
                subtitle: const Text('indicative · not live data'),
                trailing: Text(entry.$2,
                    style: TextStyle(
                        color: entry.$2.startsWith('+') ? Colors.green : null,
                        fontWeight: FontWeight.bold)),
              ),
            )),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Add symbol',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _add, tooltip: 'Add', icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => _askZara(context, 'Market update for my watchlist'),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Ask for a market summary'),
        ),
      ],
    );
  }
}

// ---------------- Marketing ----------------
class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  String _goal = 'Awareness';
  String _tone = 'Friendly';
  final _audience = TextEditingController();

  @override
  void dispose() {
    _audience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.campaign_outlined, 'Marketing', 'Campaign drafts'),
        const SizedBox(height: 20),
        Text('Goal', style: theme.textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: ['Awareness', 'Launch', 'Engagement']
              .map((g) => ChoiceChip(
                    label: Text(g),
                    selected: _goal == g,
                    onSelected: (_) => setState(() => _goal = g),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        Text('Tone', style: theme.textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: ['Friendly', 'Bold', 'Calm']
              .map((t) => ChoiceChip(
                    label: Text(t),
                    selected: _tone == t,
                    onSelected: (_) => setState(() => _tone = t),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _audience,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Who is it for?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _askZara(
            context,
            'Write a $_tone $_goal campaign for: ${_audience.text.trim().isEmpty ? 'my audience' : _audience.text.trim()}',
          ),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Draft with ZaRa'),
        ),
      ],
    );
  }
}

// ---------------- Code projects ----------------
class CodeProjectsScreen extends StatelessWidget {
  const CodeProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.persona.seed;
    final repos = [
      ('zara', 'Dart', 'active'),
      ('zara-backend', 'Python', 'active'),
      ('scratchpad', 'Dart', 'paused'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.code_outlined, 'Code projects', 'Repos and tasks'),
        const SizedBox(height: 16),
        ...repos.map((r) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withOpacity(0.14),
                  child: Icon(Icons.folder_outlined, color: accent, size: 18),
                ),
                title: Text(r.$1),
                subtitle: Text('${r.$2} · ${r.$3}'),
                trailing: IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: 'Discuss',
                  onPressed: () => _askZara(context, 'Kya ${r.$1} me change karein?'),
                ),
              ),
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _askZara(context, 'New project idea do'),
          icon: const Icon(Icons.add),
          label: const Text('New project idea'),
        ),
      ],
    );
  }
}

// ---------------- Documents ----------------
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = [
      ('notes.txt', Icons.text_snippet_outlined),
      ('ideas.md', Icons.description_outlined),
      ('budget.csv', Icons.table_chart_outlined),
      ('plan.pdf', Icons.picture_as_pdf_outlined),
    ].where((d) => d.$1.toLowerCase().contains(_filter)).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.folder_open_outlined, 'Documents', 'Files you asked to keep'),
        const SizedBox(height: 16),
        TextField(
          controller: _query,
          onChanged: (v) => setState(() => _filter = v.toLowerCase()),
          decoration: const InputDecoration(
            labelText: 'Search files',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ...docs.map((d) => ListTile(
              leading: Icon(d.$2),
              title: Text(d.$1),
              onTap: () => context.read<AppState>().setAction('${d.$1} selected'),
            )),
        if (docs.isEmpty) const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Koi file nahi mili.')),
        ),
      ],
    );
  }
}

// ---------------- Pictures ----------------
class PicturesScreen extends StatelessWidget {
  const PicturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.image_outlined, 'My pictures', 'Saved images'),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (_, i) {
            final color = Colors.primaries[i % Colors.primaries.length];
            return InkWell(
              onTap: () {
                state.attach('moment-${i + 1}.jpg');
                state.setAction('Moment ${i + 1} attached');
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withOpacity(0.45 + (i % 3) * 0.15),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Moment ${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (state.attachment != null)
          Chip(
            label: Text('Attached: ${state.attachment}'),
            onDeleted: state.removeAttachment,
          ),
      ],
    );
  }
}

// ---------------- Terminal ----------------
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _input = TextEditingController();
  final _lines = <String>['ZaRa terminal · type help'];

  void _run(String value) {
    final cmd = value.trim();
    if (cmd.isEmpty) return;
    final state = context.read<AppState>();
    setState(() => _lines.add('> $cmd'));
    _input.clear();
    switch (cmd.toLowerCase()) {
      case 'help':
        setState(() => _lines.addAll([
              'help — this list',
              'status — current state',
              'whoami — active persona',
              'clear — wipe output',
              'anything else — ask ZaRa in chat',
            ]));
        break;
      case 'status':
        setState(() => _lines.add(
            'route=${state.route} voice=${state.voiceStatus.name} mood=${state.mood}'));
        break;
      case 'whoami':
        setState(() => _lines.add(state.persona.label));
        break;
      case 'clear':
        setState(() => _lines.clear());
        break;
      default:
        _askZara(context, cmd);
        setState(() => _lines.add('→ forwarded to chat'));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.terminal_outlined, 'Terminal', 'Command shortcuts'),
        const SizedBox(height: 16),
        Container(
          height: 320,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: _lines.length,
            itemBuilder: (_, i) => Text(
              _lines[i],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                decoration: const InputDecoration(
                  hintText: 'command…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _run,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _run(_input.text), child: const Text('Run')),
          ],
        ),
      ],
    );
  }
}

// ---------------- QR scan ----------------
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  String _message = '';
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _message = status.isGranted
        ? 'Camera ready — point at a QR code.'
        : 'Permission denied — paste the code below.');
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppState>().persona.seed;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(context, Icons.qr_code_scanner_outlined, 'QR scan', 'Point at a code'),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent, width: 2),
            ),
            child: Center(
              child: Icon(Icons.qr_code_2, size: 160, color: Colors.white.withOpacity(0.25)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _start,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Enable camera'),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_message),
          ),
        TextField(
          controller: _code,
          decoration: const InputDecoration(
            labelText: 'Or paste scanned content',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            final value = _code.text.trim();
            if (value.isNotEmpty) _askZara(context, 'QR said: $value');
          },
          icon: const Icon(Icons.send),
          label: const Text('Send to Chat'),
        ),
      ],
    );
  }
}

// ---------------- Whiteboard ----------------
class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset>? _current;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.persona.seed;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _header(context, Icons.draw_outlined, 'Whiteboard', 'Sketch an idea'),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: accent.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => setState(() => _current = [d.localPosition]),
              onPanUpdate: (d) => setState(() => _current?.add(d.localPosition)),
              onPanEnd: (_) => setState(() {
                if (_current != null && _current!.isNotEmpty) _strokes.add(_current!);
                _current = null;
              }),
              child: CustomPaint(
                painter: _StrokePainter(strokes: _strokes, draft: _current, color: accent),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                onPressed: () => setState(() {
                  if (_strokes.isNotEmpty) _strokes.removeLast();
                }),
                tooltip: 'Undo',
                icon: const Icon(Icons.undo),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(_strokes.clear),
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  state.setAction('Whiteboard saved locally (${_strokes.length} strokes)');
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? draft;
  final Color color;

  const _StrokePainter({
    required this.strokes,
    required this.draft,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in [...strokes, if (draft != null) draft!]) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], paint);
      }
      if (stroke.length == 1) {
        canvas.drawLine(stroke.first, stroke.first + const Offset(0.1, 0.1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}
