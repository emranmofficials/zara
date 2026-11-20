import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../../core/keys/key_store.dart';
import '../../core/navigation/routes.dart';
import '../../state/app_state.dart';

/// Bundled, clean-room Bengali install document. The doc is always presented
/// before the engine can be installed — never the other way round.
const String kGeminiInstallDocAsset = 'assets/docs/gemini_install_bn.md';

/// Install order is fixed: doc seen -> engine installed. Both steps persist in
/// secure storage so a restart cannot skip the first one.
class GeminiSetupScreen extends StatefulWidget {
  const GeminiSetupScreen({super.key});

  @override
  State<GeminiSetupScreen> createState() => _GeminiSetupScreenState();
}

class _GeminiSetupScreenState extends State<GeminiSetupScreen> {
  static const _fallbackDoc = 'Gemini install doc — বাংলা\n\n'
      '১. প্রথমে এই doc ফাইলটি দেখুন।\n'
      '২. তারপর Gemini engine install করুন।\n'
      '৩. শেষে নিজস্ব API key বা backend URL সেট করুন।';

  bool _docSeen = false;
  bool _installed = false;
  bool _docExpanded = false;
  String _doc = _fallbackDoc;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    String? seen;
    String? installed;
    String doc;
    try {
      final values = await Future.wait([
        KeyStore.instance.read(KeyStoreKeys.geminiDocSeen),
        KeyStore.instance.read(KeyStoreKeys.geminiEngineInstalled),
      ]);
      seen = values[0];
      installed = values[1];
      final creds = await _credentials();
      state.setFlag(KeyStoreKeys.geminiDocSeen, seen == '1');
      state.setFlag(KeyStoreKeys.geminiEngineInstalled, installed == '1');
      state.setFlag(KeyStoreKeys.gemini, creds.$1);
      state.setFlag(KeyStoreKeys.backendUrl, creds.$2);
    } catch (_) {
      // Secure storage unavailable (e.g. widget tests) — fall back to the
      // in-memory gate, which still enforces doc-before-engine.
    }
    try {
      doc = await rootBundle.loadString(kGeminiInstallDocAsset);
    } catch (_) {
      doc = _fallbackDoc;
    }
    if (!mounted) return;
    setState(() {
      _docSeen = seen == '1';
      _installed = installed == '1';
      _doc = doc;
    });
  }

  Future<void> _acknowledgeDoc() async {
    setState(() {
      _docSeen = true;
      _docExpanded = false;
      _message = 'Doc দেখা হয়েছে — এখন engine install করা যাবে।';
    });
    try {
      await KeyStore.instance.save(KeyStoreKeys.geminiDocSeen, '1');
    } catch (_) {
      // Best-effort persistence: the in-memory gate still holds for this run.
    }
    if (!mounted) return;
    final state = context.read<AppState>();
    state.setFlag(KeyStoreKeys.geminiDocSeen, true);
    await state.speakBengali('ডক ফাইল দেখা হয়েছে।');
  }

  Future<void> _installEngine() async {
    if (!_docSeen) return; // Gate: never install before the doc is seen.
    // Update the UI first: the credential lookup may touch secure storage and
    // must never hold back the install confirmation.
    setState(() {
      _installed = true;
      _message = 'জেমেনি ইঞ্জিন ইনস্টল হয়েছে।';
    });
    try {
      await KeyStore.instance.save(KeyStoreKeys.geminiEngineInstalled, '1');
    } catch (_) {}
    if (!mounted) return;
    final state = context.read<AppState>();
    state.setFlag(KeyStoreKeys.geminiEngineInstalled, true);
    final (hasKey, hasBackend) = await _credentials();
    state.setFlag(KeyStoreKeys.gemini, hasKey);
    state.setFlag(KeyStoreKeys.backendUrl, hasBackend);
    if (!mounted) return;
    if (!hasKey && !hasBackend) {
      setState(() => _message =
          'জেমেনি ইঞ্জিন ইনস্টল হয়েছে — কিন্তু API key বা backend URL এখনো দেওয়া হয়নি।');
    }
    await state.speakBengali(_message);
  }

  Future<(bool, bool)> _credentials() async {
    try {
      final values = await Future.wait([
        KeyStore.instance.read(KeyStoreKeys.gemini),
        KeyStore.instance.read(KeyStoreKeys.backendUrl),
      ]);
      return (
        (values[0] ?? '').trim().isNotEmpty,
        (values[1] ?? '').trim().isNotEmpty
      );
    } catch (_) {
      return (false, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Gemini setup', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('আগে install doc, তারপর engine install।',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),

        // ---- Step 1: install doc (always first) ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 8),
                    Text('ধাপ ১ — Install doc', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Chip(
                      label: Text(_docSeen ? 'দেখা হয়েছে' : 'অপেক্ষমান'),
                      avatar: Icon(
                        _docSeen ? Icons.check_circle : Icons.schedule,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(kGeminiInstallDocAsset, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _docExpanded = !_docExpanded),
                  icon: Icon(_docExpanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_docExpanded ? 'Doc বন্ধ করুন' : 'Doc ফাইল খুলুন'),
                ),
                if (_docExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(_doc),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _docSeen ? null : _acknowledgeDoc,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Doc দেখেছি — পরবর্তী'),
                ),
              ],
            ),
          ),
        ),

        // ---- Step 2: engine install, gated on the doc ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_outlined),
                    const SizedBox(width: 8),
                    Text('ধাপ ২ — Gemini engine',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Chip(
                      label: Text(_installed ? 'ইনস্টল হয়েছে' : 'ইনস্টল হয়নি'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_docSeen
                    ? 'Doc দেখা শেষ। এখন ইঞ্জিন ইনস্টল করা যাবে।'
                    : 'প্রথমে install doc দেখতে হবে — তারপরই এই বাটন সক্রিয় হবে।'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _docSeen && !_installed ? _installEngine : null,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(_installed
                      ? 'ইঞ্জিন ইনস্টল হয়েছে'
                      : 'ইঞ্জিন ইনস্টল করুন'),
                ),
              ],
            ),
          ),
        ),

        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_message, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.read<AppState>().navigate(Routes.keySetup),
          icon: const Icon(Icons.key_outlined),
          label: const Text('API key সেট করুন'),
        ),
        const SizedBox(height: 8),
        const Text('ZaRa আপাতত শুধু বাংলা কথা বলে।',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
