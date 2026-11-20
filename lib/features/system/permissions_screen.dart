import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/reply_sender.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Future<void> _request(Permission permission) async {
    await permission.request();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final accent = state.persona.seed;
    final items = <(String, IconData, Permission)>[
      ('Microphone — voice input', Icons.mic_none, Permission.microphone),
      ('Camera — scanner & faces', Icons.camera_alt_outlined, Permission.camera),
      ('Notifications — reply actions', Icons.notifications_none, Permission.notification),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: accent, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permissions', style: theme.textTheme.headlineMedium),
                  Text('Requested only when a feature is used.',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map((item) {
          final (label, icon, permission) = item;
          return FutureBuilder<PermissionStatus>(
            future: permission.status,
            builder: (context, snap) {
              final granted = snap.data?.isGranted ?? false;
              return Card(
                child: ListTile(
                  leading: Icon(icon, color: granted ? Colors.green : accent),
                  title: Text(label),
                  subtitle: Text(granted ? 'Granted' : 'Not granted'),
                  trailing: granted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: () => _request(permission),
                          child: const Text('Allow'),
                        ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.reply_all_outlined),
            title: Text('Notification reply access'),
            subtitle: Text('Needed for RemoteInput voice replies'),
            trailing: TextButton(
              onPressed: ReplySender.openNotificationSettings,
              child: Text('Open'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => openAppSettings(),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('System app settings'),
        ),
      ],
    );
  }
}
