import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

enum _ScanState { standby, live, recording }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  _ScanState _state = _ScanState.standby;
  bool _front = false;
  String _message = '';
  final _text = TextEditingController();
  final List<String> _captures = <String>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _goLive() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _state = _ScanState.live;
        _message = 'Camera access granted — viewfinder ready.';
      });
    } else {
      setState(() {
        _state = _ScanState.standby;
        _message = 'Camera permission denied. You can still paste detected text below.';
      });
    }
  }

  void _capture() {
    final now = DateTime.now();
    final stamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _state = _state == _ScanState.recording ? _ScanState.live : _ScanState.recording;
      _captures.insert(0, 'frame · $stamp · ${_front ? 'front' : 'back'}');
      _message = _state == _ScanState.recording ? 'Recording…' : 'Frame captured.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = app.persona.seed;
    final label = switch (_state) {
      _ScanState.standby => 'standby',
      _ScanState.live => 'live',
      _ScanState.recording => 'recording',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(Icons.document_scanner_outlined, color: accent, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scanner', style: theme.textTheme.headlineMedium),
                  Text('status: $label', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Viewfinder with corner brackets. Live camera preview requires the
        // optional camera plugin; the state machine and controls are local.
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_state != _ScanState.standby)
                  const LinearProgressIndicator(minHeight: 3),
                Icon(Icons.crop_free, size: 140, color: Colors.white.withOpacity(0.25)),
                Positioned(
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _state == _ScanState.standby
                          ? 'Tap Live to start'
                          : _front
                              ? 'front camera'
                              : 'back camera',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton.filledTonal(
              onPressed: () => setState(() => _front = !_front),
              tooltip: 'Flip camera',
              icon: const Icon(Icons.flip_camera_ios_outlined),
            ),
            IconButton.filled(
              onPressed: _goLive,
              tooltip: 'Live',
              icon: const Icon(Icons.videocam_outlined),
            ),
            IconButton.filledTonal(
              onPressed: _capture,
              tooltip: _state == _ScanState.recording ? 'Stop' : 'Capture',
              icon: Icon(_state == _ScanState.recording ? Icons.stop : Icons.camera_alt_outlined),
            ),
          ],
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_message, style: theme.textTheme.bodySmall),
          ),

        const Divider(height: 28),
        Text('Detected text', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Paste or type what the scanner read…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () {
            final value = _text.text.trim();
            if (value.isEmpty) return;
            app.setDraft('Scan said: $value');
            app.navigate(Routes.chat);
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Send to Chat'),
        ),

        if (_captures.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Captures', style: theme.textTheme.titleMedium),
          ..._captures.map((c) => ListTile(
                dense: true,
                leading: const Icon(Icons.image_outlined, size: 18),
                title: Text(c),
              )),
        ],
      ],
    );
  }
}
