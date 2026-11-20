import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/services/backend_client.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

/// Assistant home + PC hub: paired devices and connection state.
class DeviceHubScreen extends StatefulWidget {
  final bool pc;
  const DeviceHubScreen({super.key, this.pc = false});

  @override
  State<DeviceHubScreen> createState() => _DeviceHubScreenState();
}

class _DeviceHubScreenState extends State<DeviceHubScreen> {
  final _name = TextEditingController();
  List<String> _devices = const [];
  String _message = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final devices = await BackendClient.instance.listDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices ?? const [];
      if (devices == null) _message = 'Backend optional — local devices shown below.';
    });
  }

  Future<void> _pair() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final token = await BackendClient.instance.registerDevice(name);
    if (!mounted) return;
    setState(() {
      _message = token == null
          ? 'Offline mode: $name added locally.'
          : '$name paired — token saved.';
      if (token == null) _devices = [..._devices, name];
    });
    _name.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final title = widget.pc ? 'PC hub' : 'Assistant home';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(widget.pc ? Icons.computer_outlined : Icons.hub_outlined,
                color: accent, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.headlineMedium)),
            IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: accent.withOpacity(0.10),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: accent,
                child: const Icon(Icons.smartphone, color: Colors.white)),
            title: const Text('This phone'),
            subtitle: Text('${state.persona.label} · connected'),
            trailing: Chip(label: Text(state.voiceStatus.name),
                visualDensity: VisualDensity.compact),
          ),
        ),
        const SizedBox(height: 12),
        Text('Paired devices', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No other devices yet.'),
          ),
        ..._devices.map((d) => Card(
              child: ListTile(
                leading: const Icon(Icons.devices_other_outlined),
                title: Text(d),
                subtitle: const Text('ready'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Forget',
                  onPressed: () {
                    setState(() => _devices = _devices.where((x) => x != d).toList());
                    state.setAction('$d forgotten');
                  },
                ),
              ),
            )),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Device name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _pair(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _pair,
              icon: const Icon(Icons.link),
              label: const Text('Pair'),
            ),
          ],
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_message, style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => state.navigate(Routes.settings),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Connection settings'),
        ),
      ],
    );
  }
}
