import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: state.persona.seed,
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              title: Text(state.persona.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(state.persona.tagline),
            ),
            const Divider(),
            _item(context, Icons.home_outlined, 'Home', Routes.home),
            _item(context, Icons.chat_bubble_outline, 'Chat', Routes.chat),
            _item(context, Icons.settings_outlined, 'Settings', Routes.settings),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('ZaRa · com.zaraai.app',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, String route) {
    final state = context.read<AppState>();
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: state.route == route,
      onTap: () {
        state.navigate(route);
        Navigator.of(context).pop();
      },
    );
  }
}
