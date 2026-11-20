import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/routes.dart';
import 'core/theme/persona.dart';
import 'core/theme/persona_theme.dart';
import 'shared/widgets/app_drawer.dart';
import 'state/app_state.dart';

class ZaraApp extends StatelessWidget {
  /// Set false in widget tests so no platform channels are touched.
  final bool enableVoice;
  const ZaraApp({super.key, this.enableVoice = true});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(enableVoice: enableVoice),
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'ZaRa',
          debugShowCheckedModeBanner: false,
          theme: PersonaTheme.themeFor(state.persona),
          home: const AppShell(),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.enableVoice) state.initializeVoice();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text('ZaRa  ·  ${state.persona.label}'),
        actions: [
          IconButton(
            tooltip: 'Voice: ${state.voiceStatus.name}',
            icon: Icon(_voiceIcon(state.voiceStatus)),
            onPressed: state.toggleListening,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          if (state.voiceError.isNotEmpty)
            MaterialBanner(
              content: Text(state.voiceError),
              leading: const Icon(Icons.mic_off),
              actions: [
                TextButton(
                  onPressed: () => state.navigate(Routes.settings),
                  child: const Text('Settings'),
                ),
              ],
            ),
          if (state.voiceStatus == VoiceStatus.listening && state.partial.isNotEmpty)
            Container(
              width: double.infinity,
              color: state.persona.seed.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                ' listening: "${state.partial}"',
                style: TextStyle(color: state.persona.seed),
              ),
            ),
          Expanded(child: RoutePage.forRoute(state.route)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: state.toggleListening,
        tooltip: 'Talk to ZaRa',
        child: Icon(state.voiceStatus == VoiceStatus.listening
            ? Icons.stop
            : Icons.mic_none),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: RouteRegistry.indexFor(state.route),
        onDestinationSelected: (i) => state.navigate(RouteRegistry.routeFor(i)),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.photo_album_outlined), label: 'Yaadein'),
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), label: 'Scanner'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  IconData _voiceIcon(VoiceStatus s) => switch (s) {
        VoiceStatus.listening => Icons.graphic_eq,
        VoiceStatus.thinking => Icons.hourglass_top,
        VoiceStatus.speaking => Icons.volume_up,
        VoiceStatus.idle => Icons.mic_off,
      };
}
