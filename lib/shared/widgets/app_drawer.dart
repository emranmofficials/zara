import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/route_meta.dart';
import '../../core/navigation/routes.dart';
import '../../core/theme/persona.dart';
import '../../state/app_state.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final results = RouteRegistry.search(_query);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(state.persona.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(state.persona.tagline),
              currentAccountPicture: CircleAvatar(
                backgroundColor: state.persona.seed,
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Find a page…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final group in RouteGroup.values) ...[
                    if (results.any((info) => info.group == group))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(group.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: state.persona.seed,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    for (final info in results.where((i) => i.group == group))
                      _item(context, info),
                  ],
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('ZaRa · ${RouteCatalog.all.length} routes · com.zaraai.app',
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, RouteInfo info) {
    final state = context.read<AppState>();
    return ListTile(
      dense: true,
      leading: Icon(info.icon, size: 20),
      title: Text(info.label),
      subtitle: _query.isEmpty ? null : Text(info.route),
      selected: state.route == info.route,
      selectedTileColor: state.persona.seed.withOpacity(0.10),
      onTap: () {
        state.navigate(info.route);
        Navigator.of(context).pop();
      },
    );
  }
}
